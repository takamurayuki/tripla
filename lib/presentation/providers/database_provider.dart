import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/local/database.dart';

/// アプリ全体で 1 つ持つ Drift データベース。
///
/// keepAlive で生存させ、unmount 時にも閉じない (アプリ終了時に OS が破棄)。
final databaseProvider = Provider<TriplaDatabase>((ref) {
  final db = TriplaDatabase();
  ref.onDispose(db.close);
  return db;
});
