import '../ffi/ams_native.dart';
import 'separation_models.dart';

class ModelDefaults {
  const ModelDefaults({
    required this.chunkSize,
    required this.overlap,
    required this.sampleRate,
  });

  final int chunkSize;
  final int overlap;
  final int sampleRate;
}

class ModelDefaultsService {
  ModelDefaultsService({AmsNative? native}) : _native = native;

  AmsNative? _native;

  AmsNative get _ffi => _native ??= AmsNative.instance;

  Future<ModelDefaults> loadDefaults({
    required String modelPath,
    required AmsBackend backend,
  }) async {
    final handle = _ffi.openEngine(modelPath, backend);
    try {
      final defaults = _ffi.getDefaults(handle);
      return ModelDefaults(
        chunkSize: defaults.chunkSize,
        overlap: defaults.overlap,
        sampleRate: defaults.sampleRate,
      );
    } finally {
      _ffi.closeEngine(handle);
    }
  }
}
