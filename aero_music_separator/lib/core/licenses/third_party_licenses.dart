import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

const List<_ThirdPartyLicenseSpec> _licenseSpecs = <_ThirdPartyLicenseSpec>[
  _ThirdPartyLicenseSpec(
    packageName: 'FFmpeg',
    assetPath: 'assets/licenses/FFmpeg-LGPL.txt',
  ),
  _ThirdPartyLicenseSpec(
    packageName: 'LAME (libmp3lame)',
    assetPath: 'assets/licenses/LAME-LICENSE.txt',
  ),
  _ThirdPartyLicenseSpec(
    packageName: 'BSRoformer.cpp',
    assetPath: 'assets/licenses/BSRoformer-LICENSE.txt',
  ),
  _ThirdPartyLicenseSpec(
    packageName: 'ggml',
    assetPath: 'assets/licenses/ggml-LICENSE.txt',
  ),
];

Future<void>? _registrationFuture;

Future<void> registerThirdPartyLicenses() {
  return _registrationFuture ??= _registerThirdPartyLicenses();
}

Future<void> _registerThirdPartyLicenses() async {
  for (final _ThirdPartyLicenseSpec spec in _licenseSpecs) {
    try {
      final String licenseText = await rootBundle.loadString(spec.assetPath);
      LicenseRegistry.addLicense(() async* {
        yield LicenseEntryWithLineBreaks(
          <String>[spec.packageName],
          licenseText,
        );
      });
    } catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'third_party_licenses',
          context: ErrorDescription(
            'while loading third-party license asset ${spec.assetPath}',
          ),
        ),
      );
    }
  }
}

class _ThirdPartyLicenseSpec {
  const _ThirdPartyLicenseSpec({
    required this.packageName,
    required this.assetPath,
  });

  final String packageName;
  final String assetPath;
}
