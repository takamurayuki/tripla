import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:tripla/data/datasources/local/database.dart';

bool _initialized = false;

/// テスト用に in-memory SQLite を使った TriplaDatabase を作る。
///
/// setUp で複数回 new されると drift が "multiple databases" 警告を出すので、
/// 初回呼び出し時に抑制フラグを立てておく。
TriplaDatabase createTestDatabase() {
  if (!_initialized) {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    _initialized = true;
  }
  return TriplaDatabase.forTesting(NativeDatabase.memory());
}
