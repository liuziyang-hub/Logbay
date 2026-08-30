import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../constants/atmosphere_theme.dart';
import '../../data/device.dart';
import '../../presentation/theme/theme_typography.dart';
import '../../services/preferences_service.dart';
import 'device_presentation.dart';
import 'layout_constants.dart';

class AvailableDeviceCard extends StatelessWidget {
  const AvailableDeviceCard({
    super.key,
    required this.device,
    required this.onSelected,
    this.onInstallApp,
    this.onShowMessage,
  });

  final Device device;
  final VoidCallback onSelected;
  final VoidCallback? onInstallApp;
  final ValueChanged<String>? onShowMessage;

  Future<void> _copyIosUdid() async {
    await Clipboard.setData(ClipboardData(text: device.id));
    onShowMessage?.call(LayoutConstants.iosUdidCopiedMessage);
  }

  @override
  Widget build(BuildContext context) {
    final atmosphere = PreferencesService.atmosphereTheme;
    final accent = atmosphere.primaryAccentDeep;
    final radius = atmosphere == AtmosphereTheme.universe ? 999.0 : 14.0;
    final labelStyle = ThemeTypography.chipLabel(atmosphere);

    return Material(
      color: atmosphere.chipFill,
      borderRadius: BorderRadius.circular(radius),
      child: InkWell(
        borderRadius: BorderRadius.circular(radius),
        onTap: onSelected,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: atmosphere.glassBorder),
            boxShadow: [
              BoxShadow(
                color: atmosphere.primaryAccent.withValues(alpha: 0.12),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: DeviceLabel(
                  device: device,
                  textStyle: labelStyle,
                  showStatus: true,
                  iconColor: accent,
                  iconSize: 20,
                ),
              ),
              switch (device) {
                IosDevice() => Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: '安装应用',
                        visualDensity: VisualDensity.compact,
                        onPressed: onInstallApp,
                        color: accent,
                        icon: const Icon(
                          Icons.app_registration_outlined,
                          size: 18,
                        ),
                      ),
                      IconButton(
                        tooltip: '复制 UDID',
                        visualDensity: VisualDensity.compact,
                        onPressed: _copyIosUdid,
                        color: accent,
                        icon: const Icon(Icons.content_copy_outlined, size: 18),
                      ),
                    ],
                  ),
                AndroidDevice() => IconButton(
                    tooltip: '安装应用',
                    visualDensity: VisualDensity.compact,
                    onPressed: onInstallApp,
                    color: accent,
                    icon: const Icon(
                      Icons.app_registration_outlined,
                      size: 18,
                    ),
                  ),
              },
            ],
          ),
        ),
      ),
    );
  }
}
