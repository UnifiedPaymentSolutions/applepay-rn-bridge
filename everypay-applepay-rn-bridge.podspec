require "json"

package = JSON.parse(File.read(File.join(__dir__, "package.json")))

Pod::Spec.new do |s|
  s.name         = "everypay-applepay-rn-bridge"
  s.version      = package["version"]
  s.summary      = "Everypay Apple Pay React Native Bridge with dual-mode support"
  s.description  = <<-DESC
    React Native bridge for Apple Pay using EverypayApplePay SDK.
    Supports two modes:
    - Backend Mode (recommended): Credentials stay on your backend
    - SDK Mode: Library makes API calls
    Supports both Old Architecture and New Architecture (TurboModules + Fabric).
  DESC
  s.homepage     = package["homepage"]
  s.license      = package["license"]
  s.author       = package["author"]
  s.platforms    = { :ios => "15.0" }
  s.source       = { :git => "https://github.com/UnifiedPaymentSolutions/applepay-rn-bridge.git", :tag => "v#{s.version}" }
  s.source_files = "ios/ApplePayBridge/**/*.{h,m,mm}"
  s.requires_arc = true

  # React Native dependency - handles both Old and New Architecture
  install_modules_dependencies(s)

  # EverypayApplePay SDK dependency
  # NOTE: Since the SDK is not yet published to CocoaPods, consumers must add
  # a local path reference in their app's Podfile:
  #
  #   pod 'EverypayApplePay', :path => '../path/to/everypay-applepay-sdk-client/EverypayApplePay'
  #
  # Once the SDK is published, uncomment the line below:
  # s.dependency "EverypayApplePay", "~> 0.1.0"
end
