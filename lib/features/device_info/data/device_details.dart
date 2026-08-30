/// Snapshot of device identity / battery / storage / system props for the
/// 「详情」pane. Field values are display-ready Chinese-friendly strings.
class DeviceDetailsSnapshot {
  const DeviceDetailsSnapshot({
    required this.sections,
    this.error,
  });

  /// Ordered sections: each is a title + list of (label, value) rows.
  final List<DeviceDetailsSection> sections;
  final String? error;

  bool get isEmpty => sections.every((s) => s.rows.isEmpty);
}

class DeviceDetailsSection {
  const DeviceDetailsSection({
    required this.title,
    required this.rows,
  });

  final String title;
  final List<DeviceDetailsRow> rows;
}

class DeviceDetailsRow {
  const DeviceDetailsRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;
}
