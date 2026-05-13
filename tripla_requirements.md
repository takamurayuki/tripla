# トリプラ (Tripla) 要件定義書

> **Claude Code 向け実装指示書**  
> このドキュメントを一読すれば、`C:\Projects\tripla` 配下で実装を開始できます。  
> 不明点はこのドキュメント内の「実装フェーズ」「優先順位」セクションに従ってください。

---

## 1. プロダクト概要

### 1.1 プロダクト名
**トリプラ (Tripla)** — 「旅(Tri)」+「プラン(pla)」+「トリケラトプス(Tri)」

### 1.2 キャッチコピー
**「旅の計画を、もっとかんたんに、もっと楽しく！」**

### 1.3 一言で言うと
旅行の **計画 → 実行 → 記録** をマスコットキャラ「**旅山トリ太(タビヤマ トリタ)**」と一緒に進められる、Flutter製の旅行計画＆記録アプリ。

### 1.4 解決する課題
| 既存アプリの不満 | トリプラの解決策 |
|---|---|
| 一覧性が悪く、行程が把握しづらい | **Day単位タイムライン**で1日分を一目で把握 |
| 操作が直感的でない | **ドラッグ&ドロップ**で予定の並べ替え・移動 |
| 海外旅行で為替計算が面倒 | **自動円換算**機能を内蔵 |
| 保存し忘れで入力が消える | **オートセーブ**で常に保存済み |
| 業務的で味気ない | **トリ太くんの水彩アニメ**で楽しい体験 |

### 1.5 差別化ポイント
1. **トリ太くんの Rive アニメーション**による愛らしい体験
2. **Day1, Day2 ... タイムライン表示**で行程の一覧性
3. **マルチ通貨対応**の費用計算・自動円換算
4. **トピック単位編集**による細かい一括編集回避
5. **ドラッグ&ドロップ**の直感的UX

---

## 2. ターゲットユーザー

### 2.1 ペルソナ
- **メインターゲット**: 20〜40代の旅行好き
- **利用シーン**:
  - 家族旅行・カップル旅行・友人グループ旅行
  - 国内旅行＆海外旅行（為替対応）
  - 個人旅行（1人計画）

### 2.2 ユーザーストーリー
```
旅行者として、
出発前は計画を立てやすく、
旅行中は次の予定を素早く確認でき、
旅行後は写真と思い出を見返せるアプリが欲しい。
```

---

## 3. 機能要件

### 3.1 コア機能（Must Have / MVP）

#### F-001: 旅行計画の作成・管理
- 旅行ごとに「**旅程(Trip)**」を作成
- 旅程は複数の「**Day(日)**」を持つ
- 各Dayは複数の「**トピック(Topic)**」を持つ
- トピックは「**親予定**」と「**子予定**」を持てる（階層構造）

**データ階層**:
```
Trip (旅行)
 └── Day (日付別)
      └── Topic (トピック: 移動/観光/食事 等)
           ├── 親予定 (例: 「東京駅集合」)
           └── 子予定 (例: 「丸の内南口で集合」「お土産チェック」)
```

#### F-002: Day単位タイムライン表示（差別化）
- 1日分の行程を **縦スクロールのタイムライン** で表示
- 時刻軸付き（例: 9:00 → 12:00 → 15:00 ...）
- **Day1, Day2, Day3** とタブまたは横スワイプで切り替え
- 親予定と子予定をインデントで視覚的に区別

#### F-003: ドラッグ&ドロップ操作
- トピックの順序入れ替え（同一Day内）
- トピックを別のDayへ移動
- 子予定を別の親予定へ移動
- ライブラリ候補: `flutter_reorderable_list` または `super_drag_and_drop`

#### F-004: トピック単位の編集
- **一括編集は行わない**（仕様明示）
- 編集ダイアログでは「概要」と「コンテンツ」を**別タブ/別セクション**で選択
  - 概要: タイトル、時刻、場所、カテゴリ
  - コンテンツ: 詳細メモ、写真、リンク、持ち物

#### F-005: オートセーブ
- 入力中に **debounce 500ms** で自動保存
- 「保存中...」「保存済み✓」のステータス表示
- オフライン時はローカルキャッシュに保存→オンライン復帰時に同期

#### F-006: 写真添付・共有
- トピックごとに **複数枚** の写真添付
- メンバー間で共有（招待リンク or ユーザーID指定）
- 写真は端末ローカル＋クラウドストレージに保存
- 共有メンバーは閲覧/編集権限を区別

#### F-007: ヘッダ固定メニュー
- 画面上部にヘッダ固定（スクロール時も常時表示）
- メニュー項目:
  - ホーム（旅程一覧）
  - 通知（リマインド）
  - 設定
  - プロフィール

### 3.2 拡張機能（Should Have）

#### F-008: リマインド機能
- トピックごとに通知時刻を設定
- 出発前リマインド（例: 「明日は旅行です！」「○○分前です」）
- 持ち物チェックの催促通知
- ライブラリ: `flutter_local_notifications`

#### F-009: 地図案内機能
- トピックに位置情報を紐づけ
- 地図表示・経路検索
- 現在地から目的地までのナビ起動
- ライブラリ: `google_maps_flutter` または `flutter_map` (OSM)

#### F-010: 持ち物チェックリスト
- 旅程ごとに持ち物リストを作成
- カテゴリ別（衣類/電子機器/書類 等）
- チェックボックスで進捗管理
- テンプレート機能（国内旅行/海外旅行/ビジネス）

#### F-011: 費用計算・円換算（差別化）
- トピックごとに費用を記録
- 通貨選択（JPY/USD/EUR/KRW/THB/TWD 等）
- 自動円換算（為替APIから取得）
- 旅程全体のサマリー表示
- メンバー間の精算機能（割り勘）
- API候補: ExchangeRate-API, Frankfurter API（無料）

### 3.3 提案する追加機能（価値向上）

> **以下は既存要件にプラスαで価値が高まる提案です。実装の必須度を ★ で示しています。**

#### F-012 ★★★: トリ太くんのコンパニオン体験
トリ太くんを単なる装飾ではなく**機能の中心**に据えると、競合との差別化が圧倒的になります。

- **状況別アニメーション**:
  - アプリ起動時: ばんざい (banzai)
  - 計画作成時: 地図を開く (map_open)
  - 写真追加時: カメラ撮影 (camera_shooting)
  - 完了時: ハート目 (heart_eyes)
  - 思考中（読み込み）: 考えるポーズ (thinking)
  - 旅行当日: 走る (run)
- **吹き出しメッセージ**:
  - 「持ち物チェックした？」
  - 「明日が楽しみだね！」
  - 「思い出を写真に残そう！」

#### F-013 ★★★: 旅のジャーナル（旅行後の記録モード）
旅行が終わった後の **「思い出を見返す体験」** を強化。
- 旅程を時系列で振り返るスライドショー
- 写真をDay別に自動編集してフォトブック風UIで表示
- 「○年前の今日」のような思い出通知

#### F-014 ★★: テンプレート機能
- 人気の旅行プランをテンプレ化（京都2泊3日、台湾3泊4日 等）
- 自分の過去旅程をテンプレートとして保存
- インポート時にDay/トピックを一括生成

#### F-015 ★★: オフラインモード
海外旅行では通信環境が不安定。
- 旅程・写真・地図をローカルキャッシュ
- オフライン編集→オンライン復帰時に同期
- Conflict時の解決UI

#### F-016 ★★: 共有リンク（読み取り専用）
- 旅程をWebで閲覧できるリンクを生成
- アプリ未インストールの家族・友人にも共有可能
- SNSシェアでバイラル獲得

#### F-017 ★: 天気予報統合
- 旅行先・日付ごとに天気を自動表示
- 雨予報なら「傘を持って！」とトリ太くんが提案

#### F-018 ★: AI旅程提案（将来拡張）
- 行き先・期間・予算を入力するとAIが旅程案を生成
- Claude API または OpenAI API

---

## 4. 非機能要件

### 4.1 パフォーマンス
- 初期起動 3秒以内
- 画面遷移 300ms以内
- リスト1000件でもスクロール60fps維持

### 4.2 対応プラットフォーム
- **iOS** 14.0+
- **Android** API 26+ (Android 8.0+)
- **Web** （将来対応、Phase 3以降）

### 4.3 セキュリティ
- 認証: Firebase Auth または Supabase Auth
- 通信: HTTPS 必須
- ローカル保存: 機密情報は暗号化（`flutter_secure_storage`）

### 4.4 アクセシビリティ
- VoiceOver / TalkBack 対応
- 最小タップ領域 44x44pt

---

## 5. 技術スタック

### 5.1 確定スタック

| カテゴリ | 技術 | バージョン | 備考 |
|---|---|---|---|
| フレームワーク | Flutter | 3.x 最新 | クロスプラットフォーム |
| 言語 | Dart | 3.x | |
| 状態管理 | **Riverpod** | 2.x | 推奨（または Bloc） |
| アニメーション | **Rive** | 0.13.x | Cadetプラン契約中 |
| ローカルDB | **Drift** または **Isar** | 最新 | オフライン対応 |
| バックエンド | **Supabase** | 最新 | Auth + DB + Storage |
| ルーティング | **go_router** | 最新 | |
| 通知 | flutter_local_notifications | 最新 | |
| 地図 | google_maps_flutter | 最新 | |
| 画像処理 | image_picker, cached_network_image | 最新 | |
| 国際化 | flutter_localizations + intl | 最新 | 日/英対応 |
| 為替API | Frankfurter API | - | 無料、APIキー不要 |

### 5.2 プロジェクト構成（推奨）

```
C:\Projects\tripla\
├── android/
├── ios/
├── assets/
│   ├── trita/                  # トリ太くん素材
│   │   ├── face/
│   │   ├── body/
│   │   └── parts/
│   ├── rive/
│   │   └── trita.riv           # Riveファイル
│   ├── icons/
│   └── images/
├── lib/
│   ├── main.dart
│   ├── app.dart
│   ├── core/                   # 共通基盤
│   │   ├── constants/
│   │   ├── theme/              # カラー・タイポグラフィ
│   │   ├── router/             # go_router設定
│   │   ├── utils/
│   │   └── extensions/
│   ├── data/                   # データ層
│   │   ├── models/             # データモデル
│   │   ├── repositories/       # リポジトリ
│   │   ├── datasources/        # API/DBアクセス
│   │   │   ├── local/          # Drift/Isar
│   │   │   └── remote/         # Supabase
│   │   └── services/           # 外部サービス
│   ├── domain/                 # ビジネスロジック
│   │   ├── entities/
│   │   └── usecases/
│   ├── presentation/           # UI層
│   │   ├── features/
│   │   │   ├── home/           # 旅程一覧
│   │   │   ├── trip_detail/    # 旅程詳細
│   │   │   ├── day_timeline/   # Dayタイムライン
│   │   │   ├── topic_edit/     # トピック編集
│   │   │   ├── checklist/      # 持ち物リスト
│   │   │   ├── expense/        # 費用計算
│   │   │   ├── map/            # 地図
│   │   │   ├── auth/           # 認証
│   │   │   └── settings/       # 設定
│   │   ├── widgets/            # 共通ウィジェット
│   │   │   ├── trita/          # トリ太くん表示用
│   │   │   ├── header/         # 固定ヘッダ
│   │   │   └── common/
│   │   └── providers/          # Riverpod Provider
│   └── l10n/                   # 国際化
├── test/
├── pubspec.yaml
└── README.md
```

### 5.3 命名規則
- ファイル: `snake_case.dart`
- クラス: `PascalCase`
- 変数・関数: `camelCase`
- 定数: `lowerCamelCase` または `SCREAMING_SNAKE_CASE`
- Widget名: `XxxScreen` (画面), `XxxWidget` (共通), `XxxCard` (カード)

---

## 6. データモデル

### 6.1 エンティティ定義

#### User
```dart
class User {
  String id;             // UUID
  String email;
  String displayName;
  String? avatarUrl;
  DateTime createdAt;
}
```

#### Trip (旅程)
```dart
class Trip {
  String id;
  String ownerId;        // User.id
  String title;          // 例: "京都2泊3日"
  String? description;
  DateTime startDate;
  DateTime endDate;
  String? coverImageUrl;
  Currency baseCurrency;       // JPY等
  Currency? travelCurrency;    // 海外旅行先通貨
  List<String> memberIds;
  DateTime createdAt;
  DateTime updatedAt;
}
```

#### Day
```dart
class Day {
  String id;
  String tripId;
  int dayNumber;         // 1, 2, 3...
  DateTime date;
  String? note;
}
```

#### Topic (トピック)
```dart
class Topic {
  String id;
  String dayId;
  String? parentTopicId;   // null = 親予定 / 値あり = 子予定
  int orderIndex;          // ドラッグ&ドロップ用
  TopicCategory category;  // 移動/観光/食事/宿泊/その他
  String title;
  String? description;
  DateTime? startTime;
  DateTime? endTime;
  Location? location;
  List<String> photoUrls;
  double? cost;
  Currency? costCurrency;
  bool isCompleted;
  DateTime createdAt;
  DateTime updatedAt;
}

enum TopicCategory { transport, sightseeing, meal, lodging, shopping, other }
```

#### Location
```dart
class Location {
  double latitude;
  double longitude;
  String? name;
  String? address;
}
```

#### ChecklistItem (持ち物)
```dart
class ChecklistItem {
  String id;
  String tripId;
  String category;       // 衣類/電子機器/書類等
  String name;
  bool isChecked;
  int orderIndex;
}
```

#### Reminder
```dart
class Reminder {
  String id;
  String topicId;
  DateTime notifyAt;
  String message;
  bool isEnabled;
}
```

#### Expense (費用記録)
```dart
class Expense {
  String id;
  String topicId;
  double amount;
  Currency currency;
  double? amountInBaseCurrency;  // 円換算済み額
  double? exchangeRate;          // 適用為替レート
  DateTime occurredAt;
  String? paidByUserId;          // 立替メンバー
  List<String> sharedWithUserIds;  // 割り勘対象
}
```

### 6.2 ER図（概要）
```
User 1─────* Trip 1─────* Day 1─────* Topic
                │                       │
                ├──* ChecklistItem      ├──* Photo
                ├──* Member             ├──* Reminder
                                        └──* Expense
```

---

## 7. 画面仕様

### 7.1 画面一覧

| ID | 画面名 | 目的 |
|---|---|---|
| S-01 | スプラッシュ | アプリ起動演出（トリ太くんbanzai） |
| S-02 | 認証 | ログイン/サインアップ |
| S-03 | ホーム | 旅程一覧 |
| S-04 | 旅程詳細 | Day切替・タイムライン表示 |
| S-05 | トピック編集 | 概要/コンテンツの編集 |
| S-06 | 持ち物リスト | チェックリスト |
| S-07 | 費用サマリー | 費用集計・円換算 |
| S-08 | 地図表示 | トピックの位置確認 |
| S-09 | メンバー管理 | 招待・権限設定 |
| S-10 | 設定 | プロフィール・通知設定 |

### 7.2 主要画面のレイアウト

#### S-03 ホーム
```
┌─────────────────────────┐
│ [≡] トリプラ      [🔔][👤] │ ← 固定ヘッダ
├─────────────────────────┤
│  [トリ太アニメ: ばんざい]   │
│  「次の旅行はどこ？」        │
├─────────────────────────┤
│  ┌────────────────┐     │
│  │ 京都 2泊3日      │     │ ← 旅程カード
│  │ 11/15 - 11/17  │     │
│  │ [カバー画像]      │     │
│  └────────────────┘     │
│                         │
│  ┌────────────────┐     │
│  │ 台湾 3泊4日      │     │
│  │ ...            │     │
│  └────────────────┘     │
│                         │
│            [+ 新規作成]   │
└─────────────────────────┘
```

#### S-04 旅程詳細（Dayタイムライン）
```
┌─────────────────────────┐
│ [←] 京都2泊3日   [⚙][···] │ ← 固定ヘッダ
├─────────────────────────┤
│ [Day1] [Day2] [Day3]    │ ← Day切替タブ
├─────────────────────────┤
│ Day1 (11/15 土)          │
│  ☀ 晴れ 18°C             │ ← 天気(F-017)
├─────────────────────────┤
│ 09:00 ●━━━━━━━━━━━     │
│       │ 🚄 東京駅出発   │
│       │  ├ 丸の内南口   │
│       │  └ お土産確認   │
│ 12:00 ●━━━━━━━━━━━     │
│       │ 🍱 京都駅で昼食 │
│       │  📷 [写真3枚]    │
│       │  💰 ¥2,400      │
│ 14:00 ●━━━━━━━━━━━     │
│       │ ⛩ 清水寺観光    │
│       │  📍 地図を見る   │
│  ...                    │
├─────────────────────────┤
│         [+ 予定を追加]    │
└─────────────────────────┘
```
**操作**: 各トピックを長押し→ドラッグで並べ替え／別Dayへ移動

#### S-05 トピック編集
```
┌─────────────────────────┐
│ [×] トピック編集    [保存中...] │
├─────────────────────────┤
│ [概要] [コンテンツ]       │ ← タブ切替（F-004）
├─────────────────────────┤
│ ▼概要タブ                │
│ タイトル: [清水寺観光  ]   │
│ 時刻: [14:00] - [16:00]  │
│ カテゴリ: [観光 ▼]        │
│ 場所: [清水寺  📍]        │
│                         │
│ ▼コンテンツタブ           │
│ メモ: ┌──────────┐       │
│      │ 拝観料... │       │
│      └──────────┘       │
│ 写真: [+] [📷] [📷]      │
│ 費用: [¥400] [JPY ▼]    │
│ 持ち物リンク: [タオル]    │
└─────────────────────────┘
```

---

## 8. UI / UX デザインガイド

### 8.1 カラーパレット
ロゴから抽出したブランドカラー:

| 用途 | カラー | HEX |
|---|---|---|
| プライマリ (トリ太の黄色) | Trita Yellow | `#F4C430` |
| アクセント1 (バンダナの緑) | Bandana Green | `#8FB339` |
| アクセント2 (アプリ説明青) | Sky Blue | `#4FB3D9` |
| 背景 (ダーク) | Deep Navy | `#0D1B2A` |
| 背景 (ライト) | Cream White | `#FFF9E6` |
| テキスト主 | Dark Brown | `#3D2914` |
| テキスト副 | Soft Gray | `#7A7A7A` |
| 警告 | Coral Red | `#FF6B6B` |
| 成功 | Mint Green | `#4ECDC4` |

### 8.2 タイポグラフィ
- 日本語: **「Noto Sans JP」** または「M PLUS Rounded 1c」（丸ゴシックでかわいさ）
- 英数字: **「Quicksand」** または「Nunito」（丸みのあるサンセリフ）
- 見出し: Bold, 24-32sp
- 本文: Regular, 14-16sp

### 8.3 角丸・シャドウ
- 角丸: カード `16px`、ボタン `12px`、入力 `8px`
- シャドウ: 軽め（`elevation: 2-4`）、水彩風の柔らかさを重視

### 8.4 トリ太くんの登場ルール
| 画面 | アニメーション | メッセージ例 |
|---|---|---|
| スプラッシュ | banzai | (なし) |
| ホーム | stand_hold_camera | 「次の旅行はどこ？」 |
| 旅程作成 | map_open | 「どこに行く？」 |
| 写真追加 | camera_shooting | 「いい写真！」 |
| 完了 | heart_eyes | 「楽しい旅になりそう！」 |
| 読み込み中 | thinking | 「少し待ってね...」 |
| 空状態 | jump | 「まだ何もないよ！」 |

---

## 9. Rive アニメーション仕様

### 9.1 State Machine 構造
```
TritaStateMachine
├── States:
│   ├── Entry (初期)
│   ├── Idle (待機・blink_loop)
│   ├── Banzai
│   ├── HoldCamera
│   ├── MapOpen
│   ├── Thinking
│   ├── HeartEyes
│   ├── Jump
│   ├── Run
│   ├── CameraShooting
│   └── Surprised
├── Triggers:
│   ├── triggerBanzai
│   ├── triggerHoldCamera
│   ├── triggerMap
│   └── ... (各状態への遷移)
└── Booleans:
    └── isIdle
```

### 9.2 Flutter組み込み例
```dart
class TritaWidget extends StatefulWidget {
  final TritaState state;  // 表示状態
  // ...
}

class _TritaWidgetState extends State<TritaWidget> {
  late RiveAnimationController _controller;
  SMITrigger? _banzaiTrigger;
  
  @override
  Widget build(BuildContext context) {
    return RiveAnimation.asset(
      'assets/rive/trita.riv',
      stateMachines: ['TritaStateMachine'],
      onInit: _onRiveInit,
    );
  }
}
```

---

## 10. 実装フェーズ

### Phase 0: 基盤構築（1週目）
1. Flutterプロジェクト初期化（`flutter create tripla`）
2. プロジェクト構造作成（lib配下のディレクトリ）
3. 依存パッケージ追加（pubspec.yaml）
4. Supabaseプロジェクト作成・接続設定
5. テーマ定義（カラー・タイポ）
6. go_router設定（画面遷移基盤）
7. **トリ太くんのRive組み込み（最小:`Idle`のみ）**

### Phase 1: コア機能 MVP（2-3週目）
1. 認証画面（S-02）
2. ホーム画面（S-03）+ 旅程CRUD
3. 旅程詳細・Dayタイムライン（S-04）
4. トピック編集（S-05）+ オートセーブ
5. ドラッグ&ドロップ実装
6. ローカルDB（Drift/Isar）統合

### Phase 2: 拡張機能（4-5週目）
1. 写真添付・共有
2. 持ち物リスト（S-06）
3. 費用計算・円換算（S-07）
4. リマインド機能
5. メンバー招待

### Phase 3: 仕上げ（6週目）
1. 地図表示（S-08）
2. トリ太くんアニメ全状態の組み込み
3. オフライン同期
4. 共有リンク機能
5. パフォーマンスチューニング
6. アプリストア申請準備

---

## 11. pubspec.yaml 推奨依存

```yaml
name: tripla
description: 旅の計画を、もっとかんたんに、もっと楽しく！
publish_to: 'none'
version: 0.1.0+1

environment:
  sdk: ^3.4.0

dependencies:
  flutter:
    sdk: flutter
  flutter_localizations:
    sdk: flutter
  
  # State Management
  flutter_riverpod: ^2.5.0
  riverpod_annotation: ^2.3.5
  
  # Routing
  go_router: ^14.0.0
  
  # Animation
  rive: ^0.13.0
  
  # Local DB
  drift: ^2.18.0
  sqlite3_flutter_libs: ^0.5.0
  path_provider: ^2.1.0
  path: ^1.9.0
  
  # Backend
  supabase_flutter: ^2.5.0
  
  # UI
  cached_network_image: ^3.3.0
  image_picker: ^1.1.0
  reorderables: ^0.6.0
  
  # Map
  google_maps_flutter: ^2.6.0
  geolocator: ^11.0.0
  
  # Notification
  flutter_local_notifications: ^17.1.0
  timezone: ^0.9.0
  
  # Utility
  intl: ^0.19.0
  uuid: ^4.4.0
  freezed_annotation: ^2.4.0
  json_annotation: ^4.9.0
  http: ^1.2.0
  collection: ^1.18.0
  
  # Storage
  flutter_secure_storage: ^9.0.0
  shared_preferences: ^2.2.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^4.0.0
  
  # Code Generation
  build_runner: ^2.4.0
  riverpod_generator: ^2.4.0
  freezed: ^2.5.0
  json_serializable: ^6.8.0
  drift_dev: ^2.18.0

flutter:
  uses-material-design: true
  assets:
    - assets/trita/face/
    - assets/trita/body/
    - assets/trita/parts/
    - assets/rive/
    - assets/icons/
    - assets/images/
  fonts:
    - family: NotoSansJP
      fonts:
        - asset: assets/fonts/NotoSansJP-Regular.ttf
        - asset: assets/fonts/NotoSansJP-Bold.ttf
          weight: 700
```

---

## 12. Supabase スキーマ（DDL）

```sql
-- ユーザー (Supabase Authで自動管理されるauth.usersを参照)
create table public.profiles (
  id uuid references auth.users primary key,
  display_name text not null,
  avatar_url text,
  created_at timestamptz default now()
);

-- 旅程
create table public.trips (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid references public.profiles(id) not null,
  title text not null,
  description text,
  start_date date not null,
  end_date date not null,
  cover_image_url text,
  base_currency text default 'JPY',
  travel_currency text,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- メンバー
create table public.trip_members (
  trip_id uuid references public.trips(id) on delete cascade,
  user_id uuid references public.profiles(id),
  role text default 'editor', -- owner/editor/viewer
  primary key (trip_id, user_id)
);

-- Day
create table public.days (
  id uuid primary key default gen_random_uuid(),
  trip_id uuid references public.trips(id) on delete cascade,
  day_number int not null,
  date date not null,
  note text
);

-- トピック
create table public.topics (
  id uuid primary key default gen_random_uuid(),
  day_id uuid references public.days(id) on delete cascade,
  parent_topic_id uuid references public.topics(id) on delete cascade,
  order_index int not null,
  category text not null,
  title text not null,
  description text,
  start_time timestamptz,
  end_time timestamptz,
  latitude double precision,
  longitude double precision,
  location_name text,
  address text,
  cost numeric(10, 2),
  cost_currency text,
  is_completed boolean default false,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- 写真
create table public.topic_photos (
  id uuid primary key default gen_random_uuid(),
  topic_id uuid references public.topics(id) on delete cascade,
  url text not null,
  uploaded_by uuid references public.profiles(id),
  uploaded_at timestamptz default now()
);

-- 持ち物
create table public.checklist_items (
  id uuid primary key default gen_random_uuid(),
  trip_id uuid references public.trips(id) on delete cascade,
  category text,
  name text not null,
  is_checked boolean default false,
  order_index int not null
);

-- リマインダー
create table public.reminders (
  id uuid primary key default gen_random_uuid(),
  topic_id uuid references public.topics(id) on delete cascade,
  notify_at timestamptz not null,
  message text not null,
  is_enabled boolean default true
);

-- 費用
create table public.expenses (
  id uuid primary key default gen_random_uuid(),
  topic_id uuid references public.topics(id) on delete cascade,
  amount numeric(10, 2) not null,
  currency text not null,
  amount_in_base_currency numeric(10, 2),
  exchange_rate numeric(10, 4),
  occurred_at timestamptz not null,
  paid_by_user_id uuid references public.profiles(id),
  shared_with_user_ids uuid[]
);

-- インデックス
create index idx_days_trip on public.days(trip_id);
create index idx_topics_day on public.topics(day_id);
create index idx_topics_parent on public.topics(parent_topic_id);
create index idx_photos_topic on public.topic_photos(topic_id);

-- RLS (Row Level Security)
alter table public.trips enable row level security;
alter table public.days enable row level security;
alter table public.topics enable row level security;
-- ... 適切なポリシーを設定
```

---

## 13. 受け入れ基準（Definition of Done）

各機能は以下を満たして完了とする:
- [ ] 機能が仕様通り動作する
- [ ] iOSとAndroidで動作確認済み
- [ ] 単体テスト・ウィジェットテストを書いている
- [ ] エラーハンドリング実装済み
- [ ] ローディング状態・空状態の表示あり
- [ ] アクセシビリティラベル設定済み
- [ ] トリ太くんの適切なアニメーションが表示される（該当箇所）

---

## 14. Claude Code への指示

### 14.1 実装開始時のコマンド
```bash
cd C:\Projects\tripla
flutter create . --org com.tripla --project-name tripla
```

### 14.2 推奨ワークフロー
1. **Phase 0から順に着手**。フェーズをスキップしない。
2. 各フェーズ完了時に `flutter test` を必ず実行。
3. 大きな変更前に `git commit` で進捗を保存。
4. 不明点はこの要件定義書 → 該当セクションを参照。
5. UIを実装する際は **必ずトリ太くんの表示箇所** を意識する（§8.4 参照）。

### 14.3 CLAUDE.md の作成
プロジェクトルートに `CLAUDE.md` を作成し、以下を記載すること:
- プロジェクト概要（本書 §1 を要約）
- アーキテクチャ（本書 §5.2）
- コーディング規約（本書 §5.3）
- 現在のフェーズ進捗

### 14.4 やってはいけないこと
- ❌ 一括編集機能の実装（仕様で明示禁止）
- ❌ トリ太くんを使わない無機質なUI
- ❌ ヘッダの非固定化
- ❌ 保存ボタンを設ける（オートセーブが原則）

---

## 15. 参考: 既存アセット

### 15.1 トリ太くん画像素材
`assets/trita/` 配下に配置済み（または配置予定）:

#### face/
- `normal_no_neck.png` - 通常表情（首なし）
- `normal_with_neck.png` - 通常表情（首あり、胴体接続用）
- `blink.png` - 瞬き ※未回収
- `wink_left.png` - 左ウインク ※未回収
- `wink_right.png` - 右ウインク ※未回収
- `surprised.png` - 驚き ※未回収
- `happy_open.png` - 大笑い ※未回収
- `heart_eyes.png` - ハート目
- `star_eyes.png` - キラキラ目

#### body/
- `stand_hold_camera.png` - カメラを持って立つ（メイン）
- `thinking.png` - 考えるポーズ
- `camera_shooting.png` - 撮影中
- `banzai.png` - ばんざい
- `jump.png` - ジャンプ ※未回収
- `map_open.png` - 地図を広げる ※未回収
- `run.png` - 走る ※未回収

#### parts/
- リギング用パーツ（horn, camera, leg, hip, body_torso 等）

### 15.2 Riveファイル
- パス: `assets/rive/trita.riv`
- State Machine名: `TritaStateMachine`
- Cadetプラン契約中（$17/月）

---

## 16. 連絡先・備考

- 開発者: gi2gi (Zenn) 
- 環境: Windows
- リポジトリパス: `C:\Projects\tripla`

---

**以上、この設計書を読めばClaude Codeはトリプラの実装を即座に開始できる状態にあります。**

実装中に判断に迷ったら、以下の優先順位で判断すること:
1. **ユーザー体験 > 開発速度** （トリ太くんの愛らしさ最優先）
2. **シンプル > 多機能** （MVP段階では機能を絞る）
3. **オフライン対応 > オンライン依存** （海外旅行を想定）
4. **保存し忘れ防止 > 明示的な保存ボタン** （オートセーブ原則）
