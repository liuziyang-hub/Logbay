import 'package:flutter/material.dart';

import 'local_assets.dart';

/// One visual theme = video + palette + typography (no separate light/dark).
/// Lake A5 Abyss+Habanero · Forest B6 Misty · Universe U1 Stellar Midnight.
enum AtmosphereTheme {
  lake,
  forest,
  universe,
}

extension AtmosphereThemeX on AtmosphereTheme {
  String get label => switch (this) {
    AtmosphereTheme.lake => '湖边',
    AtmosphereTheme.forest => '森林',
    AtmosphereTheme.universe => '宇宙',
  };

  String get description => switch (this) {
    AtmosphereTheme.lake => '深渊蓝 · 哈瓦那橙 · Cormorant / DM Sans',
    AtmosphereTheme.forest => '雾林灰绿 · Fraunces / Nunito',
    AtmosphereTheme.universe => '星夜靛蓝 · 思源宋体副标 · Italiana / Outfit',
  };

  String get settingsHint => switch (this) {
    AtmosphereTheme.lake => '湖边：深渊蓝主色 + 冰蓝辅色 + 哈瓦那橙点缀',
    AtmosphereTheme.forest => '森林：雾林灰绿，冷调护眼',
    AtmosphereTheme.universe => '宇宙：星夜靛蓝 + 深空靛 + 星光米',
  };

  String? get videoAsset => switch (this) {
    AtmosphereTheme.lake => LocalAssets.homeLakeVideo,
    AtmosphereTheme.forest => LocalAssets.homeForestVideo,
    AtmosphereTheme.universe => LocalAssets.homeUniverseVideo,
  };

  String get extractedCacheName => switch (this) {
    AtmosphereTheme.lake => 'home_lake_seamless_v5.mp4',
    AtmosphereTheme.forest => 'home_forest_boomerang_v1.mp4',
    AtmosphereTheme.universe => 'home_universe_boomerang_v1.mp4',
  };

  Color get titleColor => switch (this) {
    AtmosphereTheme.lake => const Color(0xFFE8F4F8),
    AtmosphereTheme.forest => const Color(0xFFE9EFEC),
    AtmosphereTheme.universe => const Color(0xFFE8ECFF),
  };

  Color get bodyColor => switch (this) {
    AtmosphereTheme.lake => const Color(0xFFA8C8D8),
    AtmosphereTheme.forest => const Color(0xFFC0D0C8),
    AtmosphereTheme.universe => const Color(0xFFC0C8E8),
  };

  Color get mutedColor => switch (this) {
    AtmosphereTheme.lake => const Color(0xFF7A9AAC),
    AtmosphereTheme.forest => const Color(0xFF8A9E96),
    AtmosphereTheme.universe => const Color(0xFF8A94B8),
  };

  Color get canvasColor => switch (this) {
    AtmosphereTheme.lake => const Color(0xFF08131D),
    AtmosphereTheme.forest => const Color(0xFF2A3230),
    AtmosphereTheme.universe => const Color(0xFF0B1026),
  };

  List<Color> get overlayGradient => switch (this) {
    AtmosphereTheme.lake => const [
      Color(0x7308131D),
      Color(0x4008131D),
      Color(0xB308131D),
    ],
    AtmosphereTheme.forest => const [
      Color(0x732A3230),
      Color(0x3D2A3230),
      Color(0xB31E2422),
    ],
    AtmosphereTheme.universe => const [
      Color(0x800B1026),
      Color(0x330B1026),
      Color(0xB80B1026),
    ],
  };

  Color get glassFill => switch (this) {
    AtmosphereTheme.lake => const Color(0xE60F2A3B),
    AtmosphereTheme.forest => const Color(0xE63B4A45),
    AtmosphereTheme.universe => const Color(0xE61A2A4F),
  };

  Color get glassBorder => switch (this) {
    AtmosphereTheme.lake => const Color(0x552D7AA0),
    AtmosphereTheme.forest => const Color(0x5552796F),
    AtmosphereTheme.universe => const Color(0x55A9B6FF),
  };

  Color get cardTitleColor => switch (this) {
    AtmosphereTheme.lake => const Color(0xFFE8F4F8),
    AtmosphereTheme.forest => const Color(0xFFE9EFEC),
    AtmosphereTheme.universe => const Color(0xFFE8ECFF),
  };

  Color get cardBodyColor => switch (this) {
    AtmosphereTheme.lake => const Color(0xFFA8C8D8),
    AtmosphereTheme.forest => const Color(0xFFC0D0C8),
    AtmosphereTheme.universe => const Color(0xFFC0C8E8),
  };

  Color get primaryAccent => switch (this) {
    AtmosphereTheme.lake => const Color(0xFF2D7AA0),
    AtmosphereTheme.forest => const Color(0xFF52796F),
    AtmosphereTheme.universe => const Color(0xFFA9B6FF),
  };

  Color get primaryAccentDeep => switch (this) {
    AtmosphereTheme.lake => const Color(0xFF1C4C66),
    AtmosphereTheme.forest => const Color(0xFF3B4A45),
    AtmosphereTheme.universe => const Color(0xFF2F3C7E),
  };

  Color get secondaryAccent => switch (this) {
    AtmosphereTheme.lake => const Color(0xFF9FD2E3),
    AtmosphereTheme.forest => const Color(0xFF84A98C),
    AtmosphereTheme.universe => const Color(0xFF2F3C7E),
  };

  Color get tertiaryAccent => switch (this) {
    AtmosphereTheme.lake => const Color(0xFFF98513),
    AtmosphereTheme.forest => const Color(0xFFC4A574),
    AtmosphereTheme.universe => const Color(0xFFF2E8C9),
  };

  Color get chipFill => switch (this) {
    AtmosphereTheme.lake => const Color(0xF5E8F4F8),
    AtmosphereTheme.forest => const Color(0xF0E9EFEC),
    AtmosphereTheme.universe => const Color(0xF0E8ECFF),
  };

  Color get chipForeground => switch (this) {
    AtmosphereTheme.lake => const Color(0xFF08131D),
    AtmosphereTheme.forest => const Color(0xFF1A2820),
    AtmosphereTheme.universe => const Color(0xFF0B1026),
  };

  String get tagline => switch (this) {
    AtmosphereTheme.lake => '实时查看设备日志，或打开已保存的日志文件。',
    AtmosphereTheme.forest => '林影深处，实时梳理设备日志，或打开已保存的日志文件。',
    AtmosphereTheme.universe => '在深空里凝视设备日志，或打开已保存的日志文件。',
  };

  String get badge => switch (this) {
    AtmosphereTheme.lake => '湖畔工作台 · 可同时连接多台 Android / iOS 设备',
    AtmosphereTheme.forest => '深林工作台 · 可同时连接多台 Android / iOS 设备',
    AtmosphereTheme.universe => '深空工作台 · 可同时连接多台 Android / iOS 设备',
  };

  static AtmosphereTheme? fromName(String? value) => switch (value) {
    'lake' => AtmosphereTheme.lake,
    'forest' => AtmosphereTheme.forest,
    'universe' => AtmosphereTheme.universe,
    _ => null,
  };
}
