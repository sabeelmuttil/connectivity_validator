#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint connectivity_validator.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'connectivity_validator'
  s.version          = '0.0.5'
  s.summary          = 'A robust internet connectivity checker that validates actual network access using native Android (NET_CAPABILITY_VALIDATED) and iOS (NWPathMonitor) APIs.'
  s.description      = <<-DESC
A robust internet connectivity checker that validates actual network access using native Android (NET_CAPABILITY_VALIDATED) and iOS (NWPathMonitor) APIs.
                       DESC
  s.homepage         = 'https://github.com/sabeelmuttil/connectivity_validator'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Sabeel KM' => 'sabeelmuttil@gmail.com' }
  s.source           = { :path => '.' }
  s.source_files = 'connectivity_validator/Sources/connectivity_validator/**/*.swift'
  s.dependency 'Flutter'
  s.platform = :ios, '13.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'

  # If your plugin requires a privacy manifest, for example if it uses any
  # required reason APIs, update the PrivacyInfo.xcprivacy file to describe your
  # plugin's privacy impact, and then uncomment this line. For more information,
  # see https://developer.apple.com/documentation/bundleresources/privacy_manifest_files
  s.resource_bundles = {'connectivity_validator_privacy' => ['connectivity_validator/Sources/connectivity_validator/PrivacyInfo.xcprivacy']}
end
