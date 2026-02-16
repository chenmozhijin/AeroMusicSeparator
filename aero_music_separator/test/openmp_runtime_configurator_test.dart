import 'dart:io';

import 'package:aero_music_separator/core/runtime/openmp_runtime_configurator.dart';
import 'package:aero_music_separator/core/settings/openmp_preset.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

int _clamp(int value, int minValue, int maxValue) {
  return value.clamp(minValue, maxValue).toInt();
}

void main() {
  test('OpenMP preset mapping matches desktop/android/iOS rules', () {
    final configurator = OpenMpRuntimeConfigurator();
    final cores = Platform.numberOfProcessors;

    expect(
      configurator.resolveThreadCountForTest(
        preset: OpenMpPreset.disabled,
        forceCpu: false,
        platform: TargetPlatform.windows,
      ),
      1,
    );

    expect(
      configurator.resolveThreadCountForTest(
        preset: OpenMpPreset.auto,
        forceCpu: true,
        platform: TargetPlatform.windows,
      ),
      _clamp((cores * 0.85).floor(), 4, 16),
    );

    expect(
      configurator.resolveThreadCountForTest(
        preset: OpenMpPreset.conservative,
        forceCpu: true,
        platform: TargetPlatform.windows,
      ),
      _clamp((cores * 0.33).floor(), 2, 4),
    );

    expect(
      configurator.resolveThreadCountForTest(
        preset: OpenMpPreset.balanced,
        forceCpu: false,
        platform: TargetPlatform.windows,
      ),
      _clamp((cores * 0.33).floor(), 2, 4),
    );

    expect(
      configurator.resolveThreadCountForTest(
        preset: OpenMpPreset.performance,
        forceCpu: false,
        platform: TargetPlatform.windows,
      ),
      _clamp((cores * 0.50).floor(), 2, 6),
    );

    expect(
      configurator.resolveThreadCountForTest(
        preset: OpenMpPreset.auto,
        forceCpu: false,
        platform: TargetPlatform.android,
      ),
      _clamp((cores * 0.20).floor(), 1, 2),
    );

    expect(
      configurator.resolveThreadCountForTest(
        preset: OpenMpPreset.performance,
        forceCpu: true,
        platform: TargetPlatform.android,
      ),
      _clamp((cores * 0.33).floor(), 2, 4),
    );

    expect(
      configurator.resolveThreadCountForTest(
        preset: OpenMpPreset.auto,
        forceCpu: false,
        platform: TargetPlatform.iOS,
      ),
      1,
    );
  });
}
