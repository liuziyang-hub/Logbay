import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:win32/win32.dart';

/// Detects display drivers that are known to destabilize Flutter textures.
class WindowsDisplayCompatibility {
  const WindowsDisplayCompatibility._();

  static final bool _detectedSafeGraphicsMode = _detect();

  @visibleForTesting
  static bool? safeGraphicsModeOverride;

  static bool get requiresSafeGraphicsMode =>
      safeGraphicsModeOverride ?? _detectedSafeGraphicsMode;

  @visibleForTesting
  static bool containsVirtualDisplay(Iterable<String> descriptions) {
    const markers = [
      'oray',
      'sunlogin',
      'virtual display',
      'indirect display',
      'spacedesk',
      'parsec virtual',
      'iddsample',
    ];
    return descriptions.any((description) {
      final normalized = description.toLowerCase().replaceAll(
        RegExp(r'\s+'),
        ' ',
      );
      return markers.any(normalized.contains);
    });
  }

  static bool _detect() {
    if (!Platform.isWindows) return false;
    final display = calloc<DISPLAY_DEVICE>();
    try {
      final descriptions = <String>[];
      for (var index = 0; ; index++) {
        display.ref.cb = sizeOf<DISPLAY_DEVICE>();
        if (EnumDisplayDevices(nullptr, index, display, 0) == 0) break;
        descriptions.addAll([
          display.ref.DeviceName,
          display.ref.DeviceString,
          display.ref.DeviceID,
          display.ref.DeviceKey,
        ]);
      }
      return containsVirtualDisplay(descriptions);
    } on Object {
      return false;
    } finally {
      calloc.free(display);
    }
  }
}
