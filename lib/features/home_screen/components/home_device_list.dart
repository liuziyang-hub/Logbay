import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../../../constants/atmosphere_theme.dart';
import '../../../presentation/components/animation_utils.dart';
import '../../../presentation/components/available_device_card.dart';
import '../../../presentation/theme/theme_typography.dart';
import '../../../services/preferences_service.dart';
import '../../../session/device_session_manager.dart';

/// Device section on the landing screen. Supports many devices via a capped
/// scroll region so the page layout stays stable.
class HomeDeviceList extends StatefulWidget {
  const HomeDeviceList({
    super.key,
    required this.manager,
    required this.onShowMessage,
    this.maxListHeight = 280,
  });

  final DeviceSessionManager manager;
  final ValueChanged<String> onShowMessage;
  final double maxListHeight;

  @override
  State<HomeDeviceList> createState() => _HomeDeviceListState();
}

class _HomeDeviceListState extends State<HomeDeviceList> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AtmosphereTheme>(
      valueListenable: PreferencesService.atmosphereThemeListenable,
      builder: (context, atmosphere, _) =>
          _buildBody(context, atmosphere),
    );
  }

  Widget _buildBody(BuildContext context, AtmosphereTheme atmosphere) {
    final manager = widget.manager;
    final sessions = [
      for (final session in manager.sessions)
        if (!session.isImportedWorkspace) session,
    ];
    final sectionStyle = ThemeTypography.badge(atmosphere).copyWith(
      color: atmosphere.cardTitleColor,
      fontSize: 13.5,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.35,
    );

    if (sessions.isEmpty) {
      return Container(
        key: const ValueKey('status-box'),
        width: double.infinity,
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: atmosphere.glassFill.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: atmosphere.glassBorder),
        ),
        child: AnimatedContent(
          child: manager.isLoadingDevices
              ? Column(
                  children: [
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: atmosphere.primaryAccent,
                      ),
                    ),
                    const Gap(10),
                    Text(
                      '正在搜索设备…',
                      style: ThemeTypography.cardTitle(atmosphere).copyWith(
                        fontSize: 16,
                      ),
                    ),
                  ],
                )
              : Column(
                  children: [
                    Icon(Icons.usb_off, color: atmosphere.mutedColor),
                    const Gap(10),
                    Text(
                      '未找到设备',
                      style: ThemeTypography.cardTitle(atmosphere).copyWith(
                        fontSize: 16,
                      ),
                    ),
                    const Gap(6),
                    Text(
                      '请连接已开启 ADB 的 Android 设备，或连接 '
                      'libimobiledevice 支持的 iOS 设备。',
                      style: ThemeTypography.cardBody(atmosphere),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
        ),
      );
    }

    return Column(
      key: const ValueKey('devices'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Gap(4),
        Text(
          sessions.length == 1 ? '设备' : '设备 · ${sessions.length} 台',
          style: sectionStyle,
        ),
        const Gap(8),
        ConstrainedBox(
          constraints: BoxConstraints(maxHeight: widget.maxListHeight),
          child: Scrollbar(
            controller: _scrollController,
            thumbVisibility: sessions.length > 2,
            child: ListView.separated(
              controller: _scrollController,
              primary: false,
              shrinkWrap: true,
              itemCount: sessions.length,
              separatorBuilder: (_, _) => const Gap(8),
              itemBuilder: (context, index) {
                final session = sessions[index];
                return AvailableDeviceCard(
                  device: session.device,
                  onSelected: () => manager.select(session.id),
                  onInstallApp: session.isConnected
                      ? () => session.installAppFromPicker()
                      : null,
                  onShowMessage: widget.onShowMessage,
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
