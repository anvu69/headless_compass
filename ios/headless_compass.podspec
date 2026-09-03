#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint headless_compass.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'headless_compass'
  s.version          = '0.1.1'
  s.summary          = 'Headless iOS compass: heading, accuracy and source as a stream.'
  s.description      = <<-DESC
Wraps CLLocationManager heading into a typed Dart stream. No widgets, no
exceptions, and no location permission until the app explicitly asks for true
north.
                       DESC
  s.homepage         = 'https://github.com/anvu69/headless_compass'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'anvu69' => 'anvu69@users.noreply.github.com' }
  s.source           = { :path => '.' }
  s.source_files = 'headless_compass/Sources/headless_compass/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '13.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'

  # Bản kê khai quyền riêng tư: gói này KHÔNG thu thập gì. Kê khai rõ chuyện đó
  # đỡ cho app dùng gói một câu phải tự trả lời khi nộp App Store.
  s.resource_bundles = {'headless_compass_privacy' => ['headless_compass/Sources/headless_compass/PrivacyInfo.xcprivacy']}
end
