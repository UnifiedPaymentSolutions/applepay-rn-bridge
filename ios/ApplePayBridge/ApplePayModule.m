#import <Foundation/Foundation.h>
#import <PassKit/PassKit.h>
#import <React/RCTEventEmitter.h>
#import <React/RCTBridgeModule.h>
#import <React/RCTLog.h>

@interface ApplePayModule : RCTEventEmitter <RCTBridgeModule, PKPaymentAuthorizationControllerDelegate>

@property (nonatomic, strong) PKPaymentAuthorizationController *session;
@property (nonatomic, assign) BOOL hasListeners;
@property (nonatomic, strong) NSDictionary *paymentData;
@property (nonatomic, assign) BOOL paymentSuccessful;

@end

@implementation ApplePayModule

RCT_EXPORT_MODULE(ApplePayModule);

+ (BOOL)requiresMainQueueSetup {
    return YES;
}

- (NSArray<NSString *> *)supportedEvents {
    return @[@"onPaymentSuccess", @"onPaymentFailed"];
}

- (void)startObserving {
    self.hasListeners = YES;
}

- (void)stopObserving {
    self.hasListeners = NO;
}

RCT_EXPORT_METHOD(canMakePayments:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject) {
    BOOL canPay = [PKPaymentAuthorizationController canMakePaymentsUsingNetworks:@[PKPaymentNetworkVisa,
                                                                                   PKPaymentNetworkMasterCard]];
    resolve(@(canPay));
}

- (void)getLinkDataWithPaymentDetailUrl:(NSString *)paymentDetailUrl
                       paymentReference:(NSString *)paymentReference
                            accessToken:(NSString *)accessToken
                             completion:(void (^)(NSDictionary *, NSError *))completion {
    NSURLComponents *urlComponents = [NSURLComponents componentsWithString:paymentDetailUrl];
    urlComponents.queryItems = @[[NSURLQueryItem queryItemWithName:@"payment_reference" value:paymentReference]];
    
    NSURL *url = urlComponents.URL;
    if (!url) {
        NSError *error = [NSError errorWithDomain:@"ApplePay" code:400 userInfo:@{NSLocalizedDescriptionKey: @"Failed to construct URL"}];
        completion(nil, error);
        return;
    }
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setHTTPMethod:@"GET"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setValue:[NSString stringWithFormat:@"Bearer %@",
                       accessToken] forHTTPHeaderField:@"Authorization"];
    
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData *data,
                                                                                                               NSURLResponse *response,
                                                                                                               NSError *error) {
        if (error) {
            completion(nil, error);
            return;
        }
        
        if (!data) {
            NSError *noDataError = [NSError errorWithDomain:@"ApplePay" code:404 userInfo:@{NSLocalizedDescriptionKey: @"No data received"}];
            completion(nil, noDataError);
            return;
        }
        
        NSError *jsonError;
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
        
        if (!json || jsonError) {
            NSError *invalidJsonError = [NSError errorWithDomain:@"ApplePay" code:422 userInfo:@{NSLocalizedDescriptionKey: @"Invalid JSON response"}];
            completion(nil, invalidJsonError);
            return;
        }
        
        completion(json, nil);
    }];
    [task resume];
}

- (void)configureRecurringPayment:(PKPaymentRequest *)paymentRequest linkData:(NSDictionary *)linkData amountString:(NSString *)amountString {
    // Check if this should be a recurring payment
    NSNumber *arrangement = linkData[@"arrangement"];
    NSNumber *tokenConsentAgreed = linkData[@"token_consent_agreed"];
    NSDictionary *shopAttributes = linkData[@"shop_attributes"];
    NSString *descriptorName = shopAttributes[@"descriptor_name"];
    NSString *websiteAddress = shopAttributes[@"website_address"];
    
    if (arrangement && tokenConsentAgreed && shopAttributes && descriptorName && websiteAddress &&
        [arrangement boolValue] == YES && [tokenConsentAgreed boolValue] == YES) {
        
        NSDecimalNumber *amount = [NSDecimalNumber decimalNumberWithString:amountString];
        
        if ([amount floatValue] >= 0.0f) {
            if (@available(iOS 16.0, *)) {
                // iOS 16+ supports PKRecurringPaymentSummaryItem
                PKRecurringPaymentSummaryItem *regularBilling = [PKRecurringPaymentSummaryItem summaryItemWithLabel:@"Recurring Payment" amount:amount];
                
                NSURL *websiteURL = [NSURL URLWithString:websiteAddress];
                if (websiteURL) {
                    paymentRequest.recurringPaymentRequest = [[PKRecurringPaymentRequest alloc] initWithPaymentDescription:descriptorName regularBilling:regularBilling managementURL:websiteURL];
                }
            } else {
                // For earlier iOS versions, use basic approach (without recurring payment support)
                NSMutableArray *mutableSummaryArray = [paymentRequest.paymentSummaryItems mutableCopy];
                [mutableSummaryArray addObject:[PKPaymentSummaryItem summaryItemWithLabel:@"Save card for future payments" amount:[NSDecimalNumber decimalNumberWithString:@"0.00"]]];
                paymentRequest.paymentSummaryItems = mutableSummaryArray;
            }
        }
    }
}

RCT_EXPORT_METHOD(startPayment:(NSDictionary *)config) {
    NSDictionary *endpoints = config[@"endpoints"];
    NSDictionary *paymentInfo = config[@"data"];
    
    NSString *paymentReference = paymentInfo[@"paymentReference"];
    NSNumber *amount = paymentInfo[@"amount"];
    NSString *amountString = [amount stringValue];
    NSString *label = paymentInfo[@"label"];
    NSString *merchantId = paymentInfo[@"merchantId"];
    NSString *countryCode = paymentInfo[@"countryCode"];
    NSString *currencyCode = paymentInfo[@"currencyCode"];
    
    NSString *paymentSessionUrl = endpoints[@"paymentSessionUrl"];
    NSString *authorizePaymentUrl = endpoints[@"authorizePaymentUrl"];
    NSString *paymentDetailUrl = endpoints[@"paymentDetailUrl"];
    
    NSString *accessToken = paymentInfo[@"accessToken"];
    
    // Validate required fields
    if (!paymentReference || !amountString || !label || !merchantId ||
        !countryCode || !currencyCode || !paymentSessionUrl ||
        !authorizePaymentUrl || !paymentDetailUrl || !accessToken) {
        
        if (self.hasListeners) {
            [self sendEventWithName:@"onPaymentFailed" body:@{ @"errorMessage": @"Missing payment configuration fields" }];
        }
        return;
    }

    // Prepare internal paymentData for later use
    self.paymentData = @{
        @"paymentReference": paymentReference,
        @"paymentSessionUrl": paymentSessionUrl,
        @"authorizePaymentUrl": authorizePaymentUrl,
        @"accessToken": accessToken
    };
    
    // Step 1: Get link data
    __weak typeof(self) weakSelf = self;
    [self getLinkDataWithPaymentDetailUrl:paymentDetailUrl
                         paymentReference:paymentReference
                              accessToken:accessToken
                               completion:^(NSDictionary *linkData,
                                            NSError *error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        
        if (error || !linkData) {
            if (strongSelf.hasListeners) {
                [strongSelf sendEventWithName:@"onPaymentFailed"
                                         body:@{ @"error": error ? error.localizedDescription : @"Missing payment detail response" }];
            }
            return;
        }
        
        RCTLogInfo(@"[ApplePayModule] Payment link data: %@", linkData);
        
        // Step 2: Configure Apple Pay
        PKPaymentRequest *paymentRequest = [[PKPaymentRequest alloc] init];
        paymentRequest.merchantIdentifier = merchantId;
        paymentRequest.supportedNetworks = @[PKPaymentNetworkVisa, PKPaymentNetworkMasterCard];
        paymentRequest.merchantCapabilities = PKMerchantCapability3DS;
        paymentRequest.countryCode = countryCode;
        paymentRequest.currencyCode = currencyCode;
        paymentRequest.paymentSummaryItems = @[
            [PKPaymentSummaryItem summaryItemWithLabel:label amount:[NSDecimalNumber decimalNumberWithString:amountString]]
        ];

        // Add summaryItems to internal paymentData
        NSMutableDictionary *mutableData = [strongSelf.paymentData mutableCopy];
        mutableData[@"paymentSummaryItems"] = paymentRequest.paymentSummaryItems;
        strongSelf.paymentData = [mutableData copy];
        
        // Optional: configure recurring payment, if needed
        [strongSelf configureRecurringPayment:paymentRequest linkData:linkData amountString:amountString];
        
        // Step 3: Present Apple Pay sheet
        strongSelf.session = [[PKPaymentAuthorizationController alloc] initWithPaymentRequest:paymentRequest];
        strongSelf.session.delegate = strongSelf;

        RCTLogInfo(@"[ApplePayModule] Merchant id: %@", merchantId);
        RCTLogInfo(@"[ApplePayModule] Payment request: %@", paymentRequest);
        
        dispatch_async(dispatch_get_main_queue(),
 ^{
            [strongSelf.session presentWithCompletion:^(BOOL presented) {
                if (!presented && strongSelf.hasListeners) {
                    [strongSelf sendEventWithName:@"onPaymentFailed" body:@{ @"errorMessage": @"Failed to present Apple Pay sheet" }];
                }
            }];
        });
    }];
}

- (void)paymentAuthorizationController:(PKPaymentAuthorizationController *)controller didRequestMerchantSessionUpdate:(void (^)(PKPaymentRequestMerchantSessionUpdate * _Nonnull))handler  API_AVAILABLE(ios(11.0)) {
    NSString *paymentSessionUrl = self.paymentData[@"paymentSessionUrl"];
    NSString *paymentReference = self.paymentData[@"paymentReference"];
    NSString *accessToken = self.paymentData[@"accessToken"];
    
    RCTLogWarn(@"[ApplePayModule] didRequestMerchantSessionUpdate...");
    
    if (!paymentSessionUrl || !paymentReference || !accessToken) {
        PKPaymentRequestMerchantSessionUpdate *update = [[PKPaymentRequestMerchantSessionUpdate alloc] initWithStatus:PKPaymentAuthorizationStatusFailure merchantSession:nil];
        handler(update);
        return;
    }
    
    NSURL *url = [NSURL URLWithString:paymentSessionUrl];
    if (!url) {
        PKPaymentRequestMerchantSessionUpdate *update = [[PKPaymentRequestMerchantSessionUpdate alloc] initWithStatus:PKPaymentAuthorizationStatusFailure merchantSession:nil];
        handler(update);
        return;
    }
    
    // Your backend validation request
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setHTTPMethod:@"POST"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setValue:[NSString stringWithFormat:@"Bearer %@",
                       accessToken] forHTTPHeaderField:@"Authorization"];
    
    // Prepare payload
    NSDictionary *payload = @{
        @"payment_reference": paymentReference,
        @"validation_url": @""  // Note: This should be the actual validation URL from Apple
    };
    
    NSError *jsonError;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:payload options:0 error:&jsonError];
    
    if (jsonError) {
        PKPaymentRequestMerchantSessionUpdate *update = [[PKPaymentRequestMerchantSessionUpdate alloc] initWithStatus:PKPaymentAuthorizationStatusFailure merchantSession:nil];
        handler(update);
        return;
    }
    
    [request setHTTPBody:jsonData];
    
    __weak typeof(self) weakSelf = self;
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData *data,
                                                                                                               NSURLResponse *response,
                                                                                                               NSError *error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            PKPaymentRequestMerchantSessionUpdate *update = [[PKPaymentRequestMerchantSessionUpdate alloc] initWithStatus:PKPaymentAuthorizationStatusFailure merchantSession:nil];
            handler(update);
            return;
        }
        
        if (error || !data) {
            PKPaymentRequestMerchantSessionUpdate *update = [[PKPaymentRequestMerchantSessionUpdate alloc] initWithStatus:PKPaymentAuthorizationStatusFailure merchantSession:nil];
            handler(update);
            return;
        }
        
        NSError *jsonParseError;
        NSDictionary *jsonObj = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonParseError];
        
        if (jsonParseError || !jsonObj) {
            PKPaymentRequestMerchantSessionUpdate *update = [[PKPaymentRequestMerchantSessionUpdate alloc] initWithStatus:PKPaymentAuthorizationStatusFailure merchantSession:nil];
            handler(update);
            return;
        }
        
        // Initialize merchant session
        PKPaymentMerchantSession *merchantSession = [[PKPaymentMerchantSession alloc] initWithDictionary:jsonObj];
        PKPaymentRequestMerchantSessionUpdate *update = [[PKPaymentRequestMerchantSessionUpdate alloc] initWithStatus:PKPaymentAuthorizationStatusSuccess merchantSession:merchantSession];
        handler(update);
    }];
    [task resume];
}

- (void)paymentAuthorizationControllerDidFinish:(PKPaymentAuthorizationController *)controller {
    [controller dismissWithCompletion:^{
        // Only send cancel event if payment was not already successful
        // This is to avoid sending failure events after successful payments
        if (!self.paymentSuccessful) {
            if (self.hasListeners) {
                [self sendEventWithName:@"onPaymentFailed" body:@{ @"error": @"User canceled payment" }];
            }
        }
    }];
}

- (void)paymentAuthorizationController:(PKPaymentAuthorizationController *)controller
                   didAuthorizePayment:(PKPayment *)payment
                               handler:(void (^)(PKPaymentAuthorizationResult *))completion {
    
    // Mock payment token data (in reality, this would be filled with real payment data)
    NSData *mockTokenData = [@"mockPaymentData" dataUsingEncoding:NSUTF8StringEncoding];
    
    // Create a mock PKPaymentToken
    PKPaymentToken *mockToken = [[PKPaymentToken alloc] init];
    [mockToken setValue:mockTokenData forKey:@"paymentData"];
    
    // Use the mock token to create a PKPayment object
    PKPayment *mockPayment = [[PKPayment alloc] init];
    [mockPayment setValue:mockToken forKey:@"token"];
    
    // Simulate the successful payment result
    PKPaymentAuthorizationResult *result = [[PKPaymentAuthorizationResult alloc] initWithStatus:PKPaymentAuthorizationStatusSuccess errors:nil];
    
    // Call the completion handler
    completion(result);

    self.paymentSuccessful = YES;
    
    // Send event for successful payment (for RN app)
    if (self.hasListeners) {
        RCTLogInfo(@"[ApplePayModule] Send payment success event to RN");
        NSDictionary *eventBody = @{
            @"paymentReference": self.paymentData[@"paymentReference"] ?: @"",
            @"rawResponse": mockToken ?: [NSNull null]
        };
        [self sendEventWithName:@"onPaymentSuccess" body:eventBody];
    }
}

//- (void)paymentAuthorizationController:(PKPaymentAuthorizationController *)controller
//                   didAuthorizePayment:(PKPayment *)payment
//                               handler:(void (^)(PKPaymentAuthorizationResult *))completion {
//    // Process and send token to backend
//    NSString *authorizePaymentUrlStr = self.paymentData[@"authorizePaymentUrl"];
//    NSString *paymentReference = self.paymentData[@"paymentReference"];
//    NSString *accessToken = self.paymentData[@"accessToken"];
//    NSURL *url = [NSURL URLWithString:authorizePaymentUrlStr];
//    
//    RCTLogWarn(@"[ApplePayModule] Did authorize payment with URL: %@",
//               authorizePaymentUrlStr);
//    RCTLogWarn(@"[ApplePayModule] Payment reference: %@", paymentReference);
//    RCTLogWarn(@"[ApplePayModule] Access token: %@", accessToken);
//    RCTLogWarn(@"[ApplePayModule] Payment authorization result: %@", payment);
//    
//    if (!url) {
//        RCTLogError(@"[ApplePayModule] Invalid authorization URL: %@",
//                    authorizePaymentUrlStr);
//        completion([[PKPaymentAuthorizationResult alloc] initWithStatus:PKPaymentAuthorizationStatusFailure errors:nil]);
//        if (self.hasListeners) {
//            [self sendEventWithName:@"onPaymentFailed" body:@{ @"errorMessage": @"Invalid authorization URL" }];
//        }
//        return;
//    }
//
//    RCTLogWarn(@"[ApplePayModule] Extracting payment token data...");
//    
//    // Extract payment token data
//    NSError *jsonError;
//    NSData *tokenData = payment.token.paymentData;
//    NSDictionary *tokenJSON = [NSJSONSerialization JSONObjectWithData:tokenData options:0 error:&jsonError];
//
//    NSString *tokenDataString = [[NSString alloc] initWithData:payment.token.paymentData encoding:NSUTF8StringEncoding];
//    
//    if (jsonError) {
//        RCTLogError(@"[ApplePayModule] Failed to parse payment token data: %@",
//                    jsonError.localizedDescription);
//        completion([[PKPaymentAuthorizationResult alloc] initWithStatus:PKPaymentAuthorizationStatusFailure errors:nil]);
//        if (self.hasListeners) {
//            [self sendEventWithName:@"onPaymentFailed" body:@{ @"error": @"Failed to process payment data" }];
//        }
//        return;
//    }
//    
//    RCTLogWarn(@"[ApplePayModule] Payment token data extracted successfully: %@",
//               tokenJSON);
//    
//    // Prepare payload for backend
//    NSMutableDictionary *payload = [NSMutableDictionary dictionaryWithDictionary:@{
//        @"payment_reference": paymentReference
//    }];
//    [payload addEntriesFromDictionary:tokenJSON];
//    
//    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
//    [request setHTTPMethod:@"POST"];
//    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
//    [request setValue:[NSString stringWithFormat:@"Bearer %@",
//                       accessToken] forHTTPHeaderField:@"Authorization"];
//    [request setHTTPBody:[NSJSONSerialization dataWithJSONObject:payload options:0 error:&jsonError]];
//    
//    RCTLogWarn(@"[ApplePayModule] Sending payment authorization request to backend: %@",
//               url);
//    
//    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData *data,
//                                                                                                               NSURLResponse *response,
//                                                                                                               NSError *error) {
//        if (error) {
//            RCTLogError(@"[ApplePayModule] Failed to send payment authorization request: %@",
//                        error.localizedDescription);
//            completion([[PKPaymentAuthorizationResult alloc] initWithStatus:PKPaymentAuthorizationStatusFailure errors:nil]);
//            if (self.hasListeners) {
//                [self sendEventWithName:@"onPaymentFailed" body:@{ @"errorMessage": [error localizedDescription] }];
//            }
//        } else {
//            RCTLogWarn(@"[ApplePayModule] Payment authorization succeeded. Response data: %@",
//                       [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
//            completion([[PKPaymentAuthorizationResult alloc] initWithStatus:PKPaymentAuthorizationStatusSuccess errors:nil]);
//            if (self.hasListeners) {
//                RCTLogWarn(@"[ApplePayModule] Send payment success event to RN");
//                NSDictionary *eventBody = @{
//                    @"paymentReference": self.paymentData[@"paymentReference"] ?: @"",
//                    @"rawResponse": tokenJSON ?: [NSNull null]
//                };
//                [self sendEventWithName:@"onPaymentSuccess" body:eventBody];
//            }
//        }
//    }];
//    
//    RCTLogWarn(@"[ApplePayModule] Payment authorization request is being sent...");
//    [task resume];
//}

- (void)paymentAuthorizationController:(PKPaymentAuthorizationController *)controller didSelectPaymentMethod:(PKPaymentMethod *)paymentMethod handler:(void (^)(PKPaymentRequestPaymentMethodUpdate * _Nonnull))handler API_AVAILABLE(ios(11.0)) {
    NSArray *paymentSummaryItems = self.paymentData[@"paymentSummaryItems"] ?: @[];
    PKPaymentRequestPaymentMethodUpdate *update = [[PKPaymentRequestPaymentMethodUpdate alloc] initWithPaymentSummaryItems:paymentSummaryItems];
    handler(update);
}

- (void)paymentAuthorizationController:(PKPaymentAuthorizationController *)controller didSelectShippingContact:(PKContact *)contact handler:(void (^)(PKPaymentRequestShippingContactUpdate * _Nonnull))handler API_AVAILABLE(ios(11.0)) {
    NSArray *paymentSummaryItems = self.paymentData[@"paymentSummaryItems"] ?: @[];
    PKPaymentRequestShippingContactUpdate *update = [[PKPaymentRequestShippingContactUpdate alloc] initWithPaymentSummaryItems:paymentSummaryItems];
    handler(update);
}

- (void)paymentAuthorizationController:(PKPaymentAuthorizationController *)controller didSelectShippingMethod:(PKShippingMethod *)shippingMethod handler:(void (^)(PKPaymentRequestShippingMethodUpdate * _Nonnull))handler API_AVAILABLE(ios(11.0)) {
    NSArray *paymentSummaryItems = self.paymentData[@"paymentSummaryItems"] ?: @[];
    PKPaymentRequestShippingMethodUpdate *update = [[PKPaymentRequestShippingMethodUpdate alloc] initWithPaymentSummaryItems:paymentSummaryItems];
    handler(update);
}

- (void)paymentAuthorizationController:(PKPaymentAuthorizationController *)controller didChangeCouponCode:(NSString *)couponCode handler:(void (^)(PKPaymentRequestCouponCodeUpdate * _Nonnull))handler API_AVAILABLE(ios(15.0)) {
    NSArray *paymentSummaryItems = self.paymentData[@"paymentSummaryItems"] ?: @[];
    
    // Create a sample shipping method
    PKShippingMethod *shippingMethod = [[PKShippingMethod alloc] init];
    shippingMethod.label = @"Standard Shipping";
    shippingMethod.amount = [NSDecimalNumber decimalNumberWithString:@"5.00"];
    
    // Create an array with the shipping method
    NSArray *shippingMethods = @[shippingMethod];
    
    // Create the update object
    PKPaymentRequestCouponCodeUpdate *update = [[PKPaymentRequestCouponCodeUpdate alloc]
                                                initWithErrors:nil
                                                paymentSummaryItems:paymentSummaryItems
                                                shippingMethods:shippingMethods];
    
    // Call the completion handler
    handler(update);
}

- (void)initPayment:(NSDictionary *)config completion:(void (^)(NSDictionary *response, NSError *error))completion {
    NSDictionary *auth = config[@"auth"];
    NSDictionary *endpoints = config[@"endpoints"];
    NSDictionary *payload = config[@"data"];
    
    RCTLogInfo(@"[ApplePayModule] Init staring");
    if (!auth || !endpoints || !payload) {
        if (completion) {
            completion(nil,
                       [NSError errorWithDomain:@"ApplePay" code:400 userInfo:@{NSLocalizedDescriptionKey: @"Missing required sections: auth, endpoints, or data"}]);
        }
        return;
    }
    
    NSString *apiUsername = auth[@"apiUsername"];
    NSString *apiSecret = auth[@"apiSecret"];
    NSString *initUrl = endpoints[@"initMobileOneoffUrl"];
    
    if (!apiUsername || !apiSecret || !initUrl) {
        if (completion) {
            completion(nil,
                       [NSError errorWithDomain:@"ApplePay" code:400 userInfo:@{NSLocalizedDescriptionKey: @"Missing API credentials or init mobile oneoff URL"}]);
        }
        return;
    }
    
    NSURL *url = [NSURL URLWithString:initUrl];
    NSString *orderReference = payload[@"orderReference"];
    if (!orderReference) {
        NSString *uuid = [[NSUUID UUID] UUIDString];
        orderReference = [NSString stringWithFormat:@"payment-%@", uuid];
    }
    
    NSDictionary *body = @{
        @"api_username": apiUsername,
        @"account_name": payload[@"accountName"] ?: @"EUR3D1",
        @"amount": payload[@"amount"] ?: @"1.00",
        @"order_reference": orderReference,
        @"nonce": [[NSUUID UUID] UUIDString],
        @"timestamp": [self iso8601Timestamp],
        @"mobile_payment": @YES,
        @"customer_url": payload[@"customerUrl"] ?: @"https://example.com/callback",
        @"locale": payload[@"locale"] ?: @"en",
        @"customer_ip": payload[@"customerIp"] ?: @"127.0.0.1"
    };
    
    NSError *jsonError;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:body options:0 error:&jsonError];
    if (jsonError) {
        completion(nil, jsonError);
        return;
    }
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setHTTPMethod:@"POST"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    
    NSString *login = [NSString stringWithFormat:@"%@:%@",
                       apiUsername,
                       apiSecret];
    NSData *loginData = [login dataUsingEncoding:NSUTF8StringEncoding];
    NSString *base64Login = [loginData base64EncodedStringWithOptions:0];
    [request setValue:[NSString stringWithFormat:@"Basic %@",
                       base64Login] forHTTPHeaderField:@"Authorization"];
    [request setHTTPBody:jsonData];
    
    NSURLSessionDataTask *task = [[NSURLSession sharedSession]
                                  dataTaskWithRequest:request
                                  completionHandler:^(NSData *data,
                                                      NSURLResponse *response,
                                                      NSError *error) {
        if (error) {
            completion(nil, error);
            return;
        }
        
        NSError *parseError;
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&parseError];
        if (parseError) {
            completion(nil, parseError);
            return;
        }
        
        NSString *paymentLink = json[@"payment_link"];
        NSString *paymentReference = json[@"payment_reference"];
        NSString *merchantId = json[@"applepay_merchant_identifier"];
        NSString *currency = json[@"currency"];
        NSNumber *amount = json[@"initial_amount"];
        
        if (!paymentLink || !paymentReference || !merchantId || !currency || !amount) {
            completion(nil,
                       [NSError errorWithDomain:@"ApplePay" code:500 userInfo:@{NSLocalizedDescriptionKey: @"Missing one or more required fields in init response"}]);
            return;
        }
        
        NSDictionary *result = @{
            @"accountName": json[@"account_name"] ?: @"",
            @"orderReference": json[@"order_reference"] ?: @"",
            @"email": json[@"email"] ?: [NSNull null],
            @"customerIp": json[@"customer_ip"] ?: [NSNull null],
            @"customerUrl": json[@"customer_url"] ?: @"",
            @"paymentCreatedAt": json[@"payment_created_at"] ?: @"",
            @"initialAmount": json[@"initial_amount"] ?: @(0),
            @"standingAmount": json[@"standing_amount"] ?: @(0),
            @"paymentReference": json[@"payment_reference"] ?: @"",
            @"paymentLink": json[@"payment_link"] ?: @"",
            @"paymentMethods": json[@"payment_methods"] ?: @[],
            @"apiUsername": json[@"api_username"] ?: @"",
            @"warnings": json[@"warnings"] ?: @{},
            @"stan": json[@"stan"] ?: [NSNull null],
            @"fraudScore": json[@"fraud_score"] ?: [NSNull null],
            @"paymentState": json[@"payment_state"] ?: @"",
            @"paymentMethod": json[@"payment_method"] ?: [NSNull null],
            @"mobileAccessToken": json[@"mobile_access_token"] ?: @"",
            @"currency": json[@"currency"] ?: @"",
            @"applepayMerchantIdentifier": json[@"applepay_merchant_identifier"] ?: @"",
            @"descriptorCountry": json[@"descriptor_country"] ?: @"",
            @"googlepayMerchantIdentifier": json[@"googlepay_merchant_identifier"] ?: @""
        };
        RCTLogWarn(@"✅ Init succeeded with result: %@", result);
        completion(result, nil);
    }];
    [task resume];
}

- (NSString *)iso8601Timestamp {
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"yyyy-MM-dd'T'HH:mm:ss'Z'";
    formatter.timeZone = [NSTimeZone timeZoneWithAbbreviation:@"UTC"];
    return [formatter stringFromDate:[NSDate date]];
}

RCT_EXPORT_METHOD(initPayment:(NSDictionary *)config
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
    [self initPayment:config completion:^(NSDictionary *response,
                                          NSError *error) {
        if (error) {
            reject(@"init_failed", @"Init payment failed", error);
            return;
        }

        // Return the init payload as-is, which should match InitPaymentOutput
        resolve(@{
            @"success": @YES,
            @"resultData": response
        });
    }];
}

RCT_EXPORT_METHOD(initAndStartPayment:(NSDictionary *)config
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
    // Extract input sections
    NSDictionary *auth = config[@"auth"];
    NSDictionary *endpoints = config[@"endpoints"];
    NSDictionary *data = config[@"data"];
 
    // Step 1: Call init
    [self initPayment:config completion:^(NSDictionary *initResult,
                                          NSError *error) {
        if (error) {
            NSString *message = [NSString stringWithFormat:@"Init payment failed: %@",
                                 error.localizedDescription];
            reject(@"init_failed", message, error);
            return;
        }
        
        // Step 2: Compose input for startPayment
        NSDictionary *startPaymentPayload = @{
            @"endpoints": @{
                @"paymentSessionUrl": endpoints[@"paymentSessionUrl"] ?: @"",
                @"authorizePaymentUrl": endpoints[@"authorizePaymentUrl"] ?: @"",
                @"paymentDetailUrl": endpoints[@"paymentDetailUrl"] ?: @""
            },
            @"data": @{
                @"paymentReference": initResult[@"paymentReference"] ?: @"",
                @"paymentLink": initResult[@"paymentLink"] ?: @"",
                @"countryCode": data[@"countryCode"] ?: @"EE",
                @"currencyCode": initResult[@"currency"] ?: @"EUR",
                @"amount": data[@"amount"] ?: @"",
                @"label": data[@"label"] ?: @"Payment",
                @"merchantId": initResult[@"applepayMerchantIdentifier"] ?: @"",
                @"accessToken": initResult[@"mobileAccessToken"] ?: @""
            },
        };
        
        RCTLogInfo(@"Start payment with input: %@", startPaymentPayload);
        
        dispatch_async(dispatch_get_main_queue(),
 ^{
            @try {
                // Attempt to start the payment
                [self startPayment:startPaymentPayload];
                
                // Handle the successful response and resolve the promise
                resolve(@{
                    @"success": @YES,
                    @"status": @"started",
                    @"data": @{
                        @"paymentLink": initResult[@"paymentLink"] ?: @"",
                        // Fallback to empty string if nil
                        @"paymentReference": initResult[@"paymentReference"] ?: @"" // Fallback to empty string if nil
                    }
                });
            }
            @catch (NSException *exception) {
                // Catch any exceptions thrown and reject the promise with the error details
                NSError *error = [NSError errorWithDomain:@"ApplePayModule"
                                                     code:500
                                                 userInfo:@{
                    NSLocalizedDescriptionKey: exception.reason ?: @"Unknown error",
                    @"exception": exception
                }];
                
                // Reject the promise with the error details
                NSString *message = [NSString stringWithFormat:@"Failed to start payment: %@",
                                     error.localizedDescription];
                reject(@"start_payment_failed",
                       message,
                       error);
            }
            @finally {
                // You can add any cleanup logic here if needed
            }
        });
    }];
}

@end
