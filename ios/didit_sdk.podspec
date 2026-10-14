Pod::Spec.new do |s|
  s.name             = 'didit_sdk'
  s.version          = '4.10.0'
  s.summary          = 'Didit Identity Verification SDK for Flutter'
  s.description      = <<-DESC
Flutter plugin wrapping the native DiditSDK for identity verification
with document scanning, NFC passport reading, and liveness detection.
                       DESC
  s.homepage         = 'https://github.com/didit-protocol/sdk-flutter'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Didit' => 'support@didit.me' }
  s.source           = { :path => '.' }
  s.source_files = 'didit_sdk/Sources/didit_sdk/**/*.swift'
  s.resource_bundles = { 'didit_sdk_privacy' => ['didit_sdk/Sources/didit_sdk/Resources/PrivacyInfo.xcprivacy'] }
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
                      when 'autodetection' # deprecated, identical to core
                        'DiditSDK/Core'
                      when 'nfc'
                        'DiditSDK/NFC'
                      else
                        raise "Invalid DiditSdk iOS variant '#{didit_sdk_ios_variant}'. Set $DiditSdkIosVariant in your Podfile to one of: all, core, autodetection, nfc."
                      end

  # Opt-in Location verification: $DiditSdkIosLocationEnabled (Podfile) or the
  # DIDIT_SDK_IOS_LOCATION_ENABLED env var ("true"), default off. The native SDK
  # ships Location as complete variants, so the flag swaps the one subspec for
  # its -Location twin (All-Location, Core-Location, NFC-Location).
  didit_sdk_ios_location = (defined?($DiditSdkIosLocationEnabled) && !$DiditSdkIosLocationEnabled.nil? ? $DiditSdkIosLocationEnabled : ENV.fetch('DIDIT_SDK_IOS_LOCATION_ENABLED', 'false')).to_s.downcase == 'true'
  didit_sdk_ios_pod += '-Location' if didit_sdk_ios_location
  s.dependency didit_sdk_ios_pod, '4.10.0'

  s.platform = :ios, '13.0'
  s.static_framework = true
  s.swift_version = '5.0'

  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
end
