import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'database.g.dart';

/// 旅程テーブル。要件定義書 §6.1 Trip / §12 Supabase trips に対応。
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

/// アプリ全体で利用する Drift データベース。
///
/// Phase 1 マイルストーン 1 では Trips のみ。Day / Topic / Expense は
/// 順次テーブルを足してスキーマバージョンを上げる。
@DriftDatabase(tables: [Trips])
class TriplaDatabase extends _$TriplaDatabase {
  TriplaDatabase() : super(_openConnection());

  /// テスト用に in-memory DB を渡せるコンストラクタ。
  TriplaDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 1;
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
