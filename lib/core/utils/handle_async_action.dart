import 'dart:developer' as developer;

import 'package:flutter/material.dart';

/// 書き込み系の async 処理をラップして、失敗時に SnackBar 通知する。
///
/// - 成功時: [onSuccess] が指定されていれば呼ぶ。
/// - 失敗時: [errorMessage] (既定 '操作に失敗しました') と例外メッセージを SnackBar 表示し、
///   `dart:developer` でログ出力。
///
/// `BuildContext.mounted` を必ずチェックしてから UI 操作する。
/// 戻り値は処理が成功したかの `bool`。
Future<bool> handleAsyncAction(
  BuildContext context,
  Future<void> Function() action, {
  String errorMessage = '操作に失敗しました',
  VoidCallback? onSuccess,
}) async {
  try {
    await action();
    if (onSuccess != null && context.mounted) onSuccess();
    return true;
  } catch (error, stack) {
    developer.log(
      errorMessage,
      name: 'tripla',
      error: error,
      stackTrace: stack,
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$errorMessage: $error')),
      );
    }
    return false;
  }
}
