Pod::Spec.new do |s|
  s.name             = 'AeroSeparatorFFI'
  s.version          = '1.0.0'
  s.summary          = 'Aero Music Separator native FFI runtime for iOS.'
  s.description      = <<-DESC
Static iOS XCFramework bundle for Aero Music Separator FFI runtime.
Includes a keep-alive translation unit to ensure exported C symbols are linked.
  DESC
  s.homepage         = 'https://github.com/aero-music-separator/aero_music_separator'
  s.license          = { :type => 'GPL-3.0-only', :file => '../../../../LICENSE' }
  s.author           = { 'Aero Music Separator' => 'opensource@invalid.local' }
  s.source           = { :path => '.' }
  s.platform         = :ios, '13.0'
  s.swift_version    = '5.0'
  s.requires_arc     = false

  s.vendored_frameworks = 'AeroSeparatorFFI.xcframework'
  s.source_files        = 'AmsFfiKeepAlive.m'
  s.preserve_paths      = 'AeroSeparatorFFI.xcframework'

  # FFmpeg static profile dependencies for iOS link.
  s.frameworks = 'AVFoundation', 'AudioToolbox', 'CoreAudio', 'CoreMedia', 'Foundation'
  s.libraries  = 'c++', 'z', 'bz2', 'iconv'

  s.pod_target_xcconfig = {
    'ENABLE_BITCODE' => 'NO',
  }
end
