<#
.SYNOPSIS
    git worktree 作成直後 (または新規クローン直後) のセットアップを一発で行うブートストラップスクリプト。

.DESCRIPTION
    `flutter pub get` の後、Drift の生成コード (lib/data/datasources/local/database.g.dart) が
    存在しないか、スキーマ定義 (database.dart) より古い場合のみ
    `flutter pub run build_runner build --delete-conflicting-outputs` を実行する。
    生成済みで最新の場合は build_runner をスキップし、数秒で終了する (冪等)。

    NOTE: このリポジトリでは database.dart が唯一の Drift スキーマソース
    (Trips/Days/Topics/ChecklistItems を全て集約定義) であるため、タイムスタンプ比較の
    対象は database.dart 1 ファイルのみで足りている。将来テーブル定義を複数ファイルに
    分割した場合は、この比較ロジックも合わせて見直すこと。

.PARAMETER Force
    生成済みでも常に build_runner を強制再実行する。

.EXAMPLE
    pwsh tool/setup_worktree.ps1
    pwsh tool/setup_worktree.ps1 -Force
#>

param(
    [switch]$Force
)

# NOTE: $ErrorActionPreference = 'Stop' はあえて設定しない。Windows PowerShell 5.1 では
# ネイティブコマンドが stderr に何か書き込んだだけで (build_runner は警告を stderr に出す)、
# ErrorActionPreference = 'Stop' がその出力をターミネートエラーとして扱い、
# コマンドの完了を待たずにスクリプトが先に進んでしまう既知の挙動があるため。
# 成否判定は各コマンド実行直後の $LASTEXITCODE のみで行う。

$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repoRoot

$schemaSource = Join-Path $repoRoot 'lib\data\datasources\local\database.dart'
$generatedCode = Join-Path $repoRoot 'lib\data\datasources\local\database.g.dart'

Write-Host '== flutter pub get =='
flutter pub get
if ($LASTEXITCODE -ne 0) {
    Write-Error "flutter pub get failed (exit code $LASTEXITCODE)"
    exit $LASTEXITCODE
}

$needsBuildRunner = $Force -or -not (Test-Path $generatedCode)
if (-not $needsBuildRunner) {
    $schemaTime = (Get-Item $schemaSource).LastWriteTimeUtc
    $generatedTime = (Get-Item $generatedCode).LastWriteTimeUtc
    if ($generatedTime -lt $schemaTime) {
        $needsBuildRunner = $true
    }
}

if ($needsBuildRunner) {
    Write-Host '== flutter pub run build_runner build --delete-conflicting-outputs =='
    # NOTE: 現行バージョンの build_runner では --delete-conflicting-outputs は
    # "removed and were ignored" という警告付きで無視される (コンフリクト削除は既定動作に統合済み)。
    # 警告が出てもコマンド自体は正常終了するため、exit code のみで成否判定する。
    flutter pub run build_runner build --delete-conflicting-outputs
    if ($LASTEXITCODE -ne 0) {
        Write-Error "build_runner failed (exit code $LASTEXITCODE)"
        exit $LASTEXITCODE
    }
    Write-Host '== build_runner 完了 =='
} else {
    Write-Host '== database.g.dart は最新のため build_runner をスキップ =='
}

Write-Host '== セットアップ完了 =='
