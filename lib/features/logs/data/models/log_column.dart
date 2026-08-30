enum LogColumn {
  timestamp('时间戳', 170.0, 250.0),
  pid('软件包', 150.0, 200.0),
  tid('PID/TID', 65.0, 100.0),
  level('优先级', 65.0, 100.0),
  tag('标记', 150.0, 300.0),
  message('消息', 0.0, 0.0); // expands to fill remaining space

  final String label;
  final double defaultWidth;
  final double maxWidth;

  const LogColumn(this.label, this.defaultWidth, this.maxWidth);

  static const double minWidth = 30.0;

  bool get isExpandable => this == message;

  String labelFor({bool isIos = false}) => switch (this) {
    LogColumn.pid => isIos ? '进程' : '软件包',
    LogColumn.tag => isIos ? '类别' : '标记',
    _ => label,
  };
}
