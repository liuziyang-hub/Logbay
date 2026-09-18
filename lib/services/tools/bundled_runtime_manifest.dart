import 'dart:convert';
import 'dart:io';

class BundledRuntimeEntry {
  const BundledRuntimeEntry({
    required this.name,
    required this.version,
    required this.file,
    required this.sha256,
    required this.source,
  });

  final String name;
  final String version;
  final String file;
  final String sha256;
  final String source;

  factory BundledRuntimeEntry.fromJson(Map<String, Object?> json) {
    String requiredString(String key) {
      final value = json[key];
      if (value is! String || value.trim().isEmpty) {
        throw FormatException('运行时清单缺少有效字段：$key');
      }
      return value.trim();
    }

    final hash = requiredString('sha256').toLowerCase();
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(hash)) {
      throw const FormatException('运行时清单中的 SHA-256 格式无效。');
    }
    return BundledRuntimeEntry(
      name: requiredString('name'),
      version: requiredString('version'),
      file: requiredString('file'),
      sha256: hash,
      source: requiredString('source'),
    );
  }
}

class BundledRuntimeManifest {
  const BundledRuntimeManifest({
    required this.schemaVersion,
    required this.entries,
  });

  final int schemaVersion;
  final List<BundledRuntimeEntry> entries;

  factory BundledRuntimeManifest.parse(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('运行时清单必须是 JSON 对象。');
    }
    final schemaVersion = decoded['schemaVersion'];
    final rawEntries = decoded['entries'];
    if (schemaVersion is! int || schemaVersion != 1) {
      throw const FormatException('不支持的运行时清单版本。');
    }
    if (rawEntries is! List<Object?> || rawEntries.isEmpty) {
      throw const FormatException('运行时清单没有可用组件。');
    }
    return BundledRuntimeManifest(
      schemaVersion: schemaVersion,
      entries: rawEntries
          .map((entry) {
            if (entry is! Map<String, Object?>) {
              throw const FormatException('运行时组件格式无效。');
            }
            return BundledRuntimeEntry.fromJson(entry);
          })
          .toList(growable: false),
    );
  }

  factory BundledRuntimeManifest.read(File file) =>
      BundledRuntimeManifest.parse(file.readAsStringSync());

  BundledRuntimeEntry? find(String name) {
    for (final entry in entries) {
      if (entry.name == name) return entry;
    }
    return null;
  }
}
