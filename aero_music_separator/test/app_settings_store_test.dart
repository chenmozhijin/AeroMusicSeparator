import 'package:aero_music_separator/core/settings/app_settings_store.dart';
import 'package:aero_music_separator/core/settings/openmp_preset.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('AppSettingsStore persists model path and cpu flag', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final store = AppSettingsStore();

    expect(await store.readLastModelPath(), isNull);
    expect(await store.readForceCpuEnabled(), isFalse);
    expect(await store.readOpenMpPreset(), OpenMpPreset.auto);
    expect(await store.readLocaleOverride(), isNull);

    await store.writeLastModelPath('/tmp/model.gguf');
    await store.writeForceCpuEnabled(true);
    await store.writeOpenMpPreset(OpenMpPreset.performance);
    await store.writeLocaleOverride('zh');

    expect(await store.readLastModelPath(), '/tmp/model.gguf');
    expect(await store.readForceCpuEnabled(), isTrue);
    expect(await store.readOpenMpPreset(), OpenMpPreset.performance);
    expect(await store.readLocaleOverride(), 'zh');

    await store.writeLocaleOverride(null);
    expect(await store.readLocaleOverride(), isNull);
  });

  test('AppSettingsStore migrates last model path and clears invalid value', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'last_model_path': '/legacy/model.gguf',
    });
    final store = AppSettingsStore();

    final migrated = await store.migrateLastModelPath(
      migrate: (path) async => '/managed/active.gguf',
    );
    expect(migrated, '/managed/active.gguf');
    expect(await store.readLastModelPath(), '/managed/active.gguf');

    final cleared = await store.migrateLastModelPath(
      migrate: (path) async => null,
    );
    expect(cleared, isNull);
    expect(await store.readLastModelPath(), isNull);
  });
}
