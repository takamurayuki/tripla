import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripla/app.dart';

void main() {
  testWidgets('Splash screen shows app title', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: TriplaApp()),
    );
    // 初期フレームでスプラッシュが表示される。
    await tester.pump();
    expect(find.text('トリプラ'), findsOneWidget);
  });
}
