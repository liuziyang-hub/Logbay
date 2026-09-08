import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../session/device_session_controller.dart';
import 'terminal_controller.dart';

/// Manages the ordered list of terminal tabs for one device session, the same
/// way `LogSessionManager` does for log tabs: the first tab is permanent, any
/// number of extra tabs can be opened and closed.
class TerminalSessionManager extends ChangeNotifier {
  TerminalSessionManager({required DeviceSessionController session})
    : _session = session {
    _tabs.add(TerminalController(session));
  }

  final DeviceSessionController _session;
  final List<TerminalController> _tabs = [];
  int _selectedIndex = 0;
  bool _disposed = false;

  /// Width of the terminal pane in the workspace row.
  double paneWidth = 520;

  List<TerminalController> get tabs => List.unmodifiable(_tabs);
  int get selectedIndex => _selectedIndex;
  TerminalController get selectedTab => _tabs[_selectedIndex];

  /// Human-readable label for the tab at [index].
  String labelFor(int index) {
    final tab = _tabs[index];
    if (tab.isPinnedElsewhere) return tab.targetDevice.displayName;
    return index == 0 ? '终端' : '终端 ${index + 1}';
  }

  /// The first tab is permanent; the rest can be closed.
  bool canClose(int index) => index > 0 && index < _tabs.length;

  void addTab() {
    if (_disposed) return;
    _tabs.add(TerminalController(_session));
    _selectedIndex = _tabs.length - 1;
    _notify();
  }

  void selectTab(int index) {
    if (index == _selectedIndex || index < 0 || index >= _tabs.length) return;
    _selectedIndex = index;
    _notify();
  }

  void closeTab(int index) {
    if (!canClose(index)) return;
    _tabs[index].dispose();
    _tabs.removeAt(index);
    _selectedIndex = _selectedIndex.clamp(0, math.max(0, _tabs.length - 1));
    _notify();
  }

  void setPaneWidth(double width) {
    final clamped = width.clamp(360.0, 1200.0);
    if (clamped == paneWidth) return;
    paneWidth = clamped;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    for (final tab in _tabs) {
      tab.dispose();
    }
    super.dispose();
  }
}
