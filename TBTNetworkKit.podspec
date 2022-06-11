#
# Be sure to run `pod lib lint TBTNetworkKit.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'TBTNetworkKit'
  s.version          = '0.1.0'
  s.summary          = '网络请求二次封装 TBTNetworkKit.'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = <<-DESC
TODO: Add long description of the pod here.
                       DESC

  s.homepage         = 'https://github.com/RainyofSun/TBTNetworkKit'
  # s.screenshots     = 'www.example.com/screenshots_1', 'www.example.com/screenshots_2'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'RainyofSun' => '807602063@qq.com' }
  s.source           = { :git => 'https://github.com/RainyofSun/TBTNetworkKit.git', :tag => s.version.to_s }
  # s.social_media_url = 'https://twitter.com/<TWITTER_USERNAME>'

  s.ios.deployment_target = '9.0'

  s.source_files = 'TBTNetworkKit/Classes/**/*'
  
  # s.resource_bundles = {
  #   'TBTNetworkKit' => ['TBTNetworkKit/Assets/*.png']
  # }

   s.public_header_files = 'Pod/Classes/TBTNetworkKit.h'
   # ------------------- 文件分级 --------------------- #
   s.subspec 'Cache' do |ss|
    ss.source_files = 'TBTNetworkKit/Classes/Cache/*'
    end
   s.subspec 'Manager' do |ss|
    ss.source_files = 'TBTNetworkKit/Classes/Manager/*'
    ss.dependency 'TBTNetworkKit/Request'
    ss.dependency 'TBTNetworkKit/Response'
    end
   s.subspec 'Request' do |ss|
    ss.source_files = 'TBTNetworkKit/Classes/Request/*'
    end
   s.subspec 'Response' do |ss|
    ss.source_files = 'TBTNetworkKit/Classes/Response/*'
    ss.dependency 'TBTNetworkKit/Response'
    ss.dependency 'TBTNetworkKit/Manager'
    ss.dependency 'TBTNetworkKit/Cache'
    end
  # s.frameworks = 'UIKit', 'MapKit'
   s.dependency 'AFNetworking', '=3.0'
   s.dependency 'YYCache', '=1.0.4'
end
