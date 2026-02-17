import 'package:shared_preferences/shared_preferences.dart';

import 'openmp_preset.dart';

class AppSettingsStore {
  static const String _lastModelPathKey = 'last_model_path';
  static const String _forceCpuEnabledKey = 'force_cpu_enabled';
  static const String _openMpPresetKey = 'openmp_preset';
  static const String _localeOverrideKey = 'locale_override';

  Future<String?> readLastModelPath() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_lastModelPathKey);
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    return value;
  }

  Future<void> writeLastModelPath(String value) async {
    final prefs = await SharedPreferences.getInstance();
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      await prefs.remove(_lastModelPathKey);
      return;
    }
    await prefs.setString(_lastModelPathKey, trimmed);
  }

  Future<void> clearLastModelPath() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_lastModelPathKey);
  }

  Future<String?> migrateLastModelPath({
    required Future<String?> Function(String path) migrate,
  }) async {
    final current = await readLastModelPath();
    if (current == null) {
      return null;
    }
    final migrated = await migrate(current);
    if (migrated == null || migrated.trim().isEmpty) {
      await clearLastModelPath();
      return null;
    }
    final trimmed = migrated.trim();
    if (trimmed != current) {
      await writeLastModelPath(trimmed);
    }
    return trimmed;
  }

  Future<bool> readForceCpuEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_forceCpuEnabledKey) ?? false;
  }

  Future<void> writeForceCpuEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_forceCpuEnabledKey, value);
  }

  Future<OpenMpPreset> readOpenMpPreset() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_openMpPresetKey);
    return parseOpenMpPreset(value) ?? OpenMpPreset.auto;
  }

  Future<void> writeOpenMpPreset(OpenMpPreset value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_openMpPresetKey, value.storageValue);
  }

  Future<String?> readLocaleOverride() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_localeOverrideKey)?.trim().toLowerCase();
    if (value == null || value.isEmpty) {
      return null;
    }
    if (value == 'en' || value == 'zh') {
      return value;
    }
    return null;
  }

  Future<void> writeLocaleOverride(String? value) async {
    final prefs = await SharedPreferences.getInstance();
    final normalized = value?.trim().toLowerCase();
    if (normalized == null || normalized.isEmpty) {
      await prefs.remove(_localeOverrideKey);
      return;
    }
    if (normalized != 'en' && normalized != 'zh') {
      await prefs.remove(_localeOverrideKey);
      return;
    }
    await prefs.setString(_localeOverrideKey, normalized);
  }
}
