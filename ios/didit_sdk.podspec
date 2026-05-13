Pod::Spec.new do |s|
  s.name             = 'didit_sdk'
  s.version          = '3.7.0'
  s.summary          = 'Didit Identity Verification SDK for Flutter'
  s.description      = <<-DESC
Flutter plugin wrapping the native DiditSDK for identity verification
with document scanning, NFC passport reading, and liveness detection.
                       DESC
  s.homepage         = 'https://github.com/didit-protocol/sdk-flutter'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Didit' => 'support@didit.me' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'

  didit_sdk_ios_nfc_enabled = ENV.fetch('DIDIT_SDK_IOS_NFC_ENABLED', 'true').downcase != 'false'
  didit_sdk_ios_pod = didit_sdk_ios_nfc_enabled ? 'DiditSDK' : 'DiditSDK/Core'
  s.dependency didit_sdk_ios_pod, '~> 3.6'

  s.platform = :ios, '13.0'
  s.static_framework = true
  s.swift_version = '5.0'

  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
end
