import 'package:flutter/services.dart';

abstract interface class MobileExportChannel {
  Future<String?> exportFile({
    required String sourcePath,
    required String suggestedName,
    required String mimeType,
  });
}

class MethodChannelMobileExportChannel implements MobileExportChannel {
  const MethodChannelMobileExportChannel();

  static const MethodChannel _channel = MethodChannel(
    'aero_music_separator/export',
  );

  @override
  Future<String?> exportFile({
    required String sourcePath,
    required String suggestedName,
    required String mimeType,
  }) {
    return _channel.invokeMethod<String>('exportFile', <String, Object>{
      'sourcePath': sourcePath,
      'suggestedName': suggestedName,
      'mimeType': mimeType,
    });
  }
}
