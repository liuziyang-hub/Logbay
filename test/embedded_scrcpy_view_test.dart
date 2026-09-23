import 'package:eagly/features/mirror/components/embedded_scrcpy_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('flutter_scrcpy/video');
  final calls = <MethodCall>[];
  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return call.method == 'updateEmbedded' ? true : null;
        });
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  testWidgets('positions at physical pixels and hides when removed', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 200,
            height: 250,
            child: EmbeddedScrcpyView(processId: 123),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 110));
    final update = calls.firstWhere((c) => c.method == 'updateEmbedded');
    expect(update.arguments['width'], 400);
    expect(update.arguments['height'], 500);
    expect(update.arguments['pid'], 123);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(calls.last.method, 'hideEmbedded');
    expect(tester.takeException(), isNull);
  });

  testWidgets('hides beneath a dialog and restores after dismissal', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: EmbeddedScrcpyView(processId: 321)),
      ),
    );
    await tester.pump(const Duration(milliseconds: 110));
    final context = tester.element(find.byType(EmbeddedScrcpyView));
    final dialog = showDialog<void>(
      context: context,
      builder: (_) => const AlertDialog(content: Text('测试弹窗')),
    );
    await tester.pump(const Duration(milliseconds: 110));
    expect(calls.last.method, 'hideEmbedded');
    Navigator.of(context).pop();
    await dialog;
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 110));
    expect(calls.last.method, 'updateEmbedded');
    await tester.pumpWidget(const SizedBox());
  });
}
