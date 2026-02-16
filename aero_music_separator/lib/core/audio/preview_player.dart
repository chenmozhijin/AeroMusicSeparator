import 'dart:async';

import 'package:media_kit/media_kit.dart';

enum PreviewPlaybackState { stopped, playing, paused }

class PreviewPlayer {
  PreviewPlayer() {
    _stateController.add(PreviewPlaybackState.stopped);
    _positionController.add(Duration.zero);
    _durationController.add(Duration.zero);
  }

  Player? _player;

  final StreamController<PreviewPlaybackState> _stateController =
      StreamController<PreviewPlaybackState>.broadcast();
  final StreamController<Duration> _positionController =
      StreamController<Duration>.broadcast();
  final StreamController<Duration> _durationController =
      StreamController<Duration>.broadcast();

  StreamSubscription<bool>? _playingSubscription;
  StreamSubscription<bool>? _completedSubscription;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration>? _durationSubscription;
  StreamSubscription<String>? _errorSubscription;

  bool _isLoaded = false;
  bool _isPlaying = false;
  bool _isCompleted = false;

  Stream<PreviewPlaybackState> get stateStream => _stateController.stream;
  Stream<Duration> get positionStream => _positionController.stream;
  Stream<Duration> get durationStream => _durationController.stream;

  Future<void> play(String path) async {
    _ensurePlayerInitialized();
    _isLoaded = true;
    _isCompleted = false;
    await _player!.open(Media(path), play: true);
    _emitState();
  }

  Future<void> pause() async {
    final player = _player;
    if (player == null) {
      return;
    }
    await player.pause();
  }

  Future<void> resume() async {
    final player = _player;
    if (player == null) {
      return;
    }
    await player.play();
  }

  Future<void> stop() async {
    final player = _player;
    if (player != null) {
      await player.stop();
    }
    _isLoaded = false;
    _isPlaying = false;
    _isCompleted = false;
    _positionController.add(Duration.zero);
    _durationController.add(Duration.zero);
    _emitState();
  }

  Future<void> seek(Duration position) async {
    final player = _player;
    if (player == null) {
      return;
    }
    await player.seek(position);
  }

  Future<void> dispose() async {
    await _playingSubscription?.cancel();
    await _completedSubscription?.cancel();
    await _positionSubscription?.cancel();
    await _durationSubscription?.cancel();
    await _errorSubscription?.cancel();
    final player = _player;
    if (player != null) {
      await player.dispose();
      _player = null;
    }
    await _stateController.close();
    await _positionController.close();
    await _durationController.close();
  }

  void _ensurePlayerInitialized() {
    final existing = _player;
    if (existing != null) {
      return;
    }

    final player = Player(
      configuration: const PlayerConfiguration(
        title: 'AeroMusicSeparator',
        osc: false,
        logLevel: MPVLogLevel.error,
        bufferSize: 8 * 1024 * 1024,
      ),
    );
    _player = player;

    _playingSubscription = player.stream.playing.listen((playing) {
      _isPlaying = playing;
      _emitState();
    });
    _completedSubscription = player.stream.completed.listen((completed) {
      _isCompleted = completed;
      if (completed) {
        _isLoaded = false;
      }
      _emitState();
    });
    _positionSubscription = player.stream.position.listen((position) {
      _positionController.add(position);
    });
    _durationSubscription = player.stream.duration.listen((duration) {
      _durationController.add(duration);
    });
    _errorSubscription = player.stream.error.listen((_) {
      _isLoaded = false;
      _isPlaying = false;
      _isCompleted = false;
      _emitState();
    });
  }

  void _emitState() {
    if (_isPlaying) {
      _stateController.add(PreviewPlaybackState.playing);
      return;
    }
    if (!_isLoaded || _isCompleted) {
      _stateController.add(PreviewPlaybackState.stopped);
      return;
    }
    _stateController.add(PreviewPlaybackState.paused);
  }
}
