import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../../constants/app_constants.dart';
import '../../constants/atmosphere_theme.dart';
import '../../constants/local_assets.dart';
import '../../presentation/components/get_started_action_card.dart';
import '../../presentation/components/ios_support_notice.dart';
import '../../presentation/theme/theme_typography.dart';
import '../../services/preferences_service.dart';
import '../../session/device_session_manager.dart';
import 'components/home_device_list.dart';
import 'components/home_lake_background.dart';
import 'components/recent_files_list.dart';

/// Landing screen: Layout A — brand left, actions right, as one centered block.
class HomeView extends StatelessWidget {
  const HomeView({
    super.key,
    required this.manager,
    required this.onShowWireless,
    required this.onShowMessage,
    required this.onImportLog,
    required this.onOpenRecent,
  });

  final DeviceSessionManager manager;
  final VoidCallback onShowWireless;
  final ValueChanged<String> onShowMessage;
  final VoidCallback onImportLog;
  final ValueChanged<String> onOpenRecent;

  static const double _splitBreakpoint = 900;
  static const double _maxWidth = 980;
  static const double _brandWidth = 300;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AtmosphereTheme>(
      valueListenable: PreferencesService.atmosphereThemeListenable,
      builder: (context, atmosphere, _) {
        return ListenableBuilder(
          listenable: manager,
          builder: (context, _) {
            return Stack(
              fit: StackFit.expand,
              children: [
                const HomeLakeBackground(),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth >= _splitBreakpoint;
                    final hPad = wide ? 32.0 : 24.0;
                    final contentWidth = math.min(
                      _maxWidth,
                      math.max(0.0, constraints.maxWidth - hPad * 2),
                    );

                    return Center(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.symmetric(
                          horizontal: hPad,
                          vertical: 28,
                        ),
                        child: SizedBox(
                          width: contentWidth,
                          child: wide
                              ? Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: _brandWidth,
                                      child: _BrandHero(atmosphere: atmosphere),
                                    ),
                                    const Gap(36),
                                    Expanded(
                                      child: _ActionColumn(
                                        manager: manager,
                                        onShowWireless: onShowWireless,
                                        onShowMessage: onShowMessage,
                                        onImportLog: onImportLog,
                                        onOpenRecent: onOpenRecent,
                                      ),
                                    ),
                                  ],
                                )
                              : Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _BrandHero(
                                      compact: true,
                                      atmosphere: atmosphere,
                                    ),
                                    const Gap(24),
                                    _ActionColumn(
                                      manager: manager,
                                      onShowWireless: onShowWireless,
                                      onShowMessage: onShowMessage,
                                      onImportLog: onImportLog,
                                      onOpenRecent: onOpenRecent,
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _BrandHero extends StatelessWidget {
  const _BrandHero({
    required this.atmosphere,
    this.compact = false,
  });

  final AtmosphereTheme atmosphere;
  final bool compact;

  static const _universeTitleShadows = [
    Shadow(color: Color(0x66A9B6FF), blurRadius: 40, offset: Offset.zero),
    Shadow(color: Color(0x33F2E8C9), blurRadius: 80, offset: Offset.zero),
    Shadow(color: Color(0x99000000), blurRadius: 14, offset: Offset(0, 2)),
  ];
  static const _forestTitleShadows = [
    Shadow(color: Color(0x6652796F), blurRadius: 32, offset: Offset.zero),
    Shadow(color: Color(0x4484A98C), blurRadius: 48, offset: Offset.zero),
    Shadow(color: Color(0x99000000), blurRadius: 12, offset: Offset(0, 2)),
  ];
  static const _lakeTitleShadows = [
    Shadow(color: Color(0x802D7AA0), blurRadius: 36, offset: Offset.zero),
    Shadow(color: Color(0x40F98513), blurRadius: 56, offset: Offset.zero),
    Shadow(color: Color(0x99000000), blurRadius: 12, offset: Offset(0, 2)),
  ];
  static const _bodyShadows = [
    Shadow(color: Color(0xA6000000), blurRadius: 10, offset: Offset(0, 1)),
  ];

  @override
  Widget build(BuildContext context) {
    final brandSize = compact ? 28.0 : 36.0;
    final shadows = switch (atmosphere) {
      AtmosphereTheme.lake => _lakeTitleShadows,
      AtmosphereTheme.forest => _forestTitleShadows,
      AtmosphereTheme.universe => _universeTitleShadows,
    };
    final brandStyle = ThemeTypography.brand(
      atmosphere,
      fontSize: brandSize,
      shadows: shadows,
    );
    final taglineStyle = ThemeTypography.tagline(
      atmosphere,
      shadows: _bodyShadows,
    );
    final badgeStyle = ThemeTypography.badge(atmosphere);

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 4,
        vertical: compact ? 4 : 8,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: compact
            ? CrossAxisAlignment.center
            : CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Image.asset(
              LocalAssets.appIcon,
              height: compact ? 72 : 88,
              width: compact ? 72 : 88,
            ),
          ),
          Gap(compact ? 14 : 18),
          Text(
            AppConstants.landingBrandName,
            style: brandStyle,
            textAlign: compact ? TextAlign.center : TextAlign.start,
          ),
          const Gap(10),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 280),
            child: Text(
              atmosphere.tagline,
              style: taglineStyle,
              textAlign: compact ? TextAlign.center : TextAlign.start,
            ),
          ),
          if (!compact) ...[
            const Gap(18),
            _GlassHint(
              atmosphere: atmosphere,
              child: Text(atmosphere.badge, style: badgeStyle),
            ),
          ],
        ],
      ),
    );
  }
}

class _GlassHint extends StatelessWidget {
  const _GlassHint({required this.child, required this.atmosphere});

  final Widget child;
  final AtmosphereTheme atmosphere;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(12);
    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: radius,
            color: atmosphere.glassFill,
            border: Border.all(color: atmosphere.glassBorder),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _ActionColumn extends StatelessWidget {
  const _ActionColumn({
    required this.manager,
    required this.onShowWireless,
    required this.onShowMessage,
    required this.onImportLog,
    required this.onOpenRecent,
  });

  final DeviceSessionManager manager;
  final VoidCallback onShowWireless;
  final ValueChanged<String> onShowMessage;
  final VoidCallback onImportLog;
  final ValueChanged<String> onOpenRecent;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GetStartedActionCard(
          icon: Icons.phone_android_rounded,
          title: '选择设备',
          subtitle: '发现已连接的 Android / iOS 设备，并打开实时日志。支持同时连接多台。',
          onTap: () => manager.refreshDevices(),
          glass: true,
          secondaryActions: [
            FilledButton.tonalIcon(
              onPressed: () => manager.refreshDevices(),
              icon: const Icon(Icons.usb),
              label: const Text('加载设备'),
            ),
            FilledButton.tonalIcon(
              icon: const Icon(Icons.wifi_tethering_outlined),
              onPressed: onShowWireless,
              label: const Text('无线 ADB'),
            ),
          ],
          children: [
            HomeDeviceList(
              manager: manager,
              onShowMessage: onShowMessage,
              maxListHeight: 280,
            ),
            if (Platform.isWindows && manager.iosSupportUnavailable)
              const IosSupportNotice(),
          ],
        ),
        const Gap(16),
        GetStartedActionCard(
          icon: Icons.description_outlined,
          title: '打开日志文件',
          subtitle: '查看已保存的 logcat 或 syslog 文件。',
          onTap: onImportLog,
          glass: true,
          secondaryActions: [
            FilledButton.tonalIcon(
              onPressed: onImportLog,
              icon: const Icon(Icons.folder_open_outlined),
              label: const Text('导入日志文件'),
            ),
          ],
          children: [
            RecentFilesList(onOpenRecent: onOpenRecent),
          ],
        ),
      ],
    );
  }
}
