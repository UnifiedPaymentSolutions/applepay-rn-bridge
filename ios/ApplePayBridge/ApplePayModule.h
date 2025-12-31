//
//  ApplePayModule.h
//  ApplePayBridge
//
//  Thin wrapper around EPApplePayManager SDK for React Native.
//

#import <React/RCTBridgeModule.h>

#ifdef RCT_NEW_ARCH_ENABLED
#import <RNApplePayBridgeSpec/RNApplePayBridgeSpec.h>
#endif

NS_ASSUME_NONNULL_BEGIN

@interface ApplePayModule : NSObject <RCTBridgeModule>

// --- Promise Callbacks ---
@property (nonatomic, copy, nullable) RCTPromiseResolveBlock currentResolve;
@property (nonatomic, copy, nullable) RCTPromiseRejectBlock currentReject;

// --- State ---
@property (nonatomic, assign) BOOL isPaymentInProgress;

@end

NS_ASSUME_NONNULL_END
