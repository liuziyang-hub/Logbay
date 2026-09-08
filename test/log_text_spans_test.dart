import 'package:eagly/utils/log_text_spans.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('splits emoji into Segoe/Apple emoji spans', () {
    const style = TextStyle(fontFamily: 'Microsoft YaHei UI', fontSize: 12);
    final spans = buildLogInlineSpans(
      '广告加载失败❌，No fill. ☝️ 更新成功🔴',
      style,
    );

    expect(spans, isNotEmpty);
    final fonts = spans
        .whereType<TextSpan>()
        .map((s) => s.style?.fontFamily)
        .toSet();
    expect(fonts, contains('Microsoft YaHei UI'));
    expect(fonts, contains(logEmojiFontFamily));

    final emojiTexts = spans
        .whereType<TextSpan>()
        .where((s) => s.style?.fontFamily == logEmojiFontFamily)
        .map((s) => s.text)
        .join();
    expect(emojiTexts, contains('❌'));
    expect(emojiTexts, contains('☝️'));
    expect(emojiTexts, contains('🔴'));
  });
}
