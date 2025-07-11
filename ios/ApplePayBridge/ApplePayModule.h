// ApplePayModule.h

#import <Foundation/Foundation.h>
#import <PassKit/PassKit.h>
#import <React/RCTBridgeModule.h>
#import <React/RCTEventEmitter.h>

@interface ApplePayModule : RCTEventEmitter <RCTBridgeModule, PKPaymentAuthorizationControllerDelegate>

@property (nonatomic, strong) PKPaymentAuthorizationController *session;
@property (nonatomic, assign) BOOL hasListeners;
@property (nonatomic, strong) NSDictionary *paymentData;

@end
