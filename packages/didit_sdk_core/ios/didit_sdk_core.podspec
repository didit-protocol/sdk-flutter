Pod::Spec.new do |s|
  s.name             = 'didit_sdk_core'
  s.version          = '4.7.4'
  s.summary          = 'Didit Identity Verification SDK for Flutter - core variant'
  s.description      = <<-DESC
Didit identity verification Flutter plugin pinned to the DiditSDK/Core native SDK
variant (smallest, manual capture only - no automatic capture, no NFC). Generated from didit_sdk.
                       DESC
  s.homepage         = 'https://github.com/didit-protocol/sdk-flutter'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Didit' => 'support@didit.me' }
  s.source           = { :path => '.' }
  s.source_files = 'didit_sdk_core/Sources/didit_sdk_core/**/*.swift'
  s.resource_bundles = { 'didit_sdk_core_privacy' => ['didit_sdk_core/Sources/didit_sdk_core/Resources/PrivacyInfo.xcprivacy'] }
  s.dependency 'Flutter'

  # Fixed native variant - unlike didit_sdk this podspec intentionally ignores
  # $DiditSdkIosVariant. Keep your Podfile's DiditSDK subspec line in sync
  # (DiditSDK/Core) when building with CocoaPods.
  s.dependency 'DiditSDK/Core', '4.7.2'

  s.platform = :ios, '13.0'
  s.static_framework = true
  s.swift_version = '5.0'

  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
end
