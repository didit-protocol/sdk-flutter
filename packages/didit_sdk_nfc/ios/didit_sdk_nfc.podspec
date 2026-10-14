Pod::Spec.new do |s|
  s.name             = 'didit_sdk_nfc'
  s.version          = '4.10.0'
  s.summary          = 'Didit Identity Verification SDK for Flutter - nfc variant'
  s.description      = <<-DESC
Didit identity verification Flutter plugin pinned to the DiditSDK/NFC native SDK
variant (automatic capture and NFC passport reading). Generated from didit_sdk.
                       DESC
  s.homepage         = 'https://github.com/didit-protocol/sdk-flutter'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Didit' => 'support@didit.me' }
  s.source           = { :path => '.' }
  s.source_files = 'didit_sdk_nfc/Sources/didit_sdk_nfc/**/*.swift'
  s.resource_bundles = { 'didit_sdk_nfc_privacy' => ['didit_sdk_nfc/Sources/didit_sdk_nfc/Resources/PrivacyInfo.xcprivacy'] }
  s.dependency 'Flutter'

  # Fixed native variant - unlike didit_sdk this podspec intentionally ignores
  # $DiditSdkIosVariant. Keep your Podfile's DiditSDK subspec line in sync
  # (DiditSDK/NFC) when building with CocoaPods. Location verification is opt-in
  # through $DiditSdkIosLocationEnabled (or DIDIT_SDK_IOS_LOCATION_ENABLED=true),
  # which swaps the subspec for its -Location twin (DiditSDK/NFC-Location).
  didit_sdk_ios_location = (defined?($DiditSdkIosLocationEnabled) && !$DiditSdkIosLocationEnabled.nil? ? $DiditSdkIosLocationEnabled : ENV.fetch('DIDIT_SDK_IOS_LOCATION_ENABLED', 'false')).to_s.downcase == 'true'
  s.dependency "DiditSDK/NFC#{'-Location' if didit_sdk_ios_location}", '4.10.0'

  s.platform = :ios, '15.0'
  s.static_framework = true
  s.swift_version = '5.0'

  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
end
