enum LogFilterViewMode {
  classic,
  inline;

  String get label => switch (this) {
	LogFilterViewMode.classic => '经典',
	LogFilterViewMode.inline => '内联',
  };

  String get description => switch (this) {
	LogFilterViewMode.classic =>
	  '级别、软件包、标记、消息分栏筛选。',
	LogFilterViewMode.inline =>
	  '单个 Logcat 风格输入框，支持智能建议（如 level:error、tag:Auth）。',
  };

  static LogFilterViewMode fromStored(String? value) {
	return LogFilterViewMode.values.firstWhere(
	  (mode) => mode.name == value,
	  orElse: () => LogFilterViewMode.classic,
	);
  }
}
