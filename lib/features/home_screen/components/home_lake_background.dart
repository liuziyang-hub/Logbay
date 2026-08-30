import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:path_provider/path_provider.dart';

import '../../../constants/atmosphere_theme.dart';
import '../../../services/preferences_service.dart';

/// Full-bleed muted looping landing video for the selected atmosphere theme.
///
/// Forest / universe use a pre-baked forward+reverse (boomerang) encode so
/// loop cut points land on matching frames instead of a hard jump.
class HomeLakeBackground extends StatefulWidget {
  const HomeLakeBackground({super.key});

  @override
  State<HomeLakeBackground> createState() => _HomeLakeBackgroundState();
}

class _HomeLakeBackgroundState extends State<HomeLakeBackground> {
  late final Player _player = Player(
    configuration: const PlayerConfiguration(
      muted: true,
      bufferSize: 32 * 1024 * 1024,
      logLevel: MPVLogLevel.error,
    ),
  );
  late final VideoController _controller = VideoController(
    _player,
    configuration: const VideoControllerConfiguration(
      enableHardwareAcceleration: true,
      hwdec: 'auto',
    ),
  );

  final List<StreamSubscription<dynamic>> _subs = [];
  AtmosphereTheme _atmosphere = AtmosphereTheme.lake;
  bool _mountedVideo = false;
  bool _visible = false;
  bool _restarting = false;
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _atmosphere = PreferencesService.atmosphereTheme;
    PreferencesService.atmosphereThemeListenable.addListener(_onAtmosphereChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_start(_atmosphere));
    });
  }

  void _onAtmosphereChanged() {
    final next = PreferencesService.atmosphereThemeListenable.value;
    if (next == _atmosphere) return;
    setState(() {
      _atmosphere = next;
      _visible = false;
    });
    unawaited(_start(next));
  }

  Future<String?> _ensureLocalFile(AtmosphereTheme theme) async {
    final asset = theme.videoAsset;
    if (asset == null) return null;

    final dir = await getApplicationSupportDirectory();
    final file = File(
      '${dir.path}${Platform.pathSeparator}${theme.extractedCacheName}',
    );
    if (await file.exists() && await file.length() > 100 * 1024) {
      return file.path;
    }
    final data = await rootBundle.load(asset);
    final tmp = File('${file.path}.part');
    await tmp.writeAsBytes(data.buffer.asUint8List(), flush: true);
    if (await file.exists()) await file.delete();
    await tmp.rename(file.path);
    return file.path;
  }

  Future<void> _restartFromStart() async {
    if (_restarting) return;
    _restarting = true;
    try {
      // Seek slightly past zero to avoid a one-frame hitch at the join.
      await _player.seek(const Duration(milliseconds: 16));
      await _player.play();
    } catch (_) {
      // Ignore; next completed/playing event may retry.
    } finally {
      _restarting = false;
    }
  }

  Future<void> _start(AtmosphereTheme theme) async {
    final gen = ++_loadGeneration;
    try {
      if (!mounted) return;
      setState(() => _mountedVideo = theme.videoAsset != null);

      final path = await _ensureLocalFile(theme);
      if (gen != _loadGeneration || !mounted) return;

      if (path == null) {
        await _player.stop();
        if (mounted) setState(() => _visible = false);
        return;
      }

      await Future<void>.delayed(const Duration(milliseconds: 80));
      if (gen != _loadGeneration || !mounted) return;

      final platform = _player.platform;
      if (platform is NativePlayer) {
        try {
          await platform.setProperty('audio', 'no');
          await platform.setProperty('hwdec', 'auto');
          await platform.setProperty('framedrop', 'no');
          await platform.setProperty('video-sync', 'display-vdrop');
          await platform.setProperty('video-timing-offset', '0');
          await platform.setProperty('loop-file', 'inf');
          await platform.setProperty('hr-seek', 'yes');
          await platform.setProperty('keep-open', 'yes');
        } catch (_) {}
      }

      await _player.setVolume(0);
      await _player.setPlaylistMode(PlaylistMode.single);
      await _player.open(Media(Uri.file(path).toString()), play: true);

      if (platform is NativePlayer) {
        try {
          await platform.setProperty('loop-file', 'inf');
        } catch (_) {}
      }

      if (gen != _loadGeneration || !mounted) return;
      setState(() => _visible = true);

      for (final s in _subs) {
        unawaited(s.cancel());
      }
      _subs.clear();
      _subs.add(_player.stream.completed.listen((done) {
        if (done) unawaited(_restartFromStart());
      }));
      _subs.add(_player.stream.playing.listen((playing) {
        if (!playing &&
            !_restarting &&
            _player.state.duration > Duration.zero &&
            _player.state.position >=
                _player.state.duration - const Duration(milliseconds: 400)) {
          unawaited(_restartFromStart());
        }
      }));
    } catch (_) {
      // Solid canvas fallback.
    }
  }

  @override
  void dispose() {
    PreferencesService.atmosphereThemeListenable
        .removeListener(_onAtmosphereChanged);
    for (final s in _subs) {
      unawaited(s.cancel());
    }
    unawaited(_player.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = _atmosphere;
    return ColoredBox(
      color: theme.canvasColor,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (_mountedVideo)
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedOpacity(
                  opacity: _visible ? 1 : 0,
                  duration: const Duration(milliseconds: 420),
                  curve: Curves.easeOutCubic,
                  child: Video(
                    controller: _controller,
                    controls: NoVideoControls,
                    fit: BoxFit.cover,
                    pauseUponEnteringBackgroundMode: false,
                    resumeUponEnteringForegroundMode: true,
                  ),
                ),
              ),
            ),
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: theme.overlayGradient,
                    stops: const [0.0, 0.45, 1.0],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
