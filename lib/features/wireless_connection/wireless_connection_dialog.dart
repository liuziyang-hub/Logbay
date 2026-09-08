import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../../data/device.dart';
import 'data/wireless_debug_models.dart';
import '../../session/device_session_manager.dart';
import '../../presentation/components/eagly_dialog.dart';
import 'components/discovered_wireless_target.dart';
import 'components/wireless_discovery_card.dart';
import 'components/wireless_feedback_banner.dart';
import 'components/wireless_ios_section.dart';
import 'components/wireless_manual_section.dart';
import 'components/wireless_placeholder_card.dart';
import 'components/wireless_qr_panel.dart';
import 'components/wireless_selected_device_panel.dart';
import 'wireless_connection_controller.dart';

class WirelessConnectionDialog extends StatefulWidget {
  const WirelessConnectionDialog({
    super.key,
    required this.manager,
    required this.onShowSnackBar,
  });

  final DeviceSessionManager manager;
  final ValueChanged<String> onShowSnackBar;

  @override
  State<WirelessConnectionDialog> createState() =>
      _WirelessConnectionDialogState();
}

class _WirelessConnectionDialogState extends State<WirelessConnectionDialog> {
  late final TextEditingController _pairAddressController;
  late final TextEditingController _pairingCodeController;
  late final TextEditingController _connectAddressController;
  late final wirelessController = WirelessConnectionController(
    devicesRepository: manager.repository,
    onDevicesApplied: (_) async {},
    onActivateDevice: (device) async => manager.select(device.id),
    selectedDeviceIdProvider: () => manager.selectedId,
    isRunningProvider: () {
      final session = manager.selected;
      return session != null &&
          session.isActivated &&
          (session.logSessionManager.selectedTab?.isRunning ?? false);
    },
  );

  var _section = _WirelessDialogSection.nearby;
  String? _selectedDiscoveryHost;
  String? _fallbackConnectHost;
  var _showManualConnectSection = false;

  DeviceSessionManager get manager => widget.manager;

  List<DiscoveredWirelessTarget> get _discoveredTargets {
    final groupedServices = <String, List<WirelessDebugService>>{};
    for (final service in wirelessController.wirelessServices) {
      groupedServices.putIfAbsent(service.host, () => []).add(service);
    }

    final targets = groupedServices.entries
        .map((entry) {
          final pairingService = entry.value.firstWhereOrNull(
            (service) => service.type == WirelessDebugServiceType.pairing,
          );
          final connectServices = entry.value
              .where(
                (service) => service.type == WirelessDebugServiceType.connect,
              )
              .sortedBy<num>((service) => service.port)
              .toList(growable: false);

          return DiscoveredWirelessTarget(
            host: entry.key,
            pairingService: pairingService,
            connectServices: connectServices,
          );
        })
        .toList(growable: false);

    return targets.sortedBy<String>((target) => target.host);
  }

  DiscoveredWirelessTarget? get _selectedDiscoveryTarget {
    if (_selectedDiscoveryHost != null) {
      return _discoveredTargets.firstWhereOrNull(
        (target) => target.host == _selectedDiscoveryHost,
      );
    }

    final pairingHost = _hostFromAddress(_pairAddressController.text);
    if (pairingHost != null) {
      return _discoveredTargets.firstWhereOrNull(
        (target) => target.host == pairingHost,
      );
    }

    final connectHost = _hostFromAddress(_connectAddressController.text);
    if (connectHost != null) {
      return _discoveredTargets.firstWhereOrNull(
        (target) => target.host == connectHost,
      );
    }

    return _discoveredTargets.firstOrNull;
  }

  @override
  void initState() {
    super.initState();
    _pairAddressController = TextEditingController(
      text: wirelessController.suggestedWirelessPairingAddress ?? '',
    );
    _pairingCodeController = TextEditingController();
    _connectAddressController = TextEditingController(
      text: wirelessController.suggestedWirelessConnectAddress ?? '',
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeAutoDiscoverNearby();
    });
  }

  @override
  void dispose() {
    _pairAddressController.dispose();
    _pairingCodeController.dispose();
    _connectAddressController.dispose();
    wirelessController.dispose();
    super.dispose();
  }

  Future<void> _handleDiscover() async {
    final result = await wirelessController.discoverWirelessServices();
    if (!mounted) return;

    _applySuggestedAddresses(preferFirstDiscoveredTarget: true);
    if (!result.isSuccess && result.error != null) {
      widget.onShowSnackBar(result.error!);
    }
  }

  Future<void> _handlePair() async {
    final selectedTarget = _selectedDiscoveryTarget;
    final result = await wirelessController.pairWirelessDevice(
      address: _pairAddressController.text,
      pairingCode: _pairingCodeController.text,
      connectAddresses:
          selectedTarget?.connectAddresses ?? _manualConnectAddresses,
    );
    if (!mounted) return;

    if (result.connectAddresses.isNotEmpty) {
      _connectAddressController.text = result.connectAddresses.first;
    }

    setState(() {
      if (result.shouldShowConnectAction) {
        _showManualConnectSection = true;
        _fallbackConnectHost =
            selectedTarget?.host ??
            _hostFromAddress(_connectAddressController.text);
      } else {
        _fallbackConnectHost = null;
      }
    });

    if (result.error != null) {
      widget.onShowSnackBar(result.error!);
      return;
    }

    if (result.message != null) {
      widget.onShowSnackBar(result.message!);
    }
    if (result.autoConnected) {
      Navigator.of(context).pop();
      return;
    }

    _applySuggestedAddresses();
  }

  void _maybeAutoDiscoverNearby() {
    if (!wirelessController.isWirelessBusy) {
      _handleDiscover();
    }
  }

  void _maybeAutoGenerateQr() {
    if (wirelessController.qrSession == null &&
        wirelessController.canStartQrPairing) {
      _handleQrPair();
    }
  }

  void _onSectionChanged(_WirelessDialogSection next) {
    wirelessController.cancelAllOperations();
    setState(() {
      _section = next;
    });
    if (next == _WirelessDialogSection.nearby) {
      _maybeAutoDiscoverNearby();
    } else if (next == _WirelessDialogSection.qr) {
      _maybeAutoGenerateQr();
    }
  }

  Future<void> _handleQrPair() async {
    final result = await wirelessController.startQrPairing();
    if (!mounted || result == null) return;

    if (result.error != null) {
      widget.onShowSnackBar(result.error!);
      return;
    }

    if (result.message != null) {
      widget.onShowSnackBar(result.message!);
    }
    if (result.autoConnected) {
      Navigator.of(context).pop();
      return;
    }

    if (result.connectAddresses.isNotEmpty) {
      _connectAddressController.text = result.connectAddresses.first;
    }
    setState(() {
      _section = _WirelessDialogSection.manual;
      _showManualConnectSection = true;
    });
    _applySuggestedAddresses();
  }

  Future<void> _handleConnect() async {
    final selectedTarget = _selectedDiscoveryTarget;
    final result = await wirelessController.connectWirelessDevice(
      address: _connectAddressController.text,
      candidateAddresses:
          selectedTarget?.connectAddresses ?? _manualConnectAddresses,
    );
    if (!mounted) return;

    final feedback = result.error ?? result.message;
    if (feedback != null && feedback.isNotEmpty) {
      widget.onShowSnackBar(feedback);
    }
    if (result.isSuccess) {
      Navigator.of(context).pop();
    }
  }

  List<String> get _manualConnectAddresses {
    final address = _connectAddressController.text.trim();
    return address.isEmpty ? const [] : [address];
  }

  void _applySuggestedAddresses({bool preferFirstDiscoveredTarget = false}) {
    final suggestedPairing = wirelessController.suggestedWirelessPairingAddress;
    final suggestedConnect = wirelessController.suggestedWirelessConnectAddress;
    final firstTarget = _discoveredTargets.firstOrNull;

    setState(() {
      if (_pairAddressController.text.trim().isEmpty &&
          suggestedPairing != null) {
        _pairAddressController.text = suggestedPairing;
      }
      if (_connectAddressController.text.trim().isEmpty &&
          suggestedConnect != null) {
        _connectAddressController.text = suggestedConnect;
      }

      _selectedDiscoveryHost ??=
          _hostFromAddress(suggestedPairing) ??
          _hostFromAddress(suggestedConnect) ??
          (preferFirstDiscoveredTarget ? firstTarget?.host : null);
    });
  }

  void _selectDiscoveredTarget(DiscoveredWirelessTarget target) {
    setState(() {
      _selectedDiscoveryHost = target.host;
      _fallbackConnectHost = null;
      if (target.pairingService != null) {
        _pairAddressController.text = target.pairingService!.address;
      }
      if (target.primaryConnectAddress != null) {
        _connectAddressController.text = target.primaryConnectAddress!;
      }
    });
  }

  Device? _connectedDeviceForTarget(DiscoveredWirelessTarget target) {
    return manager.devices.firstWhereOrNull(
      (device) =>
          device.status == 'device' &&
          _hostFromAddress(device.id) == target.host,
    );
  }

  Device? _connectedDeviceForAddress(String address) {
    final host = _hostFromAddress(address);
    if (host == null) return null;
    return manager.devices.firstWhereOrNull(
      (device) =>
          device.status == 'device' && _hostFromAddress(device.id) == host,
    );
  }

  String? _hostFromAddress(String? address) {
    if (address == null) return null;
    final trimmed = address.trim();
    if (trimmed.isEmpty) return null;
    final separatorIndex = trimmed.lastIndexOf(':');
    if (separatorIndex <= 0) return null;
    return trimmed.substring(0, separatorIndex);
  }

  Widget _buildNearbyDevicesTab(BuildContext context) {
    final theme = Theme.of(context);
    final selectedTarget = _selectedDiscoveryTarget;

    if (_discoveredTargets.isEmpty) {
      final description = wirelessController.hasAttemptedWirelessDiscovery
          ? '未发现附近的无线 ADB 设备。您可以重新发现或切换到手动输入。'
          : '请先发现通过 mDNS 广播的附近无线 ADB 设备。';

      return WirelessPlaceholderCard(
        icon: wirelessController.hasAttemptedWirelessDiscovery
            ? Icons.wifi_find
            : Icons.travel_explore,
        title: wirelessController.hasAttemptedWirelessDiscovery
            ? '未发现附近设备'
            : '发现附近设备',
        description: description,
        footer: Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            FilledButton.tonalIcon(
              onPressed: wirelessController.isWirelessBusy
                  ? null
                  : _handleDiscover,
              icon: wirelessController.isDiscoveringWireless
                  ? SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: theme.colorScheme.primary,
                      ),
                    )
                  : const Icon(Icons.travel_explore),
              label: Text(
                wirelessController.hasAttemptedWirelessDiscovery
                    ? '刷新发现'
                    : '发现设备',
              ),
            ),
            OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  _section = _WirelessDialogSection.manual;
                  _showManualConnectSection = true;
                });
              },
              icon: const Icon(Icons.tune),
              label: const Text('手动输入'),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('附近设备', style: theme.textTheme.titleMedium),
        const Gap(6),
        Text(
          '请先选择已发现的设备。若有可用连接端口，配对后将自动继续连接。',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const Gap(12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final target in _discoveredTargets)
              WirelessDiscoveryCard(
                target: target,
                selected: selectedTarget?.host == target.host,
                onTap: () => _selectDiscoveredTarget(target),
              ),
          ],
        ),
        const Gap(18),
        if (selectedTarget != null)
          WirelessSelectedDevicePanel(
            target: selectedTarget,
            connectedDevice: _connectedDeviceForTarget(selectedTarget),
            pairingCodeController: _pairingCodeController,
            pairingBusy: wirelessController.isPairingWireless,
            connectingBusy: wirelessController.isConnectingWireless,
            actionsDisabled: wirelessController.isWirelessBusy,
            showConnectAction:
                selectedTarget.canConnect &&
                (_fallbackConnectHost == selectedTarget.host ||
                    !selectedTarget.canPair ||
                    _connectedDeviceForTarget(selectedTarget) != null),
            onPair: selectedTarget.pairingService == null ? null : _handlePair,
            onConnect: selectedTarget.canConnect ? _handleConnect : null,
            onUseManualEntry: () {
              setState(() {
                _section = _WirelessDialogSection.manual;
                _showManualConnectSection = true;
              });
            },
          ),
      ],
    );
  }

  Widget _buildQrCodeTab(BuildContext context) {
    final theme = Theme.of(context);
    final session = wirelessController.qrSession;
    final waiting = wirelessController.isWaitingForQrScan;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('使用 QR 码配对', style: theme.textTheme.titleMedium),
        const Gap(6),
        Text(
          '在 Android 设备上打开 设置 → 开发者选项 → 无线调试 → '
          '使用 QR 码配对设备，然后扫描下方 QR 码。'
          '两台设备须在同一网络。',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const Gap(18),
        Center(
          child: WirelessQrPanel(
            payload: session?.payload,
            waiting: waiting,
            busy: !wirelessController.canStartQrPairing,
            onGenerate: _handleQrPair,
            onCancel: wirelessController.cancelQrPairing,
          ),
        ),
      ],
    );
  }

  Widget _buildManualEntryTab(BuildContext context) {
    final theme = Theme.of(context);
    final manualConnectAddress = _connectAddressController.text.trim();
    final connectedDevice = _connectedDeviceForAddress(manualConnectAddress);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('手动输入', style: theme.textTheme.titleMedium),
        const Gap(6),
        Text(
          '仅在无法发现设备或您已知配对与连接地址时使用。',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const Gap(16),
        WirelessManualSection(
          title: _manualConnectAddresses.isNotEmpty ? '配对并连接' : '使用配对码配对',
          description: '输入设备屏幕上显示的配对地址和配对码。若有可用连接地址，将自动继续连接。',
          child: Column(
            children: [
              TextField(
                controller: _pairAddressController,
                enabled: !wirelessController.isWirelessBusy,
                decoration: const InputDecoration(
                  labelText: '配对地址',
                  hintText: '192.168.0.104:45673',
                  prefixIcon: Icon(Icons.router_outlined),
                ),
              ),
              const Gap(12),
              TextField(
                controller: _pairingCodeController,
                enabled: !wirelessController.isWirelessBusy,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '配对码',
                  hintText: '输入设备上显示的 6 位配对码',
                  prefixIcon: Icon(Icons.password_outlined),
                ),
                onSubmitted: (_) {
                  if (!wirelessController.isWirelessBusy) {
                    _handlePair();
                  }
                },
              ),
              const Gap(12),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                  onPressed: wirelessController.isWirelessBusy
                      ? null
                      : _handlePair,
                  icon: wirelessController.isPairingWireless
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.verified_user_outlined),
                  label: Text(
                    _manualConnectAddresses.isNotEmpty ? '配对并连接' : '配对',
                  ),
                ),
              ),
            ],
          ),
        ),
        const Gap(12),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () {
              setState(() {
                _showManualConnectSection = !_showManualConnectSection;
              });
            },
            icon: Icon(
              _showManualConnectSection ? Icons.expand_less : Icons.expand_more,
            ),
            label: Text(_showManualConnectSection ? '隐藏手动连接' : '已配对？手动连接'),
          ),
        ),
        if (_showManualConnectSection) ...[
          const Gap(4),
          WirelessManualSection(
            title: connectedDevice != null ? '使用已连接设备' : '连接并开始采集日志',
            description: connectedDevice != null
                ? '此无线设备已连接。请复用现有连接，无需重新连接。'
                : '仅在自动连接未能完成或设备此前已配对时使用。',
            child: Column(
              children: [
                TextField(
                  controller: _connectAddressController,
                  enabled: !wirelessController.isWirelessBusy,
                  decoration: const InputDecoration(
                    labelText: '连接地址',
                    hintText: '192.168.0.117:37251',
                    prefixIcon: Icon(Icons.link_outlined),
                  ),
                  onSubmitted: (_) {
                    if (!wirelessController.isWirelessBusy) {
                      _handleConnect();
                    }
                  },
                ),
                const Gap(12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton(
                    onPressed: wirelessController.isWirelessBusy
                        ? null
                        : _handleConnect,
                    child: wirelessController.isConnectingWireless
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            connectedDevice != null
                                ? '使用已连接设备'
                                : '连接并开始采集日志',
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnimatedBuilder(
      animation: Listenable.merge([manager, wirelessController]),
      builder: (context, _) {
        return EaglyDialog(
          title: '无线连接',
          icon: Icons.wifi_tethering,
          width: 720,
          height: 560,
          contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SegmentedButton<_WirelessDialogSection>(
                    segments: const [
                      ButtonSegment<_WirelessDialogSection>(
                        value: _WirelessDialogSection.nearby,
                        icon: Icon(Icons.wifi_find_outlined),
                        label: Text('附近设备'),
                      ),
                      ButtonSegment<_WirelessDialogSection>(
                        value: _WirelessDialogSection.qr,
                        icon: Icon(Icons.qr_code_2),
                        label: Text('QR 码'),
                      ),
                      ButtonSegment<_WirelessDialogSection>(
                        value: _WirelessDialogSection.manual,
                        icon: Icon(Icons.tune),
                        label: Text('手动输入'),
                      ),
                      ButtonSegment<_WirelessDialogSection>(
                        value: _WirelessDialogSection.ios,
                        icon: Icon(Icons.apple),
                        label: Text('iOS'),
                      ),
                    ],
                    selected: {_section},
                    onSelectionChanged: (selection) {
                      _onSectionChanged(selection.first);
                    },
                  ),
                  if (_section != _WirelessDialogSection.ios)
                    FilledButton.tonalIcon(
                      onPressed: wirelessController.isWirelessBusy
                          ? null
                          : _handleDiscover,
                      icon: wirelessController.isDiscoveringWireless
                          ? SizedBox.square(
                              dimension: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: theme.colorScheme.primary,
                              ),
                            )
                          : const Icon(Icons.travel_explore),
                      label: Text(
                        wirelessController.hasAttemptedWirelessDiscovery
                            ? '刷新发现'
                            : '发现附近',
                      ),
                    ),
                  if (manager.selected != null)
                    Text(
                      '当前设备：${manager.selected!.device.displayName}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
              const Gap(14),
              WirelessFeedbackBanner(
                message: wirelessController.wirelessMessage,
                error: wirelessController.wirelessError,
              ),
              const Gap(14),
              Flexible(
                child: SingleChildScrollView(
                  child: switch (_section) {
                    _WirelessDialogSection.nearby => _buildNearbyDevicesTab(
                      context,
                    ),
                    _WirelessDialogSection.qr => _buildQrCodeTab(context),
                    _WirelessDialogSection.manual => _buildManualEntryTab(
                      context,
                    ),
                    _WirelessDialogSection.ios => WirelessIosSection(
                      manager: manager,
                      busy: wirelessController.isIosWifiBusy,
                      onEnableWifiConnections: (udid) async {
                        final ok = await wirelessController
                            .enableIosWifiConnections(udid: udid);
                        if (ok && mounted) {
                          widget.onShowSnackBar('已开启 iOS 无线调试');
                        }
                      },
                      onRefresh: () {
                        wirelessController.refreshIosDevices();
                      },
                    ),
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

enum _WirelessDialogSection { nearby, qr, manual, ios }
