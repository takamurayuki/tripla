#!/usr/bin/env bash
# git worktree 作成直後 (または新規クローン直後) のセットアップを一発で行うブートストラップスクリプト。
#
# `flutter pub get` の後、Drift の生成コード (lib/data/datasources/local/database.g.dart) が
# 存在しないか、スキーマ定義 (database.dart) より古い場合のみ
# `flutter pub run build_runner build --delete-conflicting-outputs` を実行する。
# 生成済みで最新の場合は build_runner をスキップし、数秒で終了する (冪等)。
#
# NOTE: このリポジトリでは database.dart が唯一の Drift スキーマソース
# (Trips/Days/Topics/ChecklistItems を全て集約定義) であるため、タイムスタンプ比較の
# 対象は database.dart 1 ファイルのみで足りている。将来テーブル定義を複数ファイルに
# 分割した場合は、この比較ロジックも合わせて見直すこと。
#
# Usage:
#   bash tool/setup_worktree.sh
#   bash tool/setup_worktree.sh --force

set -euo pipefail

FORCE=0
for arg in "$@"; do
    case "$arg" in
        --force) FORCE=1 ;;
    esac
done

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

SCHEMA_SOURCE="lib/data/datasources/local/database.dart"
GENERATED_CODE="lib/data/datasources/local/database.g.dart"

echo "== flutter pub get =="
flutter pub get

needs_build_runner=0
if [ "$FORCE" -eq 1 ] || [ ! -f "$GENERATED_CODE" ]; then
    needs_build_runner=1
elif [ "$SCHEMA_SOURCE" -nt "$GENERATED_CODE" ]; then
    needs_build_runner=1
fi

if [ "$needs_build_runner" -eq 1 ]; then
    echo "== flutter pub run build_runner build --delete-conflicting-outputs =="
    # NOTE: 現行バージョンの build_runner では --delete-conflicting-outputs は
    # "removed and were ignored" という警告付きで無視される (コンフリクト削除は既定動作に統合済み)。
    # 警告が出てもコマンド自体は正常終了するため、exit code のみで成否判定する。
    flutter pub run build_runner build --delete-conflicting-outputs
    echo "== build_runner 完了 =="
else
    echo "== database.g.dart は最新のため build_runner をスキップ =="
fi

echo "== セットアップ完了 =="
