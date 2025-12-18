Pod::Spec.new do |s|
  s.name         = "everypay-applepay-rn-bridge"
  s.version      = "1.1.0"
  s.summary      = "Everypay Apple Pay React Native Bridge with dual-mode support"
  s.description  = <<-DESC
    React Native bridge for Apple Pay using EverypayApplePay SDK.
    Supports two modes:
    - Backend Mode (recommended): Credentials stay on your backend
    - SDK Mode: Library makes API calls
  DESC
  s.homepage     = "https://github.com/UnifiedPaymentSolutions/applepay-rn-bridge.git"
  s.license      = "MIT"
  s.author       = { "Risto Solman" => "risto.solman@datanor.ee" }
  s.platform     = :ios, "15.0"
  s.source       = { :git => "https://github.com/UnifiedPaymentSolutions/applepay-rn-bridge.git", :tag => "v#{s.version}" }
  s.source_files = "ios/ApplePayBridge/**/*.{h,m}"
  s.requires_arc = true

  s.dependency "React-Core"

  # EverypayApplePay SDK dependency
  # NOTE: Since the SDK is not yet published to CocoaPods, consumers must add
  # a local path reference in their app's Podfile:
  #
  #   pod 'EverypayApplePay', :path => '../path/to/everypay-applepay-sdk-client/EverypayApplePay'
  #
  # Once the SDK is published, uncomment the line below:
  # s.dependency "EverypayApplePay", "~> 0.1.0"
end
