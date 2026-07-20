import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:tripla/data/datasources/local/database.dart';
import 'package:tripla/data/repositories/day_repository.dart';
import 'package:tripla/data/repositories/topic_repository.dart';
import 'package:tripla/data/repositories/trip_repository.dart';
import 'package:tripla/domain/entities/topic_category.dart';
import 'package:tripla/presentation/features/home/widgets/schedule_home_view.dart';
import 'package:tripla/presentation/providers/database_provider.dart';
import 'package:tripla/presentation/providers/month_view_display_provider.dart';

import '../../../../helpers/test_db.dart';

/// 期間予定 (全日) を 1 件シードする。 startTime=00:00 / endTime=23:59 は
/// period_event_dialog.dart の保存仕様に合わせる。
Future<void> seedPeriodEvent(
  TriplaDatabase db, {
  required String title,
  required DateTime start,
  required DateTime end,
}) async {
  final trip = await TripRepository(db).getOrCreateSchedule('local-user');
  final day = await DayRepository(db).ensureDayForDate(
    tripId: trip.id,
    date: start,
  );
  await TopicRepository(db).create(
    dayId: day.id,
    category: TopicCategory.other,
    title: title,
    startTime: DateTime(start.year, start.month, start.day),
    endTime: DateTime(end.year, end.month, end.day, 23, 59),
  );
}

/// ScheduleHomeView を ProviderScope + MaterialApp で包んでポンプする。
Future<void> pumpScheduleHome(WidgetTester tester, TriplaDatabase db) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: const MaterialApp(
        home: Scaffold(body: ScheduleHomeView()),
      ),
    ),
  );
  // drift の Stream (実 async) を進めてから UI に反映させる。
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 100)),
  );
  await tester.pumpAndSettle();
}

/// 表示月 (今月) の中で「週を跨がない 2 日間 (水〜木)」を返す。
/// 月初週の空白やたまたまの週跨ぎでテストが不安定になるのを防ぐ。
({DateTime start, DateTime end}) midWeekSpan() {
  final now = DateTime.now();
  var d = DateTime(now.year, now.month, 8);
  while (d.weekday != DateTime.wednesday) {
    d = DateTime(d.year, d.month, d.day + 1);
  }
  return (start: d, end: DateTime(d.year, d.month, d.day + 1));
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ja');
  });

  testWidgets('既定 (bar モード) では期間予定が連続バーとして描画される', (tester) async {
    final handle = tester.ensureSemantics();
    late TriplaDatabase db;
    final span = midWeekSpan();
    await tester.runAsync(() async {
      db = createTestDatabase();
      await seedPeriodEvent(db, title: '社員旅行', start: span.start, end: span.end);
    });

    await pumpScheduleHome(tester, db);

    // バーは週行内で 1 本 → タイトルは 1 回だけ現れる。
    expect(find.text('社員旅行'), findsOneWidget);
    // 旧ピル表示の継続プレフィックス (→ / ⤴) は出ない。
    expect(find.textContaining('⤴'), findsNothing);
    expect(find.textContaining('→'), findsNothing);
    // ARIA 相当: Semantics ラベルが付与されている。
    expect(
      find.bySemanticsLabel(RegExp('期間予定 社員旅行')),
      findsOneWidget,
    );

    handle.dispose();
    await tester.runAsync(db.close);
  });

  testWidgets('切替ボタンで旧ピル表示に切り替わり、再タップでバー表示に戻る', (tester) async {
    late TriplaDatabase db;
    final span = midWeekSpan();
    await tester.runAsync(() async {
      db = createTestDatabase();
      await seedPeriodEvent(db, title: '出張', start: span.start, end: span.end);
    });

    await pumpScheduleHome(tester, db);

    // bar → legacyPill
    await tester.tap(find.byTooltip('旧ピル表示に切り替え'));
    await tester.pumpAndSettle();
    // 旧表示: 日毎ピル (最終日は ⤴ プレフィックス) が復活する。
    expect(find.textContaining('⤴'), findsOneWidget);
    expect(find.text('出張'), findsOneWidget); // 開始日のピル

    // legacyPill → bar
    await tester.tap(find.byTooltip('連続バー表示に切り替え'));
    await tester.pumpAndSettle();
    expect(find.textContaining('⤴'), findsNothing);
    expect(find.text('出張'), findsOneWidget); // バー 1 本

    await tester.runAsync(db.close);
  });

  testWidgets('幅 320px 以下では bar モード指定でも旧ピル表示にフォールバックする', (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final handle = tester.ensureSemantics();
    late TriplaDatabase db;
    final span = midWeekSpan();
    await tester.runAsync(() async {
      db = createTestDatabase();
      await seedPeriodEvent(db, title: '帰省', start: span.start, end: span.end);
    });

    await pumpScheduleHome(tester, db);

    // Provider は bar のままだが表示は旧ピル (⤴ プレフィックスあり / バーの Semantics なし)。
    final container = ProviderScope.containerOf(
      tester.element(find.byType(ScheduleHomeView)),
    );
    expect(
      container.read(monthEventDisplayModeProvider),
      MonthEventDisplayMode.bar,
    );
    expect(find.textContaining('⤴'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('期間予定 帰省')), findsNothing);

    handle.dispose();
    await tester.runAsync(db.close);
  });

  testWidgets('前月から続く期間予定 (月跨ぎ) もバーとして表示される', (tester) async {
    final handle = tester.ensureSemantics();
    late TriplaDatabase db;
    final now = DateTime.now();
    await tester.runAsync(() async {
      db = createTestDatabase();
      // 前月 26 日 〜 今月 2 日: 表示月の外から続くイベント。
      await seedPeriodEvent(
        db,
        title: '長期出張',
        start: DateTime(now.year, now.month - 1, 26),
        end: DateTime(now.year, now.month, 2),
      );
    });

    await pumpScheduleHome(tester, db);

    expect(find.bySemanticsLabel(RegExp('期間予定 長期出張')), findsOneWidget);
    expect(find.text('長期出張'), findsOneWidget);

    handle.dispose();
    await tester.runAsync(db.close);
  });

  testWidgets('バーはキーボード操作 (Tab → Enter) で編集ダイアログを開ける', (tester) async {
    late TriplaDatabase db;
    final span = midWeekSpan();
    await tester.runAsync(() async {
      db = createTestDatabase();
      await seedPeriodEvent(db, title: '合宿', start: span.start, end: span.end);
    });

    await pumpScheduleHome(tester, db);

    // Tab でフォーカスを移動し、 バー (Semantics label に「合宿」を含む
    // Semantics ウィジェットの子孫 InkWell) に到達したら Enter で起動する。
    var focusedBar = false;
    for (var i = 0; i < 80 && !focusedBar; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      final ctx = tester.binding.focusManager.primaryFocus?.context;
      if (ctx == null) continue;
      ctx.visitAncestorElements((el) {
        final w = el.widget;
        if (w is Semantics &&
            (w.properties.label ?? '').contains('期間予定 合宿')) {
          focusedBar = true;
          return false;
        }
        return true;
      });
    }
    expect(focusedBar, isTrue, reason: 'Tab 移動でバーにフォーカスできること');

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text('期間予定を編集'), findsOneWidget);

    await tester.runAsync(db.close);
  });

  testWidgets('100 件の期間予定でも例外なく描画でき月送りも動作する', (tester) async {
    late TriplaDatabase db;
    final now = DateTime.now();
    await tester.runAsync(() async {
      db = createTestDatabase();
      final trip = await TripRepository(db).getOrCreateSchedule('local-user');
      final dayRepo = DayRepository(db);
      final topicRepo = TopicRepository(db);
      for (var i = 0; i < 100; i++) {
        final start = DateTime(now.year, now.month, 1 + (i % 4) * 7);
        final end = DateTime(start.year, start.month, start.day + 2);
        final day = await dayRepo.ensureDayForDate(
          tripId: trip.id,
          date: start,
        );
        await topicRepo.create(
          dayId: day.id,
          category: TopicCategory.other,
          title: '予定$i',
          startTime: start,
          endTime: DateTime(end.year, end.month, end.day, 23, 59),
        );
      }
    });

    await pumpScheduleHome(tester, db);

    // 行単位オーバーフロー「+N 件」が表示される (maxVisibleLanes=3 超過分)。
    expect(find.textContaining('+'), findsWidgets);
    expect(tester.takeException(), isNull);

    // 月送り (次へ → 前へ) しても例外が出ない。
    await tester.tap(find.byTooltip('次へ'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('前へ'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.runAsync(db.close);
  });
}
