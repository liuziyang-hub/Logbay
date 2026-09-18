import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:eagly/services/tools/ios_runtime_broker.dart';
import 'package:eagly/services/tools/pymobiledevice3_launcher.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeChild implements IosRuntimeChildProcess {
  _FakeChild({String output = '', this.onKill})
    : _stdout = Stream<List<int>>.value(utf8.encode(output));

  final Stream<List<int>> _stdout;
  final void Function()? onKill;
  final Completer<int> completion = Completer<int>();

  @override
  Future<int> get exitCode => completion.future;

  @override
  Stream<List<int>> get stderr => const Stream<List<int>>.empty();

  @override
  Stream<List<int>> get stdout => _stdout;

  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    onKill?.call();
    if (!completion.isCompleted) completion.complete(-1);
    return true;
  }
}

void main() {
  test('serializes one-shot commands for the same device', () async {
    final children = <_FakeChild>[];
    final broker = IosRuntimeBroker(
      resolveCommand: () async => const Pymobiledevice3Command('pmd3', []),
      startProcess: (_, _, {required environment}) async {
        final child = _FakeChild(
          output: '${environment['PYMOBILEDEVICE3_UDID']}',
        );
        children.add(child);
        return child;
      },
    );

    final first = broker.run('device-a', const ['first']);
    await Future<void>.delayed(Duration.zero);
    final second = broker.run('device-a', const ['second']);
    await Future<void>.delayed(Duration.zero);
    expect(children, hasLength(1));

    children.first.completion.complete(0);
    expect((await first).stdout, 'device-a');
    await Future<void>.delayed(Duration.zero);
    expect(children, hasLength(2));
    children.last.completion.complete(0);
    await second;
  });

  test('kills an upstream process when the command times out', () async {
    var killed = false;
    final child = _FakeChild(onKill: () => killed = true);
    final broker = IosRuntimeBroker(
      resolveCommand: () async => const Pymobiledevice3Command('pmd3', []),
      startProcess: (_, _, {required environment}) async => child,
    );

    await expectLater(
      broker.run('device-a', const [
        'slow',
      ], timeout: const Duration(milliseconds: 10)),
      throwsA(isA<TimeoutException>()),
    );
    expect(killed, isTrue);
  });
}
