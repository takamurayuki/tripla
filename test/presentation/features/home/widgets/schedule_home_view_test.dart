import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:tripla/domain/entities/topic_category.dart';
import 'package:tripla/presentation/features/home/widgets/schedule_home_view.dart';
import 'package:tripla/presentation/providers/database_provider.dart';
import 'package:tripla/presentation/providers/day_providers.dart';
import 'package:tripla/presentation/providers/topic_providers.dart';
import 'package:tripla/presentation/providers/trip_providers.dart';

import '../../../../helpers/test_db.dart';

const _ownerId = 'local-user';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ja');
  });

  Future<ProviderContainer> seedMultiDayEvent() async {
    final db = createTestDatabase();
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);

    final trip =
        await container.read(tripRepositoryProvider).getOrCreateSchedule(
              _ownerId,
            );
    final today = DateTime.now();
    // 月末付近だと start+2 日が翌月にはみ出し、月ビューの表示対象外
    // (空セル) になってテストが date-dependent で不安定になるため、
    // どの月でも安全な月初寄りの日付に固定する。
    final start = DateTime(today.year, today.month, 5);
    final day = await container
        .read(dayRepositoryProvider)
        .ensureDayForDate(tripId: trip.id, date: start);
    final end = start.add(const Duration(days: 2));
    await container.read(topicRepositoryProvider).create(
          dayId: day.id,
          category: TopicCategory.other,
          title: '出張旅行',
          startTime: DateTime(start.year, start.month, start.day, 0, 0),
          endTime: DateTime(end.year, end.month, end.day, 23, 59),
        );
    return container;
  }

  Future<void> pumpAt(
    WidgetTester tester,
    ProviderContainer container,
    Size size,
  ) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(body: ScheduleHomeView()),
        ),
      ),
    );
    // scheduleTripProvider / tripTopicsProvider の Stream が流れるのを待つ。
    await tester.pumpAndSettle();
  }

  testWidgets('広い画面では複数日予定が連続バー (Semantics button) として表示される',
      (tester) async {
    final container = await seedMultiDayEvent();
    await pumpAt(tester, container, const Size(800, 1000));

    expect(
      find.bySemanticsLabel(RegExp('出張旅行')),
      findsWidgets,
    );
    // 新表示 (bar) がデフォルトなので、旧ピル特有の継続矢印プレフィックスは出ない。
    expect(find.textContaining('→ 出張旅行'), findsNothing);
  });

  testWidgets('表示モード切替ボタンで旧ピル表示に戻せる', (tester) async {
    final container = await seedMultiDayEvent();
    await pumpAt(tester, container, const Size(800, 1000));

    final toggle = find.byTooltip('旧表示 (日毎ピル) に切り替え');
    expect(toggle, findsOneWidget);
    await tester.tap(toggle);
    await tester.pumpAndSettle();

    // 旧表示に切り替わると継続日を示す "→ " プレフィックス付きピルが現れる。
    expect(find.textContaining('→ 出張旅行'), findsWidgets);
    expect(find.byTooltip('新表示 (連続バー) に切り替え'), findsOneWidget);
  });

  testWidgets('幅 320px 以下では表示モードに関わらず旧ピル表示にフォールバックする',
      (tester) async {
    final container = await seedMultiDayEvent();
    await pumpAt(tester, container, const Size(300, 1000));

    // 320px 以下では bar モードのままでもレガシー表示 (継続矢印プレフィックス) になる。
    expect(find.textContaining('→ 出張旅行'), findsWidgets);
  });
}
