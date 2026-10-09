platform :ios, '18.0'

target 'NavigationWatch' do
  pod 'AMapNavi-NO-IDFA', '11.2.100'
end

# Xcode 27 builds simulator targets starting at iOS 15. The published AMap
# podspecs still generate iOS 9 pod targets, so align them with this app.
post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |configuration|
      configuration.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '18.0'
    end
  end
end
