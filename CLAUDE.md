# CLAUDE.md

このファイルは、Claude Code が本リポジトリで作業する際の常駐コンテキストです。要件定義書 `tripla_requirements.md` と併読してください。

---

## 1. プロダクト概要

**トリプラ (Tripla)** — マスコット「旅山トリ太(タビヤマ トリタ)」と一緒に旅行の **計画 → 実行 → 記録** を進められる Flutter 製アプリ。

- キャッチコピー: 「旅の計画を、もっとかんたんに、もっと楽しく！」
- ターゲット: 20〜40代の旅行好き(国内・海外)
- 差別化: Day単位タイムライン / ドラッグ&ドロップ / マルチ通貨自動円換算 / オートセーブ / トリ太くんの Rive アニメ

詳細は `tripla_requirements.md` の §1〜§3 を参照。

---

## 2. アーキテクチャ

```
lib/
├── main.dart                  # エントリポイント (ProviderScope + TriplaApp)
├── app.dart                   # MaterialApp.router (テーマ + go_router)
├── core/
│   ├── theme/                 # AppColors / AppTextTheme / AppTheme
│   ├── router/                # AppRouter (go_router)
│   ├── constants/             # (Phase 1+)
│   ├── utils/                 # (Phase 1+)
│   └── extensions/            # (Phase 1+)
├── data/                      # (Phase 1+: models / repositories / datasources)
├── domain/                    # (Phase 1+: entities / usecases)
└── presentation/
    ├── features/
    │   ├── splash/            # S-01
    │   ├── home/              # S-03 (Phase 0 は空状態のみ)
    │   ├── trip_detail/       # S-04 (Phase 1)
    │   ├── day_timeline/      # S-04 内部 (Phase 1)
    │   ├── topic_edit/        # S-05 (Phase 1)
    │   ├── auth/              # S-02 (Phase 1)
    │   ├── checklist/         # S-06 (Phase 2)
    │   ├── expense/           # S-07 (Phase 2)
    │   ├── map/               # S-08 (Phase 3)
    │   └── settings/          # S-10 (Phase 1)
    ├── widgets/
    │   ├── trita/             # TritaWidget (PNG fallback) + TritaSpeechBubble
    │   ├── header/            # TriplaHeader (固定ヘッダ)
    │   └── common/            # (Phase 1+)
    └── providers/             # (Phase 1+ Riverpod プロバイダ群)
```

- **状態管理**: Riverpod (`flutter_riverpod`)
- **ルーティング**: go_router (`appRouterProvider`)
- **アニメーション**: Rive (Phase 0 は PNG fallback。`assets/rive/trita.riv` 配置後に `TritaWidget` 内部のみ差し替え)
- **ローカル DB**: Drift (Phase 1 で導入予定)
- **バックエンド**: Supabase (Phase 1 以降。認証情報未受領のため未組込)

---

## 3. コーディング規約

- ファイル名: `snake_case.dart`
- クラス: `PascalCase`
- 変数・関数: `camelCase`
- 定数: `lowerCamelCase` / `SCREAMING_SNAKE_CASE`
- Widget サフィックス: `XxxScreen`(画面) / `XxxWidget`(共通) / `XxxCard`(カード)
- 色・タイポは必ず `AppColors` / `Theme.of(context).textTheme` 経由で参照
- 直接 `Color(0xFF...)` を Widget 内に書かない
- AppBar は `TriplaHeader` を使う (要件 §F-007 ヘッダ固定)

### やってはいけないこと (要件 §14.4)

- **一括編集機能の実装**(仕様で明示禁止)
- **トリ太くんを使わない無機質な UI**
- **ヘッダの非固定化**
- **保存ボタンを設ける**(オートセーブが原則)

---

## 4. アセット

- `assets/trita/body/` 全身 PNG (banzai / stand_hold_camera / map_open / thinking / camera_shooting / jump / walk 等)
- `assets/trita/face/` 表情 PNG (normal / blink / heart_eyes / star_eyes / surprised 等)
- `assets/trita/parts/` Rive リギング用パーツ
- `assets/image/tripla_icon.png` アプリアイコン
- `assets/rive/trita.riv` ★未配置★ (Rive Cadet プラン契約中、配置後は `TritaWidget` の PNG fallback を差し替え)

トリ太くんの状態と PNG のマッピングは `lib/presentation/widgets/trita/trita_widget.dart` の `_bodyAssetByState` を参照。

---

## 5. 現在のフェーズ進捗

### Phase 0 — 基盤構築 ✅ 完了

- [x] Flutter プロジェクト初期化 (`flutter create`)
- [x] プロジェクト構造作成 (`lib/` 配下)
- [x] 依存パッケージ追加 (`flutter_riverpod`, `go_router`, `rive`, `intl`, `uuid`, `collection`)
- [x] テーマ定義 (AppColors / AppTextTheme / AppTheme)
- [x] go_router 設定 (`/splash`, `/home`)
- [x] TritaWidget (PNG fallback、Rive 差し替え可能設計)
- [x] スプラッシュ + ホーム最小実装
- [x] `flutter analyze` クリーン / `flutter test` パス / `flutter build web` 成功
- [ ] Supabase プロジェクト作成・接続設定 → **Phase 1 に持ち越し**(認証情報未受領)
- [ ] Android SDK / Visual Studio C++ Tools → **必要時にユーザー側で対応**

### Phase 1 マイルストーン 1 — Drift + 旅程 CRUD ✅ 完了

- [x] Drift + drift_flutter + sqlite3_flutter_libs + path_provider 導入
- [x] `Trip` エンティティ / `TopicCategory` enum
- [x] `Trips` テーブル + `TriplaDatabase` (build_runner 生成済)
- [x] `TripRepository` (watchAll / create / update / delete)
- [x] `databaseProvider` (keepAlive) / `tripRepositoryProvider` / `tripListProvider` (Stream)
- [x] ホーム画面の空状態 / 一覧切替 (`TripCard`)
- [x] 旅程作成画面 `/trips/new` (タイトル / 期間 / メモ)

### Phase 1 マイルストーン 1.2 — 旅程詳細 + Day タイムライン (次)

1. `Days` / `Topics` テーブル追加 + スキーマバージョン 2 へ migration
2. 旅程詳細画面 S-04 (Day タブ切替)
3. Day タイムライン表示
4. 旅程編集・削除 (長押しメニュー)

### Phase 1 マイルストーン 1.3 — トピック編集 + D&D

1. トピック編集 S-05 (概要 / コンテンツタブ)
2. オートセーブ (debounce 500ms)
3. ドラッグ&ドロップ並べ替え

### Phase 1 マイルストーン 1.4 — 認証 (Supabase 接続後)

1. 認証画面 S-02
2. Supabase 接続 (URL / anon key)
3. `kLocalOwnerId` を実ユーザー ID に差し替え

### Phase 2 — 拡張 / Phase 3 — 仕上げ

詳細は `tripla_requirements.md` §10 を参照。

---

## 6. 開発コマンド

PowerShell から:

```powershell
$env:Path = "$env:Path;C:\flutter\bin"  # 現セッションのみ必要 (ユーザー PATH には永続追加済み)
flutter pub get
flutter analyze
flutter test
flutter run -d chrome           # Web で動作確認 (Android SDK 無くてもOK)
flutter build web
```

---

## 7. 未解決事項 / TODO

- **Rive ファイル** `assets/rive/trita.riv` の配置 (Cadet プラン契約済み)
- **Supabase** プロジェクトの URL / anon key を受領後、`SupabaseClient` 初期化を `main.dart` に追加
- **Windows 開発者モード**: ネイティブプラグインのシンボリックリンク対応のため、Windows 実機ビルド時に有効化が必要 (`start ms-settings:developers`)
- **Android Studio + Android SDK** / **Visual Studio C++ Workload** は Android / Windows ターゲットビルド時に必要
- **フォント**: NotoSansJP / Quicksand を `assets/fonts/` に配置し `AppTextTheme` で `fontFamily` を指定

---

## 8. 判断に迷ったときの優先順位 (要件 §16)

1. **ユーザー体験 > 開発速度** (トリ太くんの愛らしさ最優先)
2. **シンプル > 多機能** (MVP 段階では機能を絞る)
3. **オフライン対応 > オンライン依存** (海外旅行を想定)
4. **保存し忘れ防止 > 明示的な保存ボタン** (オートセーブ原則)
