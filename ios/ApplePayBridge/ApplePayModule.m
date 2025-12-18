//
//  ApplePayModule.m
//  ApplePayBridge
//
//  Thin wrapper around EPApplePayManager SDK for React Native.
//

#import "ApplePayModule.h"
#import <React/RCTLog.h>
#import <React/RCTConvert.h>
#import <React/RCTUtils.h>
#import <EverypayApplePay/EPApplePayManager.h>

// Error domain for this module
static NSString * const ApplePayModuleErrorDomain = @"com.everypay.ApplePayModule";

typedef NS_ENUM(NSInteger, ApplePayModuleErrorCode) {
    ApplePayModuleErrorNotConfigured = 1000,
    ApplePayModuleErrorPresentationFailed = 1001,
    ApplePayModuleErrorCancelled = 1002,
    ApplePayModuleErrorPaymentInProgress = 1003,
    ApplePayModuleErrorInvalidConfig = 1004,
};

@implementation ApplePayModule

RCT_EXPORT_MODULE(ApplePayModule);

+ (BOOL)requiresMainQueueSetup {
    return YES;
}

//-------------------------------------------------------------------------------------------
#pragma mark - Exported Methods
//-------------------------------------------------------------------------------------------

/**
 * Check if Apple Pay is available on this device
 */
RCT_EXPORT_METHOD(canMakePayments:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject) {
    BOOL canPay = [[EPApplePayManager sharedManager] canMakePayments];
    RCTLogInfo(@"[ApplePayModule] canMakePayments: %@", canPay ? @"YES" : @"NO");
    resolve(@(canPay));
}

/**
 * Check if device supports recurring payment tokens (iOS 16+)
 */
RCT_EXPORT_METHOD(canRequestRecurringToken:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject) {
    BOOL canRequest = [[EPApplePayManager sharedManager] canRequestRecurringToken];
    RCTLogInfo(@"[ApplePayModule] canRequestRecurringToken: %@", canRequest ? @"YES" : @"NO");
    resolve(@(canRequest));
}

/**
 * Configure the SDK before presenting payment sheet
 */
RCT_EXPORT_METHOD(configure:(NSDictionary *)config
                  resolve:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject) {
    RCTLogInfo(@"[ApplePayModule] configure called with config: %@", config);

    // Extract configuration
    NSNumber *amountNumber = [RCTConvert NSNumber:config[@"amount"]];
    NSString *merchantIdentifier = [RCTConvert NSString:config[@"merchantIdentifier"]];
    NSString *merchantName = [RCTConvert NSString:config[@"merchantName"]];
    NSString *currencyCode = [RCTConvert NSString:config[@"currencyCode"]];
    NSString *countryCode = [RCTConvert NSString:config[@"countryCode"]];

    // Validate required fields
    if (!amountNumber || !merchantIdentifier || !merchantName || !currencyCode || !countryCode) {
        NSString *errorMsg = @"Missing required configuration fields";
        RCTLogError(@"[ApplePayModule] %@", errorMsg);
        reject(@"invalid_config", errorMsg, nil);
        return;
    }

    NSDecimalNumber *amount = [NSDecimalNumber decimalNumberWithDecimal:[amountNumber decimalValue]];

    // Configure the SDK
    EPApplePayManager *manager = [EPApplePayManager sharedManager];
    [manager configureWithAmount:amount
              merchantIdentifier:merchantIdentifier
                    merchantName:merchantName
                    currencyCode:currencyCode
                     countryCode:countryCode
                      buttonType:PKPaymentButtonTypeBuy
                     buttonStyle:PKPaymentButtonStyleBlack];

    // Configure recurring payment if provided
    NSDictionary *recurringConfig = config[@"recurring"];
    if (recurringConfig && [manager canRequestRecurringToken]) {
        manager.requestRecurringToken = YES;
        manager.recurringPaymentDescription = [RCTConvert NSString:recurringConfig[@"description"]];

        NSString *managementURLString = [RCTConvert NSString:recurringConfig[@"managementURL"]];
        if (managementURLString) {
            manager.recurringManagementURL = [NSURL URLWithString:managementURLString];
        }

        NSString *billingLabel = [RCTConvert NSString:recurringConfig[@"billingLabel"]];
        if (billingLabel) {
            manager.recurringBillingLabel = billingLabel;
        }

        NSString *billingAgreement = [RCTConvert NSString:recurringConfig[@"billingAgreement"]];
        if (billingAgreement) {
            manager.recurringBillingAgreement = billingAgreement;
        }

        RCTLogInfo(@"[ApplePayModule] Configured recurring payment with description: %@", manager.recurringPaymentDescription);
    } else {
        manager.requestRecurringToken = NO;
    }

    RCTLogInfo(@"[ApplePayModule] SDK configured successfully");
    resolve(@{@"success": @YES});
}

/**
 * Present Apple Pay sheet and return serialized token
 */
RCT_EXPORT_METHOD(presentPayment:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject) {
    RCTLogInfo(@"[ApplePayModule] presentPayment called");

    // Check if payment is already in progress
    if (self.isPaymentInProgress) {
        RCTLogWarn(@"[ApplePayModule] Payment already in progress");
        reject(@"payment_in_progress", @"Another payment is already in progress", nil);
        return;
    }

    // Store callbacks
    self.currentResolve = resolve;
    self.currentReject = reject;
    self.isPaymentInProgress = YES;

    // Get the root view controller
    dispatch_async(dispatch_get_main_queue(), ^{
        UIViewController *rootVC = RCTPresentedViewController();
        if (!rootVC) {
            rootVC = [UIApplication sharedApplication].delegate.window.rootViewController;
        }

        if (!rootVC) {
            RCTLogError(@"[ApplePayModule] Could not find root view controller");
            [self rejectWithCode:@"presentation_failed"
                         message:@"Could not find view controller to present Apple Pay sheet"
                           error:nil];
            return;
        }

        // Present Apple Pay sheet using the SDK
        [[EPApplePayManager sharedManager] presentPaymentFromViewController:rootVC
                                                          completionHandler:^(PKPayment * _Nullable payment, NSError * _Nullable error) {
            if (error) {
                // Handle error (including cancellation)
                if (error.code == 1002) { // User cancelled
                    RCTLogInfo(@"[ApplePayModule] Payment cancelled by user");
                    [self rejectWithCode:@"cancelled"
                                 message:@"Payment cancelled by user"
                                   error:error];
                } else {
                    RCTLogError(@"[ApplePayModule] Payment error: %@", error.localizedDescription);
                    [self rejectWithCode:@"payment_error"
                                 message:error.localizedDescription
                                   error:error];
                }
                return;
            }

            if (!payment) {
                RCTLogError(@"[ApplePayModule] No payment object received");
                [self rejectWithCode:@"payment_error"
                             message:@"No payment received"
                               error:nil];
                return;
            }

            // Serialize the payment token
            [self serializePaymentToken:payment];
        }];
    });
}

/**
 * Enable/disable mock payments (debug builds only)
 */
RCT_EXPORT_METHOD(setMockPaymentsEnabled:(BOOL)enabled
                  resolve:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject) {
#ifdef DEBUG
    [[NSUserDefaults standardUserDefaults] setBool:enabled forKey:@"EP_MOCK_PAYMENTS_ENABLED"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    RCTLogInfo(@"[ApplePayModule] Mock payments %@", enabled ? @"enabled" : @"disabled");
    resolve(@{@"success": @YES});
#else
    RCTLogInfo(@"[ApplePayModule] Mock payments can only be enabled in debug builds");
    resolve(@{@"success": @NO, @"reason": @"Mock payments can only be enabled in debug builds"});
#endif
}

//-------------------------------------------------------------------------------------------
#pragma mark - Private Helper Methods
//-------------------------------------------------------------------------------------------

/**
 * Serialize PKPayment to dictionary for JavaScript
 */
- (void)serializePaymentToken:(PKPayment *)payment {
    NSMutableDictionary *result = [NSMutableDictionary dictionary];
    result[@"success"] = @YES;

    // Base64 encode the payment data
    NSData *paymentData = payment.token.paymentData;
    if (paymentData) {
        result[@"paymentData"] = [paymentData base64EncodedStringWithOptions:0];
    } else {
        result[@"paymentData"] = @"";
    }

    // Transaction identifier
    result[@"transactionIdentifier"] = payment.token.transactionIdentifier ?: @"";

    // Payment method info
    PKPaymentMethod *method = payment.token.paymentMethod;
    result[@"paymentMethod"] = @{
        @"displayName": method.displayName ?: @"",
        @"network": method.network ?: @"",
        @"type": @(method.type)
    };

    RCTLogInfo(@"[ApplePayModule] Payment token serialized successfully");
    [self resolveWithSuccess:result];
}

/**
 * Resolve promise and cleanup
 */
- (void)resolveWithSuccess:(NSDictionary *)result {
    if (self.currentResolve) {
        RCTPromiseResolveBlock resolveBlock = self.currentResolve;
        [self clearCallbacks];
        resolveBlock(result);
    }
    self.isPaymentInProgress = NO;
}

/**
 * Reject promise and cleanup
 */
- (void)rejectWithCode:(NSString *)code message:(NSString *)message error:(NSError * _Nullable)error {
    if (self.currentReject) {
        RCTPromiseRejectBlock rejectBlock = self.currentReject;
        [self clearCallbacks];

        NSError *rejectionError = error;
        if (!rejectionError) {
            rejectionError = [NSError errorWithDomain:ApplePayModuleErrorDomain
                                                 code:0
                                             userInfo:@{NSLocalizedDescriptionKey: message}];
        }
        rejectBlock(code, message, rejectionError);
    }
    self.isPaymentInProgress = NO;
}

/**
 * Clear promise callbacks
 */
- (void)clearCallbacks {
    self.currentResolve = nil;
    self.currentReject = nil;
}

@end
