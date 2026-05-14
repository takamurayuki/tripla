import 'package:flutter/foundation.dart';

/// Topic に紐づくリンク (URL + 表示用ラベル)。
///
/// 例: { label: '予約サイト', url: 'https://...' }
/// タイムラインカードでは OGP プレビューを試み、失敗時は
/// ラベル + ドメイン名のフォールバックを表示する。
@immutable
class TopicLink {
  TopicLink({
    required this.id,
    required this.label,
    required this.url,
  }) : assert(url.trim().isNotEmpty, 'url must not be empty');

  final String id;
  final String label;
  final String url;

  TopicLink copyWith({String? label, String? url}) {
    return TopicLink(
      id: id,
      label: label ?? this.label,
      url: url ?? this.url,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'url': url,
      };

  factory TopicLink.fromJson(Map<String, dynamic> json) {
    return TopicLink(
      id: json['id'] as String,
      label: (json['label'] as String?) ?? '',
      url: json['url'] as String,
    );
  }
}
