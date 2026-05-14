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
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
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
