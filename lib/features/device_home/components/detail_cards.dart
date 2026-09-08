import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../../../data/device.dart';
import '../../../presentation/theme/app_theme.dart';
import '../data/device_info.dart';
import '../data/installed_app_info.dart';
import 'home_primitives.dart';

/// Secondary, slower-moving device facts. Each card groups one topic so the
/// grid stays scannable instead of one long list of label/value rows.

// ── Debug readiness ──────────────────────────────────────────────────────

class ReadinessCard extends StatelessWidget {
  const ReadinessCard({
    super.key,
    required this.device,
    required this.developerState,
  });

  final Device device;
  final DeviceDeveloperStateInfo developerState;

  @override
  Widget build(BuildContext context) {
    final isIos = device is IosDevice;
    final pills = <Widget>[
      if (developerState.debuggingReady != null)
        _readinessPill(
          context,
          label: isIos ? '调试' : 'ADB 桥接',
          ok: developerState.debuggingReady!,
          okText: '就绪',
          badText: '未就绪',
        ),
      if (developerState.pairingState != null)
        _readinessPill(
          context,
          label: '配对',
          ok: developerState.pairingState == '已配对',
          okText: developerState.pairingState!,
          badText: developerState.pairingState!,
        ),
      if (developerState.developerModeEnabled != null)
        _readinessPill(
          context,
          label: '开发者模式',
          ok: developerState.developerModeEnabled!,
          okText: '开',
          badText: '关',
        ),
      if (developerState.adbEnabled != null)
        _readinessPill(
          context,
          label: 'USB 调试',
          ok: developerState.adbEnabled!,
          okText: '开',
          badText: '关',
        ),
    ];

    return SectionCard(
      title: '调试就绪',
      icon: Icons.verified_user_outlined,
      accent: Theme.of(context).colorScheme.primary,
      child: Wrap(spacing: 8, runSpacing: 8, children: pills),
    );
  }

  Widget _readinessPill(
    BuildContext context, {
    required String label,
    required bool ok,
    required String okText,
    required String badText,
  }) {
    return StatusPill(
      label: '$label · ${ok ? okText : badText}',
      tone: ok ? StatusTone.good : StatusTone.warn,
      icon: ok ? Icons.check_circle_outline : Icons.error_outline,
    );
  }
}

// ── Hardware ─────────────────────────────────────────────────────────────

class HardwareCard extends StatelessWidget {
  const HardwareCard({super.key, required this.device, required this.identity});

  final Device device;
  final DeviceIdentityInfo identity;

  @override
  Widget build(BuildContext context) {
    final device = this.device;
    final isIos = device is IosDevice;
    final items = <SpecItem>[
      if (identity.manufacturer != null)
        SpecItem('厂商', identity.manufacturer!),
      if (device.brand != null && device.brand!.isNotEmpty)
        SpecItem('品牌', device.brand!),
      if (device.model != null && device.model!.isNotEmpty)
        SpecItem('型号', device.model!),
      if (device.name != null && device.name!.isNotEmpty)
        SpecItem('代号', device.name!),
      if (identity.buildVersion != null)
        SpecItem('构建版本', identity.buildVersion!, mono: true),
      if (identity.cpuArchitecture != null)
        SpecItem('CPU', identity.cpuArchitecture!),
      if (device is AndroidDevice && device.serialNumber != null)
        SpecItem('序列号', device.serialNumber!, copyable: true),
      SpecItem(isIos ? 'UDID' : '设备 ID', device.id, copyable: true),
    ];

    return SectionCard(
      title: '硬件',
      icon: Icons.developer_board_outlined,
      accent: Theme.of(context).colorScheme.secondary,
      child: SpecGrid(items: items),
    );
  }
}

// ── Display ──────────────────────────────────────────────────────────────

class DisplayCard extends StatelessWidget {
  const DisplayCard({super.key, required this.display});

  final DeviceDisplayInfo display;

  @override
  Widget build(BuildContext context) {
    final width = display.widthPx;
    final height = display.heightPx;
    final landscape = display.orientation == DisplayOrientation.landscape;

    final items = <SpecItem>[
      if (width != null && height != null)
        SpecItem('分辨率', '$width × $height'),
      if (display.densityDpi != null)
        SpecItem('密度', '${display.densityDpi} dpi'),
      if (display.refreshRateHz != null)
        SpecItem('刷新率', '${display.refreshRateHz!.toStringAsFixed(0)} Hz'),
      if (display.orientation != null)
        SpecItem('方向', landscape ? '横屏' : '竖屏'),
    ];

    return SectionCard(
      title: '显示',
      icon: Icons.smartphone_outlined,
      accent: Theme.of(context).colorScheme.tertiary,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _ScreenGlyph(widthPx: width, heightPx: height, landscape: landscape),
          const Gap(14),
          Expanded(child: SpecGrid(items: items, minColumnWidth: 110)),
        ],
      ),
    );
  }
}

/// A to-scale outline of the device screen — communicates aspect ratio and
/// orientation instantly, which "1080 × 2400" alone does not.
class _ScreenGlyph extends StatelessWidget {
  const _ScreenGlyph({
    required this.widthPx,
    required this.heightPx,
    required this.landscape,
  });

  final int? widthPx;
  final int? heightPx;
  final bool landscape;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const boxHeight = 74.0;
    var ratio = widthPx != null && heightPx != null && heightPx! > 0
        ? widthPx! / heightPx!
        : 0.46;
    if (landscape && ratio < 1) ratio = 1 / ratio;
    final glyphHeight = landscape ? boxHeight * 0.62 : boxHeight;
    final glyphWidth = (glyphHeight * ratio).clamp(24.0, 120.0);

    return SizedBox(
      height: boxHeight,
      width: glyphWidth,
      child: Center(
        child: Container(
          width: glyphWidth,
          height: glyphHeight,
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: theme.colorScheme.outline, width: 1.5),
          ),
          child: Padding(
            padding: const EdgeInsets.all(3),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    theme.colorScheme.primary.withValues(alpha: 0.28),
                    theme.colorScheme.tertiary.withValues(alpha: 0.12),
                  ],
                ),
                borderRadius: BorderRadius.circular(5),
              ),
              child: Align(
                alignment: Alignment.topCenter,
                child: Container(
                  margin: const EdgeInsets.only(top: 3),
                  width: glyphWidth * 0.28,
                  height: 3,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outline,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Connectivity ─────────────────────────────────────────────────────────

class ConnectivityCard extends StatelessWidget {
  const ConnectivityCard({
    super.key,
    required this.connectivity,
    required this.cellular,
  });

  final DeviceConnectivityInfo connectivity;
  final DeviceCellularInfo cellular;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final toggles = <Widget>[
      if (connectivity.usbConnected != null)
        ToggleTile(
          icon: connectivity.usbConnected! ? Icons.usb : Icons.wifi_tethering,
          label: connectivity.usbConnected! ? 'USB' : '无线',
          enabled: true,
          accent: scheme.primary,
        ),
      if (connectivity.wifiEnabled != null)
        ToggleTile(
          icon: connectivity.wifiEnabled! ? Icons.wifi : Icons.wifi_off,
          label: 'Wi-Fi',
          enabled: connectivity.wifiEnabled!,
          accent: scheme.secondary,
        ),
      if (connectivity.bluetoothEnabled != null)
        ToggleTile(
          icon: connectivity.bluetoothEnabled!
              ? Icons.bluetooth
              : Icons.bluetooth_disabled,
          label: '蓝牙',
          enabled: connectivity.bluetoothEnabled!,
          accent: scheme.tertiary,
        ),
    ];

    final cellularPills = <Widget>[
      if (cellular.carrierName != null)
        StatusPill(label: cellular.carrierName!, icon: Icons.cell_tower),
      if (cellular.networkType != null)
        StatusPill(label: cellular.networkType!, icon: Icons.network_cell),
      if (cellular.simState != null)
        StatusPill(label: 'SIM ${cellular.simState!}', icon: Icons.sim_card),
      if (cellular.simOperatorName != null &&
          cellular.simOperatorName != cellular.carrierName)
        StatusPill(label: cellular.simOperatorName!, icon: Icons.store),
      if (cellular.mcc != null && cellular.mnc != null)
        StatusPill(
          label: '${cellular.mcc}/${cellular.mnc}',
          icon: Icons.tag,
          mono: true,
        ),
    ];

    return SectionCard(
      title: '连接',
      icon: Icons.settings_ethernet,
      accent: Theme.of(context).colorScheme.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (toggles.isNotEmpty)
            Wrap(spacing: 8, runSpacing: 8, children: toggles),
          if (connectivity.ipAddress != null) ...[
            const Gap(10),
            SpecGrid(
              items: [
                SpecItem('IP 地址', connectivity.ipAddress!, copyable: true),
              ],
            ),
          ],
          if (cellularPills.isNotEmpty) ...[
            const Gap(12),
            Text(
              '蜂窝网络',
              style: theme.textTheme.labelSmall?.copyWith(
                fontSize: 9.5,
                letterSpacing: 0.7,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const Gap(6),
            Wrap(spacing: 6, runSpacing: 6, children: cellularPills),
          ],
        ],
      ),
    );
  }
}

// ── Software ─────────────────────────────────────────────────────────────

class SoftwareCard extends StatelessWidget {
  const SoftwareCard({
    super.key,
    required this.software,
    required this.identity,
  });

  final DeviceSoftwareInfo software;
  final DeviceIdentityInfo identity;

  @override
  Widget build(BuildContext context) {
    final items = <SpecItem>[
      if (identity.osVersion != null)
        SpecItem(identity.osName ?? '系统版本', identity.osVersion!),
      if (software.sdkLevel != null)
        SpecItem('SDK 级别', 'API ${software.sdkLevel}'),
      if (software.securityPatch != null)
        SpecItem('安全补丁', software.securityPatch!),
      if (software.locale != null) SpecItem('区域', software.locale!),
      if (software.timeZone != null) SpecItem('时区', software.timeZone!),
    ];

    return SectionCard(
      title: '软件与区域',
      icon: Icons.shield_moon_outlined,
      accent: Theme.of(context).colorScheme.tertiary,
      child: SpecGrid(items: items),
    );
  }
}

// ── Recent installs ──────────────────────────────────────────────────────

class RecentInstallsCard extends StatelessWidget {
  const RecentInstallsCard({
    super.key,
    required this.apps,
    required this.isLoading,
  });

  final List<InstalledAppInfo> apps;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SectionCard(
      title: '最近安装',
      icon: Icons.history_rounded,
      accent: theme.colorScheme.secondary,
      trailing: isLoading
          ? const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(strokeWidth: 1.5),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final app in apps)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 14,
                    color: theme.colorScheme.tertiary,
                  ),
                  const Gap(8),
                  Expanded(
                    child: Text(
                      app.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                  if (app.installTime != null)
                    Text(
                      formatClockTime(app.installTime!),
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontFamily: 'monospace',
                        fontSize: 10.5,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
