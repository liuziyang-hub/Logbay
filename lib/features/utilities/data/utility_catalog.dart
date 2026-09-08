import 'package:flutter/material.dart';

import '../../../data/device.dart';
import 'utility_command.dart';

/// The Utilities catalog: curated `adb` / `adb shell` commands a developer
/// actually reaches for, with a libimobiledevice equivalent wherever one
/// exists (`idevicediagnostics`, `ideviceinfo`, `idevicename`, `idevicedate`,
/// `idevicepair`, `idevicesetlocation` — all already bundled).
///
/// Commands that have no counterpart on the other platform simply return
/// `null` from their builder and are hidden for that device; nothing else in
/// the feature is platform-aware.
final List<UtilityGroup> utilityCatalog = [
  _powerGroup,
  _infoGroup,
  _screenGroup,
  _appsGroup,
  _debugGroup,
];

// ── Builder helpers ───────────────────────────────────────────────────────

UtilityInvocation? _adb(Device device, List<String> arguments) =>
    device is AndroidDevice ? UtilityInvocation.adb(arguments) : null;

UtilityInvocation? _adbShell(Device device, String script) =>
    device is AndroidDevice ? UtilityInvocation.adbShell(script) : null;

UtilityInvocation? _idevice(
  Device device,
  UtilityTool tool,
  List<String> arguments,
) => device is IosDevice ? UtilityInvocation(tool, arguments) : null;

// ── Power & connection ────────────────────────────────────────────────────

final _powerGroup = UtilityGroup(
  id: 'power',
  title: '电源与连接',
  icon: Icons.power_settings_new,
  commands: [
    UtilityCommand(
      id: 'reboot',
      label: '重启设备',
      description: '重启设备，恢复后会重新连接。',
      icon: Icons.restart_alt,
      confirmation: '设备将重启并短暂断开连接。',
      expectsOutput: false,
      successMessage: '已请求重启。',
      build: (device, args) =>
          _adb(device, ['reboot']) ??
          _idevice(device, UtilityTool.idevicediagnostics, ['restart']),
    ),
    UtilityCommand(
      id: 'power-off',
      label: '关机',
      description:
          '关闭设备电源。之后需要手动开机。',
      icon: Icons.power_off,
      confirmation:
          '设备将关机 — 需要手动开机后才会重新出现在列表中。',
      expectsOutput: false,
      successMessage: '已请求关机。',
      build: (device, args) =>
          _adbShell(device, 'reboot -p') ??
          _idevice(device, UtilityTool.idevicediagnostics, ['shutdown']),
    ),
    UtilityCommand(
      id: 'sleep-screen',
      label: '息屏',
      description: '关闭屏幕，不额外锁定其他内容。',
      icon: Icons.bedtime_outlined,
      expectsOutput: false,
      successMessage: '屏幕已息屏。',
      build: (device, args) =>
          _adbShell(device, 'input keyevent 223') ??
          _idevice(device, UtilityTool.idevicediagnostics, ['sleep']),
    ),
    UtilityCommand(
      id: 'wake-screen',
      label: '亮屏',
      description: '重新点亮屏幕。',
      icon: Icons.wb_sunny_outlined,
      expectsOutput: false,
      successMessage: '屏幕已唤醒。',
      build: (device, args) => _adbShell(device, 'input keyevent 224'),
    ),
    UtilityCommand(
      id: 'reboot-recovery',
      label: '重启到恢复模式',
      description: '重启进入系统恢复分区。',
      icon: Icons.medical_services_outlined,
      confirmation:
          '设备将进入恢复模式，并暂时从设备列表消失，直到重新启动到 Android。',
      expectsOutput: false,
      successMessage: '正在重启到恢复模式。',
      build: (device, args) => _adb(device, ['reboot', 'recovery']),
    ),
    UtilityCommand(
      id: 'reboot-bootloader',
      label: '重启到引导模式',
      description: '重启进入 fastboot / 引导加载程序。',
      icon: Icons.developer_board,
      confirmation:
          '设备将进入引导模式，并暂时从设备列表消失，直到重新启动到 Android。',
      expectsOutput: false,
      successMessage: '正在重启到引导模式。',
      build: (device, args) => _adb(device, ['reboot', 'bootloader']),
    ),
    UtilityCommand(
      id: 'reconnect',
      label: '重连传输',
      description:
          '重置 adb 连接 — 设备卡住时常用的修复方式。',
      icon: Icons.usb,
      build: (device, args) => _adb(device, ['reconnect']),
    ),
    UtilityCommand(
      id: 'pair-status',
      label: '检查配对',
      description: '检查此电脑是否仍被设备信任。',
      icon: Icons.verified_user_outlined,
      build: (device, args) =>
          _idevice(device, UtilityTool.idevicepair, ['validate']),
    ),
    UtilityCommand(
      id: 'unpair',
      label: '取消配对',
      description: '移除与此电脑的信任关系。',
      icon: Icons.link_off,
      confirmation:
          '设备将不再信任此电脑。之后需要在设备上再次点「信任」才能使用日志或应用功能。',
      build: (device, args) =>
          _idevice(device, UtilityTool.idevicepair, ['unpair']),
    ),
  ],
);

// ── Device info ───────────────────────────────────────────────────────────

final _infoGroup = UtilityGroup(
  id: 'info',
  title: '设备信息',
  icon: Icons.info_outline,
  commands: [
    UtilityCommand(
      id: 'system-properties',
      label: '系统属性',
      description: '完整属性 / 设备信息转储。',
      icon: Icons.list_alt,
      build: (device, args) =>
          _adbShell(device, 'getprop') ??
          _idevice(device, UtilityTool.ideviceinfo, const []),
    ),
    UtilityCommand(
      id: 'battery',
      label: '电池状态',
      description: '电量、健康度、温度与充电来源。',
      icon: Icons.battery_full,
      build: (device, args) =>
          _adbShell(device, 'dumpsys battery') ??
          _idevice(device, UtilityTool.idevicediagnostics, [
            'diagnostics',
            'GasGauge',
          ]),
    ),
    UtilityCommand(
      id: 'storage',
      label: '存储占用',
      description: '各文件系统的可用与已用空间。',
      icon: Icons.storage,
      build: (device, args) =>
          _adbShell(device, 'df -h') ??
          _idevice(device, UtilityTool.ideviceinfo, [
            '-q',
            'com.apple.disk_usage',
          ]),
    ),
    UtilityCommand(
      id: 'device-name',
      label: '设备名称',
      description: '设备对外显示的名称。',
      icon: Icons.badge_outlined,
      build: (device, args) =>
          _adbShell(device, 'settings get global device_name') ??
          _idevice(device, UtilityTool.idevicename, const []),
    ),
    UtilityCommand(
      id: 'device-date',
      label: '日期与时间',
      description:
          '设备当前时间 — 排查令牌过早过期时很有用。',
      icon: Icons.schedule,
      build: (device, args) =>
          _adbShell(device, 'date') ??
          _idevice(device, UtilityTool.idevicedate, const []),
    ),
    UtilityCommand(
      id: 'network',
      label: '网络地址',
      description: '设备已分配的 IP / Wi-Fi 地址。',
      icon: Icons.wifi,
      build: (device, args) =>
          _adbShell(device, 'ip -f inet addr') ??
          _idevice(device, UtilityTool.ideviceinfo, ['-k', 'WiFiAddress']),
    ),
    UtilityCommand(
      id: 'screen-metrics',
      label: '屏幕尺寸与密度',
      description: '物理与覆盖分辨率，以及 dpi。',
      icon: Icons.aspect_ratio,
      build: (device, args) => _adbShell(device, 'wm size; wm density'),
    ),
    UtilityCommand(
      id: 'processes',
      label: '运行中的进程',
      description: '带 pid 的进程列表（等同 `ps -A`）。',
      icon: Icons.memory,
      build: (device, args) => _adbShell(device, 'ps -A'),
    ),
  ],
);

// ── Screen & input ────────────────────────────────────────────────────────

const _keyEventOptions = [
  UtilityOption('3', '主页'),
  UtilityOption('4', '返回'),
  UtilityOption('187', '最近任务'),
  UtilityOption('82', '菜单'),
  UtilityOption('66', '回车'),
  UtilityOption('67', '退格'),
  UtilityOption('84', '搜索'),
  UtilityOption('26', '电源'),
  UtilityOption('24', '音量加'),
  UtilityOption('25', '音量减'),
  UtilityOption('164', '静音'),
  UtilityOption('27', '相机'),
  UtilityOption('220', '亮度减'),
  UtilityOption('221', '亮度加'),
];

const _rotationOptions = [
  UtilityOption('0', '竖屏'),
  UtilityOption('1', '横屏'),
  UtilityOption('2', '倒置竖屏'),
  UtilityOption('3', '反向横屏'),
  UtilityOption('auto', '自动旋转'),
];

const _animationScaleOptions = [
  UtilityOption('0', '关闭（最快）'),
  UtilityOption('0.5', '0.5×'),
  UtilityOption('1', '1×（默认）'),
  UtilityOption('2', '2×（慢动作）'),
];

const _toggleOptions = [UtilityOption('1', '开'), UtilityOption('0', '关')];

final _screenGroup = UtilityGroup(
  id: 'screen',
  title: '屏幕与输入',
  icon: Icons.touch_app_outlined,
  commands: [
    UtilityCommand(
      id: 'input-text',
      label: '输入文本',
      description: '向当前焦点输入框输入文本。',
      icon: Icons.keyboard_alt_outlined,
      expectsOutput: false,
      successMessage: '文本已发送到设备。',
      params: const [
        UtilityParam(key: 'text', label: '文本', hint: '要输入的内容'),
      ],
      // `input text` treats spaces as argument separators, so they go over the
      // wire as %s.
      build: (device, args) => _adbShell(
        device,
        'input text ${shellQuote(args['text'].replaceAll(' ', '%s'))}',
      ),
    ),
    UtilityCommand(
      id: 'key-event',
      label: '发送按键',
      description: '按下硬件键或导航键。',
      icon: Icons.smart_button,
      expectsOutput: false,
      successMessage: '按键已发送。',
      params: const [
        UtilityParam.choice(
          key: 'code',
          label: '按键',
          options: _keyEventOptions,
          defaultValue: '3',
        ),
      ],
      build: (device, args) =>
          _adbShell(device, 'input keyevent ${args['code']}'),
    ),
    UtilityCommand(
      id: 'open-url',
      label: '打开链接 / 深链',
      description: '在设备上打开网页或应用深链。',
      icon: Icons.link,
      params: const [
        UtilityParam(
          key: 'url',
          label: '链接地址',
          hint: 'https://example.com 或 myapp://path',
        ),
      ],
      build: (device, args) => _adbShell(
        device,
        'am start -a android.intent.action.VIEW -d ${shellQuote(args['url'])}',
      ),
    ),
    UtilityCommand(
      id: 'rotation',
      label: '设置旋转',
      description:
          '强制方向，或交回给传感器自动控制。',
      icon: Icons.screen_rotation,
      expectsOutput: false,
      successMessage: '旋转已应用。',
      params: const [
        UtilityParam.choice(
          key: 'rotation',
          label: '方向',
          options: _rotationOptions,
          defaultValue: '0',
        ),
      ],
      build: (device, args) {
        final rotation = args['rotation'];
        if (rotation == 'auto') {
          return _adbShell(
            device,
            'settings put system accelerometer_rotation 1',
          );
        }
        return _adbShell(
          device,
          'settings put system accelerometer_rotation 0; '
          'settings put system user_rotation $rotation',
        );
      },
    ),
    UtilityCommand(
      id: 'resolution',
      label: '覆盖分辨率',
      description: '模拟其他屏幕尺寸。输入 reset 可恢复。',
      icon: Icons.fit_screen,
      params: const [
        UtilityParam(
          key: 'size',
          label: '尺寸',
          hint: '1080x1920 或 reset',
          defaultValue: 'reset',
        ),
      ],
      build: (device, args) =>
          _adbShell(device, 'wm size ${shellQuote(args['size'])}'),
    ),
    UtilityCommand(
      id: 'density',
      label: '覆盖密度',
      description: '模拟其他 dpi。输入 reset 可恢复。',
      icon: Icons.grid_4x4,
      params: const [
        UtilityParam(
          key: 'density',
          label: '密度',
          hint: '420 或 reset',
          defaultValue: 'reset',
        ),
      ],
      build: (device, args) =>
          _adbShell(device, 'wm density ${shellQuote(args['density'])}'),
    ),
    UtilityCommand(
      id: 'show-touches',
      label: '显示点击',
      description: '在触摸位置绘制标记。',
      icon: Icons.adjust,
      expectsOutput: false,
      successMessage: '点击指示已更新。',
      params: const [
        UtilityParam.choice(
          key: 'value',
          label: '显示点击',
          options: _toggleOptions,
          defaultValue: '1',
        ),
      ],
      build: (device, args) => _adbShell(
        device,
        'settings put system show_touches ${args['value']}',
      ),
    ),
    UtilityCommand(
      id: 'animation-scale',
      label: '动画缩放',
      description: '一次性加快或减慢所有系统动画。',
      icon: Icons.speed,
      expectsOutput: false,
      successMessage: '动画缩放已更新。',
      params: const [
        UtilityParam.choice(
          key: 'scale',
          label: '缩放',
          options: _animationScaleOptions,
          defaultValue: '0',
        ),
      ],
      build: (device, args) {
        final scale = args['scale'];
        return _adbShell(
          device,
          'settings put global window_animation_scale $scale; '
          'settings put global transition_animation_scale $scale; '
          'settings put global animator_duration_scale $scale',
        );
      },
    ),
  ],
);

// ── Apps & permissions ────────────────────────────────────────────────────

final _appsGroup = UtilityGroup(
  id: 'apps',
  title: '应用与权限',
  icon: Icons.security_outlined,
  commands: [
    UtilityCommand(
      id: 'foreground-activity',
      label: '前台界面',
      description: '当前屏幕上的应用与界面。',
      icon: Icons.center_focus_strong_outlined,
      build: (device, args) => _adbShell(
        device,
        "dumpsys window | grep -E 'mCurrentFocus|mFocusedApp'",
      ),
    ),
    UtilityCommand(
      id: 'grant-permission',
      label: '授予权限',
      description: '无需进入设置即可授予运行时权限。',
      icon: Icons.lock_open,
      expectsOutput: false,
      successMessage: '权限已授予。',
      params: const [
        UtilityParam(key: 'package', label: '包名', hint: 'com.example.app'),
        UtilityParam(
          key: 'permission',
          label: '权限',
          hint: 'android.permission.CAMERA',
        ),
      ],
      build: (device, args) => _adbShell(
        device,
        'pm grant ${shellQuote(args['package'])} '
        '${shellQuote(args['permission'])}',
      ),
    ),
    UtilityCommand(
      id: 'revoke-permission',
      label: '撤销权限',
      description:
          '收回运行时权限 — 不会重启应用。',
      icon: Icons.lock_outline,
      expectsOutput: false,
      successMessage: '权限已撤销。',
      params: const [
        UtilityParam(key: 'package', label: '包名', hint: 'com.example.app'),
        UtilityParam(
          key: 'permission',
          label: '权限',
          hint: 'android.permission.CAMERA',
        ),
      ],
      build: (device, args) => _adbShell(
        device,
        'pm revoke ${shellQuote(args['package'])} '
        '${shellQuote(args['permission'])}',
      ),
    ),
    UtilityCommand(
      id: 'reset-permissions',
      label: '重置权限',
      description:
          '将所有运行时权限恢复为「询问」，如同全新安装。',
      icon: Icons.restore,
      confirmation:
          '该包的所有运行时权限将恢复为「询问」。过程中会强制停止应用。',
      params: const [
        UtilityParam(key: 'package', label: '包名', hint: 'com.example.app'),
      ],
      build: (device, args) => _adbShell(
        device,
        'pm reset-permissions -p ${shellQuote(args['package'])}',
      ),
    ),
    UtilityCommand(
      id: 'package-info',
      label: '包详情',
      description: '版本、安装来源、权限与组件。',
      icon: Icons.inventory_2_outlined,
      params: const [
        UtilityParam(key: 'package', label: '包名', hint: 'com.example.app'),
      ],
      build: (device, args) =>
          _adbShell(device, 'dumpsys package ${shellQuote(args['package'])}'),
    ),
    UtilityCommand(
      id: 'monkey',
      label: 'Monkey 压力测试',
      description:
          '向应用发送伪随机 UI 事件，用于发现崩溃。',
      icon: Icons.bolt,
      confirmation:
          '应用将收到大量随机点击与手势。请勿在已登录的生产账号上运行。',
      params: const [
        UtilityParam(key: 'package', label: '包名', hint: 'com.example.app'),
        UtilityParam(
          key: 'events',
          label: '事件数',
          hint: '500',
          defaultValue: '500',
        ),
      ],
      build: (device, args) => _adbShell(
        device,
        'monkey -p ${shellQuote(args['package'])} -v ${args['events']} -s 100',
      ),
    ),
  ],
);

// ── Debug & diagnostics ───────────────────────────────────────────────────

final _debugGroup = UtilityGroup(
  id: 'debug',
  title: '调试与诊断',
  icon: Icons.terminal,
  commands: [
    UtilityCommand(
      id: 'clear-logcat',
      label: '清空日志缓冲',
      description: '清空设备上的 logcat 环形缓冲。',
      icon: Icons.cleaning_services_outlined,
      expectsOutput: false,
      successMessage: '日志缓冲已清空。',
      build: (device, args) => _adb(device, ['logcat', '-c']),
    ),
    UtilityCommand(
      id: 'dumpsys',
      label: '转储系统服务',
      description:
          '某个服务的原始 `dumpsys` 输出（battery、power、wifi…）。',
      icon: Icons.data_object,
      params: const [
        UtilityParam(
          key: 'service',
          label: '服务',
          hint: 'battery, power, wifi, activity …',
          defaultValue: 'battery',
        ),
      ],
      build: (device, args) =>
          _adbShell(device, 'dumpsys ${shellQuote(args['service'])}'),
    ),
    UtilityCommand(
      id: 'shell-command',
      label: '运行 shell 命令',
      description: '兜底入口 — 设备 shell 能理解的任意命令。',
      icon: Icons.code,
      params: const [
        UtilityParam(
          key: 'command',
          label: '命令',
          hint: 'pm list packages -3',
        ),
      ],
      // Deliberately unquoted: the whole point is to pass the line through.
      build: (device, args) => _adbShell(device, args['command']),
    ),
    UtilityCommand(
      id: 'ios-diagnostics',
      label: '硬件诊断',
      description: '完整诊断转储（电池、NAND、Wi-Fi…）。',
      icon: Icons.monitor_heart_outlined,
      build: (device, args) => _idevice(
        device,
        UtilityTool.idevicediagnostics,
        ['diagnostics', 'All'],
      ),
    ),
    UtilityCommand(
      id: 'set-location',
      label: '模拟定位',
      description: '覆盖报告的 GPS 位置。',
      icon: Icons.my_location,
      expectsOutput: false,
      successMessage: '已设置模拟定位。',
      params: const [
        UtilityParam(key: 'lat', label: '纬度', hint: '48.8584'),
        UtilityParam(key: 'lon', label: '经度', hint: '2.2945'),
      ],
      // `--` so a negative latitude isn't parsed as a flag.
      build: (device, args) => _idevice(
        device,
        UtilityTool.idevicesetlocation,
        ['--', args['lat'], args['lon']],
      ),
    ),
    UtilityCommand(
      id: 'reset-location',
      label: '重置模拟定位',
      description: '将定位交还给真实 GPS。',
      icon: Icons.location_searching,
      expectsOutput: false,
      successMessage: '模拟定位已清除。',
      build: (device, args) =>
          _idevice(device, UtilityTool.idevicesetlocation, ['reset']),
    ),
  ],
);
