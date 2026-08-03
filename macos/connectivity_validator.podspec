#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint connectivity_validator.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'connectivity_validator'
  s.version          = '0.1.3'
  s.summary          = 'Validated internet connectivity for Flutter (macOS).'
  s.description      = <<-DESC
Detects real internet access (not just a network link) and captive portals using
native NWPathMonitor plus an HTTPS validation probe.
                       DESC
  s.homepage         = 'https://github.com/sabeelmuttil/connectivity_validator'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Sabeel KM' => 'sabeelmuttil@gmail.com' }

  s.source           = { :path => '.' }
  s.source_files = 'connectivity_validator/Sources/connectivity_validator/**/*.swift'
  s.resource_bundles = {'connectivity_validator_privacy' => ['connectivity_validator/Sources/connectivity_validator/PrivacyInfo.xcprivacy']}

  s.dependency 'FlutterMacOS'

  # NWPathMonitor requires macOS 10.14+
  s.platform = :osx, '10.14'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version = '5.0'
end
