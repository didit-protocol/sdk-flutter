Pod::Spec.new do |s|
  s.name             = 'didit_auth'
  s.version          = '0.1.0'
  s.summary          = 'Didit Authentication for Flutter'
  s.description      = <<-DESC
Flutter plugin wrapping native DiditAuth: hosted sign-in with PKCE, passkeys,
sessions in the Keychain, sign-out and step-ups.
                       DESC
  s.homepage         = 'https://github.com/didit-protocol/sdk-flutter'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Didit' => 'support@didit.me' }
  s.source           = { :path => '.' }
  s.source_files = 'didit_auth/Sources/didit_auth/**/*.swift'
  s.resource_bundles = { 'didit_auth_privacy' => ['didit_auth/Sources/didit_auth/Resources/PrivacyInfo.xcprivacy'] }
  s.dependency 'Flutter'

  # The native release this plugin pins. ../android/build.gradle.kts and
  # didit_auth/Package.swift pin the same one; test/native_pin_test.dart keeps
  # the three equal. The host's Podfile names the DiditSDK podspec (see the README).
  didit_auth_native_version = '4.15.0'
  s.dependency 'DiditSDK/Auth', didit_auth_native_version

  # DiditAuth needs iOS 15; its hosted pages need 17.4 at run time and fail
  # with browser_unavailable below that.
  s.platform = :ios, '15.0'
  s.static_framework = true
  s.swift_version = '5.0'

  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',
    'FRAMEWORK_SEARCH_PATHS' => [
      '$(inherited)',
      '"${PODS_CONFIGURATION_BUILD_DIR}/DiditSDK"',
      '"${PODS_XCFRAMEWORKS_BUILD_DIR}/DiditSDK"',
      '"${PODS_XCFRAMEWORKS_BUILD_DIR}/DiditSDK/Auth"'
    ].join(' ')
  }
end
