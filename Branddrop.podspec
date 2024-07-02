#
# Be sure to run `pod lib lint Branddrop.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'Branddrop'
  s.version          = '1.0.0'
  s.summary          = 'Location-based notifications for personalized user engagement and retention campaigns.'
  s.description      = 'BrandDrop iOS SDK, for integrating into you iOS application. The SDK supports iOS 10.0]+'
  s.homepage         = 'https://branddrop.us'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'BrandDrop' => 'info@branddrop.us' }
  s.source           = { :git => 'https://github.com/BoardActive/BD-SDK-iOS.git', :tag => s.version.to_s }
  
  s.ios.deployment_target = '12.0'

  s.swift_version         = '4.0'

  s.requires_arc = true
  
  s.module_name = 'BAKit'

  s.source_files = 'BAKit/Source/**/*.{swift,h,m}'
  
  s.static_framework = true
end
