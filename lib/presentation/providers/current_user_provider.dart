import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 現在ログイン中のユーザー ID。
///
/// Phase 1 では認証未実装のため固定値 'local-user' を返す。
/// Phase 2 で Supabase Auth 導入時に、ここを Supabase の `auth.currentUser?.id`
/// に差し替えれば、参照側 (TripCreateScreen 等) のコードを変えずに移行できる。
final currentUserIdProvider = Provider<String>((ref) => 'local-user');
