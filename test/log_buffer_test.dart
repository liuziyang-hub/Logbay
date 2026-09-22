import 'package:flutter_test/flutter_test.dart';
import 'package:eagly/utils/log_buffer.dart';

void main() {
  test('retains only the newest entries up to the line limit', () {
    final buffer = LogBuffer<String>(baseCapacity: 3);

    for (final value in ['a', 'b', 'c', 'd']) {
      buffer.append(value);
    }

    expect(buffer.getLogs(), ['b', 'c', 'd']);
    expect(buffer.bytes, 0);
  });

  test('evicts oldest entries when the byte limit is reached', () {
    final buffer = LogBuffer<String>(
      baseCapacity: 10,
      maxBytes: 5,
      sizeOf: (value) => value.length,
    );

    buffer.append('aa');
    buffer.append('bbb');
    expect(buffer.getLogs(), ['aa', 'bbb']);

    expect(buffer.append('cccc'), ['aa', 'bbb']);
    expect(buffer.getLogs(), ['cccc']);
    expect(buffer.bytes, 4);
  });

  test('keeps one entry even when it exceeds the byte limit', () {
    final buffer = LogBuffer<String>(
      baseCapacity: 10,
      maxBytes: 2,
      sizeOf: (value) => value.length,
    );

    expect(buffer.append('large'), isEmpty);
    expect(buffer.getLogs(), ['large']);
  });
}
