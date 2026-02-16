enum OpenMpPreset {
  auto,
  disabled,
  conservative,
  balanced,
  performance,
}

extension OpenMpPresetStorage on OpenMpPreset {
  String get storageValue => name;
}

OpenMpPreset? parseOpenMpPreset(String? rawValue) {
  if (rawValue == null || rawValue.trim().isEmpty) {
    return null;
  }

  final normalized = rawValue.trim().toLowerCase();
  for (final preset in OpenMpPreset.values) {
    if (preset.name == normalized) {
      return preset;
    }
  }
  return null;
}
