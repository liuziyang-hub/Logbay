import 'package:eagly/features/tips/tip.dart';
import 'package:eagly/features/tips/tips_controller.dart';
import 'package:eagly/features/tips/tips_header_panel.dart';
import 'package:eagly/presentation/theme/app_theme.dart';
import 'package:eagly/services/preferences_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _tips = [
  Tip(
    id: 'a',
    icon: Icons.view_column_outlined,
    title: '隐藏不常用的列',
    detail: '右键点击任意列标题即可显示或隐藏各列。',
    actionHint: '在日志视图中右键点击列标题',
  ),
];

const _twoTips = [
  Tip(id: 'a', icon: Icons.abc, title: '第一条提示', detail: '详情甲'),
  Tip(id: 'b', icon: Icons.abc, title: '第二条提示', detail: '详情乙'),
];

Widget _host(TipsController controller) {
  // The header only reserves room for tips on a reasonably wide window, so the
  // pump surface must exceed the panel's minimum-width threshold.
  return MaterialApp(
    theme: AppTheme.darkTheme,
    home: Scaffold(
      body: Row(children: [TipsHeaderPanel(controller: controller)]),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await PreferencesService.init();
  });

  useWideWindow(WidgetTester tester) {
    tester.view.physicalSize = const Size(1400, 700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  testWidgets('renders the current tip title inline', (tester) async {
    useWideWindow(tester);
    final controller = TipsController(tips: _tips);
    addTearDown(controller.dispose);

    await tester.pumpWidget(_host(controller));

    expect(find.text('隐藏不常用的列'), findsOneWidget);
  });

  testWidgets('hides on a narrow window', (tester) async {
    tester.view.physicalSize = const Size(700, 700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final controller = TipsController(tips: _tips);
    addTearDown(controller.dispose);

    await tester.pumpWidget(_host(controller));

    expect(find.text('隐藏不常用的列'), findsNothing);
  });

  testWidgets('close button hides it for the session', (tester) async {
    useWideWindow(tester);
    final controller = TipsController(tips: _tips);
    addTearDown(controller.dispose);

    await tester.pumpWidget(_host(controller));
    await tester.tap(find.byTooltip('隐藏提示'));
    await tester.pumpAndSettle();

    expect(find.text('隐藏不常用的列'), findsNothing);
    expect(controller.visible, isFalse);
  });

  testWidgets('tapping the body opens the detail dialog', (tester) async {
    useWideWindow(tester);
    final controller = TipsController(tips: _tips);
    addTearDown(controller.dispose);

    await tester.pumpWidget(_host(controller));
    await tester.tap(find.text('隐藏不常用的列'));
    await tester.pumpAndSettle();

    expect(find.text('右键点击任意列标题即可显示或隐藏各列。'), findsOneWidget);
    expect(find.text('在日志视图中右键点击列标题'), findsOneWidget);
    expect(find.text('知道了'), findsOneWidget);
  });

  testWidgets('detail dialog chevrons browse the tip pool in place', (
    tester,
  ) async {
    useWideWindow(tester);
    final controller = TipsController(tips: _twoTips);
    addTearDown(controller.dispose);

    await tester.pumpWidget(_host(controller));
    await tester.tap(find.text('第一条提示'));
    await tester.pumpAndSettle();

    // The dialog opens on the same tip the pill displayed.
    expect(find.text('详情甲'), findsOneWidget);

    await tester.tap(find.byTooltip('下一条提示'));
    await tester.pumpAndSettle();
    expect(find.text('详情乙'), findsOneWidget);

    // Wraps around, and backwards too.
    await tester.tap(find.byTooltip('下一条提示'));
    await tester.pumpAndSettle();
    expect(find.text('详情甲'), findsOneWidget);

    await tester.tap(find.byTooltip('上一条提示'));
    await tester.pumpAndSettle();
    expect(find.text('详情乙'), findsOneWidget);

    // Browsing in the dialog also moves the pill behind it.
    expect(controller.currentTip?.id, 'b');
  });

  testWidgets('detail dialog hides chevrons when there is only one tip', (
    tester,
  ) async {
    useWideWindow(tester);
    final controller = TipsController(tips: _tips);
    addTearDown(controller.dispose);

    await tester.pumpWidget(_host(controller));
    await tester.tap(find.text('隐藏不常用的列'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('上一条提示'), findsNothing);
    expect(find.byTooltip('下一条提示'), findsNothing);
  });

  testWidgets('three-dot menu can turn tips off behind a confirmation', (
    tester,
  ) async {
    useWideWindow(tester);
    final controller = TipsController(tips: _tips);
    addTearDown(controller.dispose);

    await tester.pumpWidget(_host(controller));

    // Open the ⋮ menu.
    await tester.tap(find.byTooltip('提示选项'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('关闭提示…'));
    await tester.pumpAndSettle();

    // The confirmation guard appears; nothing has changed yet.
    expect(find.text('关闭提示？'), findsOneWidget);
    expect(controller.enabled, isTrue);

    // Confirm.
    await tester.tap(find.widgetWithText(FilledButton, '关闭'));
    await tester.pumpAndSettle();

    expect(controller.enabled, isFalse);
    expect(find.text('隐藏不常用的列'), findsNothing);
    expect(PreferencesService.tipsEnabled, isFalse);
  });

  testWidgets('cancelling the confirmation keeps tips on', (tester) async {
    useWideWindow(tester);
    final controller = TipsController(tips: _tips);
    addTearDown(controller.dispose);

    await tester.pumpWidget(_host(controller));

    await tester.tap(find.byTooltip('提示选项'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('关闭提示…'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, '取消'));
    await tester.pumpAndSettle();

    expect(controller.enabled, isTrue);
    expect(find.text('隐藏不常用的列'), findsOneWidget);
  });
}
