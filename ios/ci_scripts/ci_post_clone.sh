#!/bin/sh
# Xcode Cloud: clone 直後に実行される（このファイルの場所と名前は Xcode Cloud の決まり。
# ci_scripts は .xcworkspace と同じ階層 = ios/ に置く必要がある）。
#
# Xcode Cloud の Mac には Flutter も CocoaPods の依存も無く、リポジトリにも生成物
# （ios/Flutter/Generated.xcconfig、ios/Pods/）は含まれない。ここで用意しないと
# 「could not find included file 'Generated.xcconfig'」や
# 「Unable to load contents of file list: .../Pods-Runner-frameworks-Release-*.xcfilelist」で
# アーカイブが失敗する。
# - Flutter stable を取得し、flutter pub get で Generated.xcconfig を作る
# - pod install で Pods/ と xcfilelist を作る
# - ビルド番号は Xcode Cloud の通し番号（CI_BUILD_NUMBER）+ 100 を使う。pubspec.yaml の
#   ビルド番号（+N）のままだと毎回同じ番号になり、TestFlight が
#   「同じビルド番号」として2回目以降のアップロードを受け付けないため。
#   GitHub配信時代の既存ビルド（〜12）との衝突回避のため +100 する。
#   Xcode Cloud の通し番号に連動して単調増加する（CI_BUILD_NUMBER 未設定時は 1 + 100 = 101）
#
# NOTE: ここでは xcodebuild を呼ぶコマンド（flutter build ios --config-only や、Flutter の
# Swift Package Manager 連携）を使わない。Xcode Cloud ではこの post-clone 段階で xcodebuild を
# 呼ぶと失敗する実績がある（--config-only で exit code 15、別プロジェクトでは
# 「PIF transfer session (operation in progress?)」で失敗）。同じスクリプトが GitHub の macOS
# ランナーでは通るため、Xcode Cloud 固有の制約と判断している。
# Flutter 公式の Xcode Cloud 向け手順（precache → pub get → pod install）に合わせる。
#
# NOTE: 各ステップは失敗すると固有の終了コードで終わる（下の表）。Xcode Cloud の画面には
# 「Running ci_post_clone.sh script failed (exited with code N)」しか出ず、ログを見られない
# ことがあるため、N だけでどのステップで止まったか分かるようにしている。
#   11 リポジトリ直下へ移動            12 CocoaPods のインストール
#   13 Flutter の取得                  14 Swift Package Manager 連携をオフにする
#   15 flutter precache               16 flutter pub get
#   17 ビルド番号の設定                18 ios へ移動
#   19 pod install
#   ※ 17 のビルド番号は CI_BUILD_NUMBER + 100。GitHub配信時代の既存ビルド（〜12）との
#     衝突回避のため +100 する。Xcode Cloud の通し番号に連動して単調増加する

# step <終了コード> <説明> <コマンド...>: コマンドが失敗したら、説明を出して固有のコードで終わる
step() {
  code="$1"
  label="$2"
  shift 2
  echo "==> [$code] $label"
  "$@" || {
    echo "error: ci_post_clone.sh: [$code] $label が失敗しました: $*" >&2
    exit "$code"
  }
}

# set_build_number <番号>: Generated.xcconfig の FLUTTER_BUILD_NUMBER を書き換え、書き換わったことを確かめる
set_build_number() {
  [ -n "$1" ] &&
    sed -i '' "s/^FLUTTER_BUILD_NUMBER=.*/FLUTTER_BUILD_NUMBER=$1/" ios/Flutter/Generated.xcconfig &&
    grep -qx "FLUTTER_BUILD_NUMBER=$1" ios/Flutter/Generated.xcconfig
}

# NOTE: Xcode のバージョンは xcodebuild を呼ばずに Info.plist から読む（上の NOTE のとおり、この段階では xcodebuild を使わない）
echo "==> 環境: macOS $(sw_vers -productVersion 2>/dev/null) $(uname -m) / Xcode $(defaults read "$(xcode-select -p)/../Info" CFBundleShortVersionString 2>/dev/null)"

# tripla は Flutter プロジェクトがリポジトリ直下にある（サブディレクトリへの移動は不要）
step 11 "リポジトリ直下へ移動" cd "$CI_PRIMARY_REPOSITORY_PATH"

export HOMEBREW_NO_AUTO_UPDATE=1
if ! command -v pod >/dev/null 2>&1; then
  step 12 "CocoaPods のインストール" brew install cocoapods
fi

step 13 "Flutter の取得" git clone https://github.com/flutter/flutter.git --depth 1 -b stable "$HOME/flutter"
export PATH="$HOME/flutter/bin:$PATH"

# NOTE: Swift Package Manager 連携がオンだと、Flutter はプラグインを Swift パッケージとして
# プロジェクトに追加するために xcodebuild を呼ぶ。オフにしてすべて CocoaPods で入れる
# （リポジトリの ios プロジェクトも CocoaPods 前提）
step 14 "Swift Package Manager 連携をオフにする" flutter config --no-enable-swift-package-manager
step 15 "flutter precache" flutter precache --ios
step 16 "flutter pub get" flutter pub get
step 17 "ビルド番号の設定" set_build_number "$(expr "${CI_BUILD_NUMBER:-1}" + 100)"

step 18 "ios へ移動" cd ios
step 19 "pod install" pod install

exit 0
