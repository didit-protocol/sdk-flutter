Pod::Spec.new do |s|
  s.name             = 'didit_sdk'
  s.version          = '4.0.4'
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

  # Variant selection — consumer chooses one of: all, core, autodetection, nfc.
  # Reads from $DiditSdkIosVariant (set in the host app's Podfile) so the choice
  # survives every implicit pod install that `flutter build` triggers. Falls back
  # to DIDIT_SDK_IOS_VARIANT env var for CI workflows, then to 'all'.
  didit_sdk_ios_variant = (defined?($DiditSdkIosVariant) && $DiditSdkIosVariant ? $DiditSdkIosVariant.to_s : ENV.fetch('DIDIT_SDK_IOS_VARIANT', 'all')).downcase
  didit_sdk_ios_pod = case didit_sdk_ios_variant
                      when 'all'
                        'DiditSDK/All'
                      when 'core'
                        'DiditSDK/Core'
                      when 'autodetection'
                        'DiditSDK/AutoDetection'
                      when 'nfc'
                        'DiditSDK/NFC'
                      else
                        raise "Invalid DiditSdk iOS variant '#{didit_sdk_ios_variant}'. Set $DiditSdkIosVariant in your Podfile to one of: all, core, autodetection, nfc."
                      end
  s.dependency didit_sdk_ios_pod, '4.0.4'

  s.platform = :ios, '13.0'
  s.static_framework = true
  s.swift_version = '5.0'

  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
end
