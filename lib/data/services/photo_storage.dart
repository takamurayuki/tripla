import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// 添付写真のローカル保存を担うサービス。
///
/// - モバイル / デスクトップ: アプリのドキュメントディレクトリ配下
///   (`{docs}/photos/{topicId}/{uuid}.jpg`) に物理ファイルとして保存し、
///   Topic.photos には `photos/{topicId}/{uuid}.jpg` の相対パスを格納する。
/// - Web: ファイルシステムが無いため非対応 (呼び出し側で skip 想定)。
///
/// `resolveAbsolute()` で表示時に絶対パスへ展開する。
class PhotoStorage {
  PhotoStorage({Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final Uuid _uuid;

  bool get isSupported => !kIsWeb;

  /// 与えられた画像バイト列をアプリ docs に保存し、 保存した相対パスを返す。
  /// `originalName` の拡張子を引き継ぐ (無ければ `.jpg`)。
  Future<String> save({
    required String topicId,
    required Uint8List bytes,
    String? originalName,
  }) async {
    if (!isSupported) {
      throw UnsupportedError('写真の保存は現在のプラットフォームでは未対応です');
    }
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'photos', topicId));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    final ext = _extOf(originalName) ?? '.jpg';
    final fileName = '${_uuid.v4()}$ext';
    final file = File(p.join(dir.path, fileName));
    await file.writeAsBytes(bytes, flush: true);
    return p.join('photos', topicId, fileName);
  }

  /// 相対パス → 絶対 File を解決。
  Future<File> resolveAbsolute(String relativePath) async {
    final docs = await getApplicationDocumentsDirectory();
    return File(p.join(docs.path, relativePath));
  }

  /// 1 枚を物理削除。 存在しない場合は無視。
  Future<void> deleteOne(String relativePath) async {
    if (!isSupported) return;
    final file = await resolveAbsolute(relativePath);
    if (await file.exists()) {
      await file.delete();
    }
  }

  static String? _extOf(String? name) {
    if (name == null) return null;
    final ext = p.extension(name);
    if (ext.isEmpty) return null;
    return ext.toLowerCase();
  }
}
