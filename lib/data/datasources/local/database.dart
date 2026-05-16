import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'database.g.dart';

/// 旅程テーブル。要件定義書 §6.1 Trip / §12 trips 相当。
@DataClassName('TripRow')
class Trips extends Table {
  TextColumn get id => text()();
  TextColumn get ownerId => text().named('owner_id')();
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();
  DateTimeColumn get startDate => dateTime().named('start_date')();
  DateTimeColumn get endDate => dateTime().named('end_date')();
  TextColumn get coverImageUrl => text().named('cover_image_url').nullable()();
  TextColumn get baseCurrency =>
      text().named('base_currency').withDefault(const Constant('JPY'))();
  TextColumn get travelCurrency =>
      text().named('travel_currency').nullable()();
  DateTimeColumn get createdAt => dateTime().named('created_at')();
  DateTimeColumn get updatedAt => dateTime().named('updated_at')();

  /// Trip 全体の編集ロック (一括ロック)。true なら全 Day がロック扱い。
  BoolColumn get isLocked =>
      boolean().named('is_locked').withDefault(const Constant(false))();

  /// Trip の種類 (TripMode.name)。
  /// - 'plan' = 通常の旅行計画 (start/endDate を持ち Day1..N に分割)
  /// - 'schedule' = アプリ全体で 1 件だけ存在するマイスケジュール
  TextColumn get mode =>
      text().withDefault(const Constant('plan'))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Day テーブル。Trip に紐づく日別の枠。
@DataClassName('DayRow')
class Days extends Table {
  TextColumn get id => text()();
  TextColumn get tripId => text().named('trip_id')
      .references(Trips, #id, onDelete: KeyAction.cascade)();
  IntColumn get dayNumber => integer().named('day_number')();
  DateTimeColumn get date => dateTime()();
  TextColumn get note => text().nullable()();

  /// Day 個別の編集ロック。Trip.isLocked が true なら強制的にロック扱い。
  BoolColumn get isLocked =>
      boolean().named('is_locked').withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
        {tripId, dayNumber},
      ];
}

/// Topic テーブル。Day 内の予定。
@DataClassName('TopicRow')
class Topics extends Table {
  TextColumn get id => text()();
  TextColumn get dayId => text().named('day_id')
      .references(Days, #id, onDelete: KeyAction.cascade)();

  /// 親予定 ID。null なら親予定、値があれば子予定。
  TextColumn get parentTopicId =>
      text().named('parent_topic_id').nullable()();

  IntColumn get orderIndex => integer().named('order_index')();
  TextColumn get category => text()();
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();
  DateTimeColumn get startTime => dateTime().named('start_time').nullable()();
  DateTimeColumn get endTime => dateTime().named('end_time').nullable()();

  RealColumn get latitude => real().nullable()();
  RealColumn get longitude => real().nullable()();
  TextColumn get locationName =>
      text().named('location_name').nullable()();
  TextColumn get address => text().nullable()();

  RealColumn get cost => real().nullable()();
  TextColumn get costCurrency => text().named('cost_currency').nullable()();

  BoolColumn get isCompleted =>
      boolean().named('is_completed').withDefault(const Constant(false))();

  /// 移動カテゴリ専用: 出発地。
  TextColumn get departure => text().nullable()();

  /// 移動カテゴリ専用: 到着地。
  TextColumn get destination => text().nullable()();

  /// 移動カテゴリ専用: 移動手段 (TransportMode.name)。
  TextColumn get transportMode =>
      text().named('transport_mode').nullable()();

  /// 代替プランの JSON 配列 (TopicAltPlan)。移動 / 予定どちらでも使う。
  TextColumn get altPlans => text().named('alt_plans').nullable()();

  /// 紐づくリンク (TopicLink) の JSON 配列。null/空配列の両方を許容。
  TextColumn get links => text().nullable()();

  /// 表示色オーバーライド (#RRGGBB / #AARRGGBB)。
  /// 主に schedule モードの期間予定で利用 (カテゴリ色とは独立に自由選択)。
  /// null なら category.color にフォールバックする。
  TextColumn get colorHex => text().named('color_hex').nullable()();

  DateTimeColumn get createdAt => dateTime().named('created_at')();
  DateTimeColumn get updatedAt => dateTime().named('updated_at')();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// 持ち物リスト。要件定義書 §6.1 ChecklistItem。
@DataClassName('ChecklistItemRow')
class ChecklistItems extends Table {
  TextColumn get id => text()();
  TextColumn get tripId => text().named('trip_id')
      .references(Trips, #id, onDelete: KeyAction.cascade)();
  TextColumn get category => text().nullable()();
  TextColumn get name => text()();
  BoolColumn get isChecked =>
      boolean().named('is_checked').withDefault(const Constant(false))();
  IntColumn get orderIndex => integer().named('order_index')();
  DateTimeColumn get createdAt => dateTime().named('created_at')();

  /// 紐づく Day。null なら「旅全体」スコープ。
  /// 関連 Day が消えた場合は NULL に戻して「旅全体」スコープに昇格させる。
  TextColumn get dayId => text().named('day_id').nullable()();

  /// 紐づく Topic (予定)。null なら予定経由ではない。
  /// 関連 Topic が消えると cascade で削除される。
  TextColumn get topicId => text().named('topic_id').nullable()
      .references(Topics, #id, onDelete: KeyAction.cascade)();

  /// このアイテムの作成者ユーザー ID。
  /// 削除権限は作成者にのみある (UI 側でチェック)。
  TextColumn get createdByUserId => text().named('created_by_user_id')
      .withDefault(const Constant('local-user'))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// アプリ全体で利用する Drift データベース。
@DriftDatabase(tables: [Trips, Days, Topics, ChecklistItems])
class TriplaDatabase extends _$TriplaDatabase {
  TriplaDatabase() : super(_openConnection());

  /// テスト用に in-memory DB を渡せるコンストラクタ。
  TriplaDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 10;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        beforeOpen: (details) async {
          // SQLite はデフォルトで外部キー制約が無効。
          // cascade 削除 (Topic 削除 → 関連 ChecklistItem 削除など) を効かせるため、
          // 接続オープン時に常に有効化する。
          await customStatement('PRAGMA foreign_keys = ON');
        },
        onCreate: (m) async {
          await m.createAll();
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.createTable(days);
            await m.createTable(topics);
          }
          if (from < 3) {
            await m.createTable(checklistItems);
          }
          if (from < 4) {
            await m.addColumn(topics, topics.departure);
            await m.addColumn(topics, topics.destination);
            await m.addColumn(topics, topics.transportMode);
          }
          if (from < 5) {
            await m.addColumn(topics, topics.altPlans);
          }
          if (from < 6) {
            await m.addColumn(trips, trips.isLocked);
            await m.addColumn(days, days.isLocked);
            // ALTER TABLE で DEFAULT が既存行に当たらないケースに備えた保険。
            // 'unexpected null value' エラーを防ぐため明示的に 0 (=false) で埋める。
            await customStatement(
              'UPDATE trips SET is_locked = 0 WHERE is_locked IS NULL',
            );
            await customStatement(
              'UPDATE days SET is_locked = 0 WHERE is_locked IS NULL',
            );
          }
          if (from < 7) {
            await m.addColumn(topics, topics.links);
          }
          if (from < 8) {
            await m.addColumn(checklistItems, checklistItems.dayId);
            await m.addColumn(checklistItems, checklistItems.topicId);
            await m.addColumn(
              checklistItems,
              checklistItems.createdByUserId,
            );
            // 既存行は created_by_user_id が NULL になる可能性があるので保険
            await customStatement(
              "UPDATE checklist_items SET created_by_user_id = 'local-user' "
              'WHERE created_by_user_id IS NULL',
            );
          }
          if (from < 9) {
            await m.addColumn(trips, trips.mode);
            await customStatement(
              "UPDATE trips SET mode = 'plan' WHERE mode IS NULL",
            );
          }
          if (from < 10) {
            await m.addColumn(topics, topics.colorHex);
          }
        },
      );
}

QueryExecutor _openConnection() {
  // drift_flutter がプラットフォームごとに最適な実装を選ぶ。
  // ネイティブは sqlite3, Web は WASM。
  // Web 用の sqlite3.wasm と drift_worker.js は web/ 配下に配置済み。
  return driftDatabase(
    name: 'tripla_db',
    web: DriftWebOptions(
      sqlite3Wasm: Uri.parse('sqlite3.wasm'),
      driftWorker: Uri.parse('drift_worker.js'),
    ),
  );
}
