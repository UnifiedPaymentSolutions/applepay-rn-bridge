Pod::Spec.new do |s|
  s.name         = "ApplePayBridge"
  s.version      = "1.0.0"
  s.summary      = "Apple Pay for React Native"
  s.homepage     = "https://github.com/yourusername/rn-applepay-everypay-bridge"
  s.license      = "MIT"
  s.author       = { "Risto Solman" => "risto.solman@datanor.ee" }
  s.platform     = :ios, "15.0"
  s.source       = { :git => "https://github.com/yourusername/rn-applepay-everypay-bridge.git", :tag => "v#{s.version}" }
  s.source_files = "ios/**/*.{h,m,swift}"
  s.requires_arc = true
  s.dependency "React-Core"
end
