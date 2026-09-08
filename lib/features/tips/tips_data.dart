import 'package:flutter/material.dart';

import 'tip.dart';

/// The rotating pool of feature tips. Each launch surfaces the next one.
///
/// Keep every [Tip.title] short enough to read at a glance in the header and
/// every [Tip.detail] to a couple of sentences — the panel is meant to be
/// quiet and skimmable, not a manual.
const List<Tip> kTips = [
  Tip(
    id: 'hide-columns',
    icon: Icons.view_column_outlined,
    title: '隐藏不常用的列',
    detail:
        '日志表格的列数往往超出实际需要。右键点击任意列标题即可显示或隐藏各列——'
        '精简为仅保留消息列，或在需要时加回 PID、标记和时间戳。',
    actionHint: '在日志视图中右键点击列标题',
  ),
  Tip(
    id: 'advanced-filters',
    icon: Icons.filter_alt_outlined,
    title: '精确匹配、正则与否定过滤',
    detail:
        '将筛选栏切换为「内联」样式即可输入高级筛选条件。'
        '使用 "tag:MyTag" 匹配、"-tag:Noise" 排除、"tag=:Exact" 精确匹配、'
        '"tag~:Err.*" 正则匹配。组合多个条件即可精准定位所需日志行。',
    actionHint: '筛选样式 → 内联（在筛选栏或设置中）',
  ),
  Tip(
    id: 'time-filter',
    icon: Icons.schedule_outlined,
    title: '仅显示最近几分钟',
    detail:
        '追踪刚发生的问题？在筛选中添加时间窗口，如 "5m"、"30s" 或 "1h"，'
        '即可隐藏更早的日志，让嘈杂的日志流收缩为近期活动。',
    actionHint: '在筛选中输入时长，如 5m',
  ),
  Tip(
    id: 'multiple-tabs',
    icon: Icons.tab_outlined,
    title: '每台设备可开多个日志标签页',
    detail:
        '不限于单一日志流。在同一设备上打开额外日志标签页，'
        '可同时保留筛选视图与原始日志，或并排对比两次捕获。',
    actionHint: '使用设备标签旁的「新建标签页」操作',
  ),
  Tip(
    id: 'import-logs',
    icon: Icons.file_open_outlined,
    title: '无设备时打开已保存的日志',
    detail:
        '未连接设备？仍可打开先前保存的日志文件。'
        '它将加载到「导入日志」工作区，筛选、搜索和列设置均可正常使用。',
    actionHint: '将日志文件拖入窗口，或使用「打开日志」',
  ),
  Tip(
    id: 'drag-drop-install',
    icon: Icons.install_mobile_outlined,
    title: '拖放应用至窗口即可安装',
    detail:
        '将 .apk（Android）或 .ipa（iOS）拖放到已连接的设备上即可就地安装。'
        '拖放其他文件则会复制到设备——无需命令行。',
    actionHint: '将文件拖放到设备标签页',
  ),
  Tip(
    id: 'screen-mirror',
    icon: Icons.screen_share_outlined,
    title: '镜像设备屏幕',
    detail:
        '除日志外，还可在应用内镜像设备屏幕，'
        '便于在复现问题时同时观察界面与日志流。',
    actionHint: '在设备侧栏中选择「镜像」功能',
  ),
  Tip(
    id: 'device-home',
    icon: Icons.home_outlined,
    title: '设备主页概览',
    detail:
        '主页可查看身份、系统、电池、存储、连接状态等完整信息，'
        '以及实时 CPU / 内存 / 电池等仪表；字段支持复制。',
    actionHint: '在设备侧栏中选择「主页」',
  ),
  Tip(
    id: 'adb-shell',
    icon: Icons.terminal_outlined,
    title: '内置终端',
    detail:
        '无需另开命令行：在「终端」面板直接运行 adb / idevice 命令，'
        'Android 还可隐式进入设备 shell。',
    actionHint: '在已连接的设备上打开「终端」',
  ),
  Tip(
    id: 'crash-reports',
    icon: Icons.bug_report_outlined,
    title: '浏览崩溃报告',
    detail:
        '可从设备拉取崩溃报告并列出，'
        '无需在原始日志中翻找即可阅读堆栈跟踪。',
    actionHint: '在设备侧栏中打开「崩溃报告」功能',
  ),
  Tip(
    id: 'ios-unified-log',
    icon: Icons.apple,
    title: 'iOS 统一日志（os_trace）',
    detail:
        '默认优先使用 pymobiledevice3 拉取统一日志（含更多 Debug/Info）。'
        '若本机未安装会自动回退 idevicesyslog；可在设置中开关。',
    actionHint: '设置 → iOS 统一日志',
  ),
  Tip(
    id: 'app-view-logs',
    icon: Icons.article_outlined,
    title: '从应用列表只看它的日志',
    detail:
        '在「应用」中右键目标 App，选择「查看日志」。'
        '会新开标签页并按包名过滤，Android 还会跟随进程 PID（重启后仍跟得住）。',
    actionHint: '应用 → 右键 → 查看日志',
  ),
];
