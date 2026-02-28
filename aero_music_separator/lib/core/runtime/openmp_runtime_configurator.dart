import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../ffi/ams_native.dart';
import '../settings/openmp_preset.dart';

class OpenMpRuntimeConfigurator {
  OpenMpRuntimeConfigurator({AmsNative? native}) : _native = native;

  AmsNative? _native;

  AmsNative get _ffi => _native ??= AmsNative.instance;

  Future<void> applyForNextTask({
    required OpenMpPreset preset,
    required bool forceCpu,
    required TargetPlatform platform,
  }) async {
    final threads = _resolveThreadCount(
      preset: preset,
      forceCpu: forceCpu,
      platform: platform,
    );

    _ffi.runtimeSetEnv('OMP_NUM_THREADS', '$threads');
    _ffi.runtimeSetEnv('OMP_THREAD_LIMIT', '$threads');
    _ffi.runtimeSetEnv('OMP_DYNAMIC', 'FALSE');
    if (platform == TargetPlatform.android) {
      _ffi.runtimeSetEnv('OMP_PROC_BIND', 'TRUE');
      _ffi.runtimeSetEnv('OMP_PLACES', 'cores');
      _ffi.runtimeSetEnv('KMP_BLOCKTIME', '0');
    }
  }

  int _resolveThreadCount({
    required OpenMpPreset preset,
    required bool forceCpu,
    required TargetPlatform platform,
  }) {
    if (platform == TargetPlatform.iOS) {
      return 1;
    }

    final cores = math.max(1, Platform.numberOfProcessors);

    if (preset == OpenMpPreset.disabled) {
      return 1;
    }

    if (platform == TargetPlatform.android) {
      if (forceCpu) {
        switch (preset) {
          case OpenMpPreset.auto:
            return _clamp((cores * 0.40).floor(), 2, 4);
          case OpenMpPreset.conservative:
            return _clamp((cores * 0.50).floor(), 2, 5);
          case OpenMpPreset.balanced:
            return _clamp((cores * 0.66).floor(), 3, 6);
          case OpenMpPreset.performance:
            return _clamp((cores * 0.80).floor(), 4, 8);
          case OpenMpPreset.disabled:
            return 1;
        }
      }

      switch (preset) {
        case OpenMpPreset.auto:
        case OpenMpPreset.conservative:
          return _clamp((cores * 0.20).floor(), 1, 2);
        case OpenMpPreset.balanced:
          return _clamp((cores * 0.25).floor(), 2, 3);
        case OpenMpPreset.performance:
          return _clamp((cores * 0.33).floor(), 2, 4);
        case OpenMpPreset.disabled:
          return 1;
      }
    }

    final effectivePreset = preset == OpenMpPreset.auto
        ? OpenMpPreset.performance
        : preset;

    if (forceCpu) {
      switch (effectivePreset) {
        case OpenMpPreset.conservative:
          return _clamp((cores * 0.33).floor(), 2, 4);
        case OpenMpPreset.balanced:
          return _clamp((cores * 0.50).floor(), 2, 8);
        case OpenMpPreset.performance:
          return _clamp((cores * 0.85).floor(), 4, 16);
        case OpenMpPreset.auto:
        case OpenMpPreset.disabled:
          return 1;
      }
    }

    switch (effectivePreset) {
      case OpenMpPreset.conservative:
        return _clamp((cores * 0.25).floor(), 1, 3);
      case OpenMpPreset.balanced:
        return _clamp((cores * 0.33).floor(), 2, 4);
      case OpenMpPreset.performance:
        return _clamp((cores * 0.50).floor(), 2, 6);
      case OpenMpPreset.auto:
      case OpenMpPreset.disabled:
        return 1;
    }
  }

  @visibleForTesting
  int resolveThreadCountForTest({
    required OpenMpPreset preset,
    required bool forceCpu,
    required TargetPlatform platform,
  }) {
    return _resolveThreadCount(
      preset: preset,
      forceCpu: forceCpu,
      platform: platform,
    );
  }

  int _clamp(int value, int minValue, int maxValue) {
    return value.clamp(minValue, maxValue).toInt();
  }
}
