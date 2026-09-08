import 'dart:io';

import 'package:characters/characters.dart';
import 'package:flutter/painting.dart';

/// Builds [TextSpan] children so emoji/symbols use a color-emoji face while
/// CJK/Latin keep the log body font. Windows YaHei often maps emoji codepoints
/// to empty/.notdef glyphs, which blocks `fontFamilyFallback` — so emoji must
/// be a separate span with `Segoe UI Emoji` (Android logcat + iOS syslog).
List<InlineSpan> buildLogInlineSpans(
  String text,
  TextStyle style, {
  TextStyle? Function(TextStyle base)? styleOverride,
}) {
  if (text.isEmpty) {
    return const [];
  }

  final emojiBase = style.copyWith(
    fontFamily: logEmojiFontFamily,
    fontFamilyFallback: logEmojiFontFallbacks,
  );

  final spans = <InlineSpan>[];
  final buffer = StringBuffer();
  var bufferIsEmoji = false;

  void flush() {
    if (buffer.isEmpty) return;
    final base = bufferIsEmoji ? emojiBase : style;
    final applied = styleOverride?.call(base) ?? base;
    spans.add(TextSpan(text: buffer.toString(), style: applied));
    buffer.clear();
  }

  for (final grapheme in text.characters) {
    final isEmoji = _graphemeLooksLikeEmoji(grapheme);
    if (buffer.isNotEmpty && isEmoji != bufferIsEmoji) {
      flush();
    }
    bufferIsEmoji = isEmoji;
    buffer.write(grapheme);
  }
  flush();
  return spans;
}

String get logEmojiFontFamily {
  if (Platform.isWindows) return 'Segoe UI Emoji';
  if (Platform.isMacOS) return 'Apple Color Emoji';
  return 'Noto Color Emoji';
}

List<String> get logEmojiFontFallbacks {
  if (Platform.isWindows) {
    return const ['Segoe UI Symbol', 'Segoe UI Emoji'];
  }
  if (Platform.isMacOS) {
    return const ['Apple Color Emoji', 'Symbol'];
  }
  return const ['Noto Color Emoji', 'Noto Emoji'];
}

bool _graphemeLooksLikeEmoji(String grapheme) {
  for (final unit in grapheme.runes) {
    if (_codePointLooksLikeEmoji(unit)) return true;
  }
  return false;
}

bool _codePointLooksLikeEmoji(int cp) {
  // Variation selector / ZWJ keep the cluster in emoji mode when present.
  if (cp == 0xFE0F || cp == 0x200D) return true;
  // Dingbats (❌ ✅ ✨ …), misc symbols (☝️ ⚠️ ☀️ …)
  if (cp >= 0x2600 && cp <= 0x27BF) return true;
  // Misc symbols and arrows often used as status marks
  if (cp >= 0x2B00 && cp <= 0x2BFF) return true;
  // Enclosed alphanumerics / regional indicators
  if (cp >= 0x1F1E0 && cp <= 0x1F1FF) return true;
  // Main emoji blocks
  if (cp >= 0x1F300 && cp <= 0x1FAFF) return true;
  // Supplemental (newer emoji)
  if (cp >= 0x1F000 && cp <= 0x1F2FF) return true;
  return false;
}
