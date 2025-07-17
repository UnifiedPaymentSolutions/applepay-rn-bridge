#import <React/RCTBridgeModule.h>
#import <PassKit/PassKit.h>

// Forward declare classes to avoid circular imports in header
@class ApplePayNetworkService;
@class ApplePayPaymentContext;

NS_ASSUME_NONNULL_BEGIN

@interface ApplePayModule : NSObject <RCTBridgeModule, PKPaymentAuthorizationControllerDelegate>

// --- State Properties ---
@property (nonatomic, strong, nullable) PKPaymentAuthorizationController *session;
@property (nonatomic, strong, nullable) ApplePayPaymentContext *paymentContext; // Holds data for the current payment
@property (nonatomic, assign) BOOL isPaymentInProgress;

// --- Dependencies ---
@property (nonatomic, strong) ApplePayNetworkService *networkService; // Handles network calls

// --- Promise Callbacks ---
@property (nonatomic, copy, nullable) RCTPromiseResolveBlock currentResolve;
@property (nonatomic, copy, nullable) RCTPromiseRejectBlock currentReject;




@end

NS_ASSUME_NONNULL_END
