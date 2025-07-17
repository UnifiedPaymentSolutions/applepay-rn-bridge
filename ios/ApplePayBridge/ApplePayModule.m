#import "ApplePayModule.h"
#import "ApplePayNetworkService.h" // Import implementation details
#import "ApplePayPaymentContext.h" // Import implementation details
#import <React/RCTLog.h>
#import <React/RCTConvert.h>

// Error domains used by the module itself
static NSString * const ApplePayModuleErrorDomain = @"com.yourapp.ApplePayModule";
typedef NS_ENUM(NSInteger, ApplePayModuleErrorCode) {
    ApplePayModuleErrorPaymentInProgress = 1001,
    ApplePayModuleErrorInvalidConfig = 1002,
    ApplePayModuleErrorContextCreationFailed = 1003,
    ApplePayModuleErrorRequestCreationFailed = 1004,
    ApplePayModuleErrorPresentationFailed = 1005,
    ApplePayModuleErrorAuthorizationInternal = 1006,
    ApplePayModuleErrorTokenMissing = 1007,
    ApplePayModuleErrorTokenParse = 1008,
    ApplePayModuleErrorBackendRejected = 1009, // When backend returns success HTTP but logical failure
    ApplePayModuleErrorCancelled = 1010, // User cancelled or finished prematurely
    ApplePayModuleErrorLegacyDelegate = 1011,
    ApplePayModuleErrorMerchantIdFetchFailed = 1012,
};

@implementation ApplePayModule

@synthesize bridge = _bridge; // If you need access to the bridge

RCT_EXPORT_MODULE(ApplePayModule);

- (instancetype)init {
    self = [super init];
    if (self) {
        _networkService = [[ApplePayNetworkService alloc] init];
        RCTLogInfo(@"[ApplePayModule] Initialized with Network Service.");
    }
    return self;
}

+ (BOOL)requiresMainQueueSetup {
    return YES; // Important for UI-related setup like PKPaymentAuthorizationController
}

- (void)dealloc {
    RCTLogInfo(@"[ApplePayModule] Deallocating.");
    [self clearPaymentState];
    [self clearPromiseCallbacks]; // Ensure no dangling promises
}

//-------------------------------------------------------------------------------------------
#pragma mark - Helper Methods
//-------------------------------------------------------------------------------------------

/** Clears payment session, context, and resets the progress flag. */
- (void)clearPaymentState {
    RCTLogInfo(@"[ApplePayModule] Clearing payment state.");
    if (self.session) {
        self.session.delegate = nil; // Break potential cycle BEFORE nilling session
        // Dismiss if still somehow presented? Usually handled by didFinish.
        // dispatch_async(dispatch_get_main_queue(), ^{
        //    [self.session dismissWithCompletion:nil];
        // });
        self.session = nil;
    }
    self.paymentContext = nil; // Clear the stored payment data
    self.isPaymentInProgress = NO; // Crucial reset
}

/** Clears stored promise callbacks safely. */
- (void)clearPromiseCallbacks {
    if (self.currentResolve || self.currentReject) {
        RCTLogInfo(@"[ApplePayModule] Clearing promise callbacks.");
        self.currentResolve = nil;
        self.currentReject = nil;
    }
}

/** Resolves the current promise and clears callbacks. */
- (void)resolveWithSuccess:(NSDictionary *)data {
    if (self.currentResolve) {
        RCTLogInfo(@"[ApplePayModule] Resolving promise with success.");
        RCTPromiseResolveBlock resolveBlock = self.currentResolve;
        [self clearPromiseCallbacks]; // Clear *before* resolving
        resolveBlock(data);
    } else {
        RCTLogWarn(@"[ApplePayModule] Attempted to resolve but no currentResolve callback found (possibly already resolved/rejected).");
    }
}

/** Rejects the current promise and clears promise callbacks only. */
- (void)rejectWithCode:(NSString *)code message:(NSString *)message error:(nullable NSError *)error {
    if (self.currentReject) {
        RCTLogWarn(@"[ApplePayModule] Rejecting promise with code: %@, message: %@", code, message);
        RCTPromiseRejectBlock rejectBlock = self.currentReject;
        [self clearPromiseCallbacks]; // Clear callbacks ONLY, not payment state

        // Construct a more informative NSError if one wasn't provided
        NSError *rejectionError = error;
        if (!rejectionError) {
             rejectionError = [NSError errorWithDomain:ApplePayModuleErrorDomain
                                                  code:[self mapErrorCodeFromString:code]
                                              userInfo:@{NSLocalizedDescriptionKey: message}];
        }
        rejectBlock(code, message, rejectionError);
    } else {
        RCTLogWarn(@"[ApplePayModule] Attempted to reject but no currentReject callback found.");
    }
}

// Helper to map string codes to internal error enum (optional but can be useful)
- (ApplePayModuleErrorCode)mapErrorCodeFromString:(NSString *)codeString {
    if ([codeString isEqualToString:@"payment_in_progress"]) return ApplePayModuleErrorPaymentInProgress;
    if ([codeString isEqualToString:@"init_failed"]) return ApplePayModuleErrorContextCreationFailed; // Assuming init fail prevents context creation
    if ([codeString isEqualToString:@"invalid_context"]) return ApplePayModuleErrorContextCreationFailed;
    if ([codeString isEqualToString:@"link_data_error"]) return ApplePayModuleErrorRequestCreationFailed; // Or a specific network error code?
    if ([codeString isEqualToString:@"request_creation_failed"]) return ApplePayModuleErrorRequestCreationFailed;
    if ([codeString isEqualToString:@"presentation_failed"]) return ApplePayModuleErrorPresentationFailed;
    if ([codeString isEqualToString:@"token_error"]) return ApplePayModuleErrorTokenMissing;
    if ([codeString isEqualToString:@"token_parse_error"]) return ApplePayModuleErrorTokenParse;
    if ([codeString isEqualToString:@"authorization_failed"]) return ApplePayModuleErrorAuthorizationInternal; // Generic auth fail
    if ([codeString isEqualToString:@"backend_rejected"]) return ApplePayModuleErrorBackendRejected;
    if ([codeString isEqualToString:@"cancelled"]) return ApplePayModuleErrorCancelled;
    if ([codeString isEqualToString:@"legacy_delegate_error"]) return ApplePayModuleErrorLegacyDelegate;
    if ([codeString isEqualToString:@"merchant_id_fetch_failed"]) return ApplePayModuleErrorMerchantIdFetchFailed;
    // Add mappings for network service errors if needed
    return 0; // Default or unknown
}

//-------------------------------------------------------------------------------------------
#pragma mark - Exported Methods
//-------------------------------------------------------------------------------------------

RCT_EXPORT_METHOD(canMakePayments:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject) {
    // Define supported networks consistently
    // TODO: Potentially read networks from config or make dynamic?
    NSArray<PKPaymentNetwork> *supportedNetworks = @[PKPaymentNetworkVisa, PKPaymentNetworkMasterCard];
    BOOL canPay = [PKPaymentAuthorizationController canMakePaymentsUsingNetworks:supportedNetworks];
    resolve(@(canPay));
}


RCT_EXPORT_METHOD(initPayment:(NSDictionary *)config
                  resolve:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject) {
    RCTLogInfo(@"[ApplePayModule] initPayment called.");

    [self.networkService initializePaymentWithConfig:config completion:^(NSDictionary *initResult, NSError *networkError) {
        if (networkError || !initResult) {
            RCTLogError(@"[ApplePayModule] Init payment failed: %@", networkError.localizedDescription);
            NSString *errorMessage = [NSString stringWithFormat:@"Init payment failed: %@", networkError.localizedDescription ?: @"Unknown error"];
            // Reject the initPayment promise directly
            reject(@"init_failed", errorMessage, networkError);
        } else {
            RCTLogInfo(@"[ApplePayModule] Init payment successful.");

            // Construct the dictionary startApplePay expects
            NSMutableDictionary *paymentInitData = [NSMutableDictionary dictionary];

            // Required from initResult
            paymentInitData[@"accountName"] = initResult[@"account_name"];
            paymentInitData[@"apiUsername"] = initResult[@"api_username"];
            paymentInitData[@"paymentReference"] = initResult[@"payment_reference"];
            paymentInitData[@"orderReference"] = initResult[@"order_reference"];
            paymentInitData[@"mobileAccessToken"] = initResult[@"mobile_access_token"];
            paymentInitData[@"amount"] = initResult[@"standing_amount"];
            paymentInitData[@"currencyCode"] = initResult[@"currency"];
            paymentInitData[@"paymentState"] = initResult[@"payment_state"];

            // Optionally include the original full init response if needed later
            paymentInitData[@"originalInitResponse"] = initResult;


            // Validate that essential keys are present before resolving
            BOOL isValidData =
                // Required for basic payment identification
                paymentInitData[@"paymentReference"] != nil &&
                paymentInitData[@"mobileAccessToken"] != nil &&
                
                // Required for payment amount/details
                paymentInitData[@"amount"] != nil &&
                paymentInitData[@"currencyCode"] != nil &&
                
                // Required for API communication
                paymentInitData[@"accountName"] != nil &&
                paymentInitData[@"apiUsername"] != nil;
            
            if (isValidData) {
                RCTLogInfo(@"[ApplePayModule] Resolving initPayment promise with data.");
                resolve(paymentInitData); // Resolve with the prepared dictionary
            } else {
                NSMutableArray *missingFields = [NSMutableArray array];
                if (!paymentInitData[@"paymentReference"]) [missingFields addObject:@"paymentReference"];
                if (!paymentInitData[@"mobileAccessToken"]) [missingFields addObject:@"mobileAccessToken"];
                if (!paymentInitData[@"amount"]) [missingFields addObject:@"amount"];
                if (!paymentInitData[@"currencyCode"]) [missingFields addObject:@"currencyCode"];
                if (!paymentInitData[@"accountName"]) [missingFields addObject:@"accountName"];
                if (!paymentInitData[@"apiUsername"]) [missingFields addObject:@"apiUsername"];
                
                NSString *errorMessage = [NSString stringWithFormat:@"Invalid initialization data. Missing fields: %@",
                                         [missingFields componentsJoinedByString:@", "]];
                
                RCTLogError(@"[ApplePayModule'] Essential data missing after successful init. Cannot resolve initPayment.");
                // Log missing keys for debugging
                NSLog(@"Missing data in initPayment result construction: %@", paymentInitData);
                // Handle error
                reject(@"invalid_init_data", errorMessage, nil);
                return;
            }
        }
    }];
}


RCT_EXPORT_METHOD(startApplePay:(NSDictionary *)paymentInitData
                  resolve:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject) {
    RCTLogInfo(@"[ApplePayModule] startApplePay called.");
    
    // --- Concurrency Check for the UI Flow ---
    if (self.isPaymentInProgress) {
        RCTLogWarn(@"[ApplePayModule] Apple Pay UI flow already in progress. Rejecting new request.");
        NSError *error = [NSError errorWithDomain:ApplePayModuleErrorDomain code:ApplePayModuleErrorPaymentInProgress userInfo:@{NSLocalizedDescriptionKey: @"Another Apple Pay UI flow is already in progress."}];
        reject(@"payment_in_progress", @"Another Apple Pay UI flow is already in progress.", error);
        return;
    }
    
    // --- Store Callbacks and Set Flag for the UI Flow ---
    if (self.currentResolve || self.currentReject) {
        RCTLogWarn(@"[ApplePayModule] Overwriting existing startApplePay promise callbacks. Cleaning up previous UI state.");
        [self clearPromiseCallbacks];
        [self clearPaymentState];
    }
    self.currentResolve = resolve;
    self.currentReject = reject;
    self.isPaymentInProgress = YES; // Mark UI flow as started
    
    // --- Step 1: Create Payment Context from provided data ---
    self.paymentContext = [[ApplePayPaymentContext alloc] initWithPaymentInitData:paymentInitData];
    
    NSString *apiUsername = [RCTConvert NSString:[paymentInitData valueForKeyPath:@"auth.apiUsername"]];
    NSString *accountName = [RCTConvert NSString:[paymentInitData valueForKeyPath:@"data.accountName"]];
    NSString *paymentMethodsUrl = [RCTConvert NSString:[paymentInitData valueForKeyPath:@"endpoints.paymentMethodsUrl"]];
    
    [self.networkService fetchApplePayIdentifierForAccount:accountName
                                               apiUsername:apiUsername
                                                    amount:self.paymentContext.amount
                                         paymentMethodsURL:paymentMethodsUrl
                                                completion:^(BOOL success, NSString *applePayIdentifier, NSString *errorMessage) {
        // First, log everything we know about the request for debugging
        RCTLogInfo(@"[ApplePayModule] Network request details: account=%@, username=%@, amount=%@, URL=%@",
                   accountName, apiUsername, [self.paymentContext.amount stringValue], paymentMethodsUrl);
        
        if (success) {
            // Update context with the identifier
            [self.paymentContext updateWithApplePayMerchantIdentifier:applePayIdentifier];
            
            // NOW validate the context with complete data
            if (self.paymentContext && [self.paymentContext isContextValidForStartingPayment]) {
                // Only proceed with payment flow if context is valid
                [self proceedWithPaymentFlow];
            } else {
                // Guard against double rejection
                if (self.currentReject) {
                    RCTLogError(@"[ApplePayModule] Context validation failed after merchant ID update");
                    [self rejectWithCode:@"invalid_context"
                                 message:@"Failed to create valid payment context after merchant ID update"
                                   error:[NSError errorWithDomain:ApplePayModuleErrorDomain
                                                             code:ApplePayModuleErrorContextCreationFailed
                                                         userInfo:@{NSLocalizedDescriptionKey: @"Context validation failed"}]];
                }
            }
        }
        else {
            // Guard against double rejection
            if (self.currentReject) {
                RCTLogError(@"[ApplePayModule] Merchant ID fetch failed: %@", errorMessage);
                [self rejectWithCode:@"merchant_id_fetch_failed"
                             message:[NSString stringWithFormat:@"Failed to retrieve Apple Pay merchant identifier: %@", errorMessage]
                               error:[NSError errorWithDomain:ApplePayModuleErrorDomain
                                                         code:ApplePayModuleErrorMerchantIdFetchFailed
                                                     userInfo:@{NSLocalizedDescriptionKey: errorMessage ?: @"Unknown error"}]];
            }
        }
    }];
}

//-------------------------------------------------------------------------------------------
#pragma mark - Internal Payment Flow Logic
//-------------------------------------------------------------------------------------------

/** Fetches link data (if needed) and presents the Apple Pay sheet. Assumes self.paymentContext is valid. */
- (void)proceedWithPaymentFlow {
    RCTLogInfo(@"[ApplePayModule] Proceeding with payment flow (fetching link data).");

    if (!self.paymentContext) { /* ... handle internal error, reject, clear state ... */ return; }

    // --- Step 1: Get Link Data ---
    __weak typeof(self) weakSelf = self;
//    [self.networkService fetchLinkDataWithDetailURL:self.paymentContext.paymentDetailURL
//                                   paymentReference:self.paymentContext.paymentReference
//                                        accessToken:self.paymentContext.accessToken
//                                         completion:^(NSDictionary *linkData, NSError *networkError) {
//
    __strong typeof(weakSelf) strongSelf = weakSelf;
//         if (!strongSelf || !strongSelf.isPaymentInProgress) {  return; }
//
//         if (networkError || !linkData) {
//             RCTLogError(@"[ApplePayModule] Failed to get payment link data: %@", networkError.localizedDescription);
//             [strongSelf rejectWithCode:@"link_data_error" message:@"Failed to get payment link data." error:networkError];
//             // rejectWithCode handles state cleanup because isPaymentInProgress is true
//             return;
//         }
    RCTLogInfo(@"[ApplePayModule] Payment link data received.");
    PKPaymentRequest *paymentRequest = [strongSelf createPaymentRequestWithLinkData];

    if (!paymentRequest) {
         RCTLogError(@"[ApplePayModule] Failed to create PKPaymentRequest.");
         [strongSelf rejectWithCode:@"request_creation_failed" message:@"Failed to create Apple Pay request object." error:nil];
         return;
    }

    if (strongSelf.session) { /* ... clear old session ... */ }
    strongSelf.session = [[PKPaymentAuthorizationController alloc] initWithPaymentRequest:paymentRequest];
    if (!strongSelf.session) {
        /* ... handle controller init failure, reject ... */
        return;
    }

    strongSelf.session.delegate = strongSelf;
    RCTLogInfo(@"[ApplePayModule] Presenting Apple Pay sheet...");
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!strongSelf || !strongSelf.isPaymentInProgress) {
            /* ... check state before presenting ... */
            return;
        }
        [strongSelf.session presentWithCompletion:^(BOOL presented) {
            if (!strongSelf || !strongSelf.isPaymentInProgress) {
                /* ... check state after presentation attempt ... */ return;
            }
            if (!presented) {
                RCTLogError(@"[ApplePayModule] Failed to present Apple Pay sheet.");
                [strongSelf rejectWithCode:@"presentation_failed" message:@"Failed to present Apple Pay sheet." error:nil];
            } else {
                RCTLogInfo(@"[ApplePayModule] Apple Pay sheet presented successfully.");
            }
        }];
    });
    //    }];
}

/** Creates and configures the PKPaymentRequest using context and link data. */
- (nullable PKPaymentRequest *)createPaymentRequestWithLinkData {
    if (!self.paymentContext) {
        RCTLogError(@"[ApplePayModule] Cannot create payment request without valid context.");
        return nil;
    }

    PKPaymentRequest *request = [[PKPaymentRequest alloc] init];
    request.merchantIdentifier = self.paymentContext.merchantId;
    request.supportedNetworks = @[PKPaymentNetworkVisa, PKPaymentNetworkMasterCard]; // TODO: Make configurable?
    request.merchantCapabilities = PKMerchantCapability3DS; // TODO: Make configurable?
    request.countryCode = self.paymentContext.countryCode;
    request.currencyCode = self.paymentContext.currencyCode;

    // Ensure amount is valid before creating summary item
    if (!self.paymentContext.amount) {
         RCTLogError(@"[ApplePayModule] Cannot create payment request summary item: Amount is missing in context.");
         return nil;
    }
    request.paymentSummaryItems = @[
        [PKPaymentSummaryItem summaryItemWithLabel:self.paymentContext.paymentLabel
                                            amount:self.paymentContext.amount
                                              type:PKPaymentSummaryItemTypeFinal] // Use TypeFinal for one-off payments
    ];

    // Configure recurring payment if applicable
//    NSDictionary *shopAttributes = [RCTConvert NSDictionary:linkData[@"shop_attributes"]];
//    if (shopAttributes) {
//         [self configureRecurringPayment:request linkData:linkData amount:self.paymentContext.amount shopAttributes:shopAttributes];
//    } else {
//         RCTLogInfo(@"[ApplePayModule] No shop_attributes found in linkData, skipping recurring payment config.");
//    }
    return request;
}

/** Configures the payment request for recurring payments based on link data. */
- (void)configureRecurringPayment:(PKPaymentRequest *)paymentRequest
                         linkData:(NSDictionary *)linkData
                           amount:(NSDecimalNumber *)amount
                   shopAttributes:(NSDictionary *)shopAttributes {

    if (!linkData || !amount || !shopAttributes) {
        RCTLogInfo(@"[ApplePayModule] Skipping recurring payment config: Missing data.");
        return;
    }

    BOOL isArrangement = [RCTConvert BOOL:linkData[@"arrangement"]];
    BOOL tokenConsentAgreed = [RCTConvert BOOL:linkData[@"token_consent_agreed"]];
    NSString *descriptorName = [RCTConvert NSString:shopAttributes[@"descriptor_name"]];
    NSString *websiteAddress = [RCTConvert NSString:shopAttributes[@"website_address"]];

    if (!isArrangement || !tokenConsentAgreed || !descriptorName || descriptorName.length == 0 || !websiteAddress || websiteAddress.length == 0) {
        RCTLogInfo(@"[ApplePayModule] Not configuring as recurring (isArrangement=%@, tokenConsentAgreed=%@, descriptor=%@, website=%@).",
                   @(isArrangement), @(tokenConsentAgreed), descriptorName, websiteAddress);
        return;
    }

    if ([amount compare:NSDecimalNumber.zero] == NSOrderedAscending) {
        RCTLogWarn(@"[ApplePayModule] Recurring payment amount is negative (%@). Skipping configuration.", amount);
        return;
    }

    RCTLogInfo(@"[ApplePayModule] Configuring as recurring payment for '%@' with amount %@", descriptorName, amount);

    if (@available(iOS 16.0, *)) {
        PKRecurringPaymentSummaryItem *regularBilling = [PKRecurringPaymentSummaryItem summaryItemWithLabel:descriptorName amount:amount];


        NSURL *managementURL = [NSURL URLWithString:websiteAddress];
        if (managementURL) {
            paymentRequest.recurringPaymentRequest = [[PKRecurringPaymentRequest alloc]
                                                      initWithPaymentDescription:descriptorName
                                                      regularBilling:regularBilling
                                                      managementURL:managementURL];

            RCTLogInfo(@"[ApplePayModule] Configured using PKRecurringPaymentRequest (iOS 16+). Management URL: %@", managementURL);
        } else {
            RCTLogWarn(@"[ApplePayModule] Invalid management URL for recurring payment: %@", websiteAddress);
        }
    } else {
        // Fallback for older iOS: Modify summary items to imply saving the card.
        // This doesn't create a formal recurring request object.
        NSMutableArray<PKPaymentSummaryItem *> *summaryItems = [paymentRequest.paymentSummaryItems mutableCopy];
        NSString *saveCardLabel = [NSString stringWithFormat:@"Save card for future payments to %@", descriptorName];
        // Add a zero-amount item or use the actual amount - clarify desired UX. Using actual amount here.
        [summaryItems addObject:[PKPaymentSummaryItem summaryItemWithLabel:saveCardLabel amount:amount type:PKPaymentSummaryItemTypePending]]; // Use Pending or Final?
        paymentRequest.paymentSummaryItems = summaryItems;
        RCTLogInfo(@"[ApplePayModule] Added summary item to imply recurring payment (pre-iOS 16).");
    }
}


//-------------------------------------------------------------------------------------------
#pragma mark - PKPaymentAuthorizationControllerDelegate Methods
//-------------------------------------------------------------------------------------------

- (void)proceedWithAuthorization:(void (^ _Nonnull)(PKPaymentAuthorizationResult * _Nonnull))completion tokenDataDict:(NSDictionary *)tokenDataDict {
    __weak typeof(self) weakSelf = self;
    [self.networkService authorizePaymentWithTokenData:tokenDataDict
                                      paymentReference:self.paymentContext.paymentReference
                                          authorizeURL:self.paymentContext.authorizePaymentURL
                                           accessToken:self.paymentContext.accessToken
                                            completion:^(NSDictionary * _Nullable backendResponse, NSError * _Nullable networkError) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        // Check if the payment process is still active and module exists
        if (!strongSelf || !strongSelf.isPaymentInProgress) {
            RCTLogWarn(@"[ApplePayModule] Authorization response received, but payment no longer in progress or module deallocated.");
            // IMPORTANT: Do NOT call completion() or resolve/reject here. didFinish MUST handle the final state.
            // If we call completion() here and didFinish also tries to reject (e.g., due to cancellation), it can lead to issues.
            return;
        }
        
        PKPaymentAuthorizationStatus status = PKPaymentAuthorizationStatusFailure; // Default to failure
        NSDictionary *resolveData = nil;
        NSString *rejectCode = @"authorization_failed"; // Default reject code
        NSString *rejectMessage = @"Payment authorization failed."; // Default reject message
        NSError *rejectionError = networkError; // Use network error initially if present
        
        // --- Process Backend Response ---
        if (networkError) {
            // Network or HTTP error from the service
            RCTLogError(@"[ApplePayModule] Authorization network/HTTP error: %@", networkError.localizedDescription);
            rejectMessage = [NSString stringWithFormat:@"Authorization failed: %@", networkError.localizedDescription];
            // rejectionError is already set to networkError
        } else if (backendResponse) {
            // Received a response (HTTP 2xx presumed, as service layer handles HTTP errors)
            RCTLogInfo(@"[ApplePayModule] Received backend authorization response: %@", backendResponse);
            
            NSString *backendStatus = [RCTConvert NSString:backendResponse[@"state"]];
            BOOL backendSuccess = (backendStatus && ([backendStatus isEqualToString:@"completed"] || [backendStatus isEqualToString:@"authorized"] || [backendStatus isEqualToString:@"captured"]));
            
            if (backendSuccess) {
                RCTLogInfo(@"[ApplePayModule] Backend confirms successful authorization (status: %@).", backendStatus);
                status = PKPaymentAuthorizationStatusSuccess; // Set Apple Pay status to SUCCESS
                
                // Prepare data for RN promise resolve
                resolveData = @{
                    @"success": @YES,
                    @"paymentReference": strongSelf.paymentContext.paymentReference ?: [NSNull null],
                    @"response": backendResponse, // Include full backend response
                    @"initData": strongSelf.paymentContext.initializationResponse ?: @{} // Include original init data
                };
            } else {
                // Backend returned 2xx but indicated a logical failure
                RCTLogError(@"[ApplePayModule] Authorization failed: Backend reported failure in response (status: %@). Response: %@", backendStatus, backendResponse);
                status = PKPaymentAuthorizationStatusFailure; // Keep Apple Pay status as failure
                rejectCode = @"backend_rejected";
                rejectMessage = [NSString stringWithFormat:@"Payment rejected by backend (status: %@)", backendStatus ?: @"Unknown reason"];
                rejectionError = [NSError errorWithDomain:ApplePayModuleErrorDomain
                                                     code:ApplePayModuleErrorBackendRejected
                                                 userInfo:@{NSLocalizedDescriptionKey: rejectMessage,
                                                            @"responseBody": backendResponse}];
            }
        } else {
            // Should not happen if networkError is nil, but handle defensively
            RCTLogError(@"[ApplePayModule] Authorization completed with no error and no backend response.");
            status = PKPaymentAuthorizationStatusFailure;
            rejectMessage = @"Authorization failed: No response received from backend.";
            rejectionError = [NSError errorWithDomain:ApplePayModuleErrorDomain code:ApplePayModuleErrorAuthorizationInternal userInfo:@{NSLocalizedDescriptionKey: rejectMessage}];
        }
        
        // --- Step 4: Call Apple Pay Completion Handler (MUST be called ONCE) ---
        PKPaymentAuthorizationResult *authResult = [[PKPaymentAuthorizationResult alloc] initWithStatus:status errors:nil]; // TODO: Map backend errors to PKPaymentError if possible/useful
        completion(authResult);
        
        // --- Step 5: Resolve or Reject the React Native Promise ---
        if (status == PKPaymentAuthorizationStatusSuccess && resolveData) {
            [strongSelf resolveWithSuccess:resolveData];
        } else {
            // Use the reject details determined above
            [strongSelf rejectWithCode:rejectCode message:rejectMessage error:rejectionError];
        }
        // State cleanup (isPaymentInProgress=NO, context=nil) will happen in paymentAuthorizationControllerDidFinish
    }];
}

/** Delegate method called when the user authorizes the payment (iOS 11+). */
- (void)paymentAuthorizationController:(PKPaymentAuthorizationController *)controller
                   didAuthorizePayment:(PKPayment *)payment
                               handler:(void (^)(PKPaymentAuthorizationResult * _Nonnull result))completion API_AVAILABLE(ios(11.0), watchos(4.0)) {

    RCTLogInfo(@"[ApplePayModule] didAuthorizePayment:handler: called.");

     // TODO: --- MOCK PAYMENT (Remove or disable for production) ---
     BOOL shouldMockPayment = [self shouldUseMockPayment]; // <<<<<<< SET TO NO FOR REAL PAYMENTS
     if (shouldMockPayment) {
         RCTLogInfo(@"[ApplePayModule] --- USING MOCK PAYMENT AUTHORIZATION ---");
         dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ // Simulate delay
             PKPaymentAuthorizationResult *mockResult = [[PKPaymentAuthorizationResult alloc] initWithStatus:PKPaymentAuthorizationStatusSuccess errors:nil];
             completion(mockResult); // Call Apple Pay handler

             // Prepare mock data for RN promise
             NSDictionary *mockResponse = @{@"status": @"authorized", @"message": @"Mock payment authorized successfully"};
             NSMutableDictionary *finalResult = [NSMutableDictionary dictionary];
             finalResult[@"success"] = @YES;
             finalResult[@"paymentReference"] = self.paymentContext.paymentReference ?: [NSNull null];
             finalResult[@"response"] = mockResponse;
             if (self.paymentContext.initializationResponse) {
                 finalResult[@"initData"] = self.paymentContext.initializationResponse;
             }
             [self resolveWithSuccess:finalResult]; // Resolve RN promise
             // Cleanup will happen in didFinish
         });
         return;
     }
     // --- END MOCK PAYMENT ---


    // --- Step 1: Validate Context and Payment Token ---
    if (!self.paymentContext || !self.paymentContext.authorizePaymentURL || (self.paymentContext.everypayAlreadyInitialized && (!self.paymentContext.accessToken || !self.paymentContext.paymentReference))) {
        RCTLogError(@"[ApplePayModule] Authorization cannot proceed: Missing critical payment context.");
        completion([[PKPaymentAuthorizationResult alloc] initWithStatus:PKPaymentAuthorizationStatusFailure errors:nil]);
        [self rejectWithCode:@"internal_error" message:@"Internal state error during authorization." error:[NSError errorWithDomain:ApplePayModuleErrorDomain code:ApplePayModuleErrorAuthorizationInternal userInfo:@{NSLocalizedDescriptionKey:@"Payment context was missing or invalid during authorization."}]];
        // Cleanup should happen in didFinish
        return;
    }

    PKPaymentToken *token = payment.token;
    if (!token || !token.paymentData) {
        RCTLogError(@"[ApplePayModule] Payment token or token data is missing.");
        completion([[PKPaymentAuthorizationResult alloc] initWithStatus:PKPaymentAuthorizationStatusFailure errors:nil]);
        [self rejectWithCode:@"token_error" message:@"Payment token data is missing." error:[NSError errorWithDomain:ApplePayModuleErrorDomain code:ApplePayModuleErrorTokenMissing userInfo:@{NSLocalizedDescriptionKey:@"PKPaymentToken or its paymentData was nil."}]];
        return;
    }

    // --- Step 2: Parse Apple Pay Token Data ---
    NSError *jsonError;
    id tokenDataObj = [NSJSONSerialization JSONObjectWithData:token.paymentData options:0 error:&jsonError];

    if (jsonError || !tokenDataObj || ![tokenDataObj isKindOfClass:[NSDictionary class]]) {
        RCTLogError(@"[ApplePayModule] Failed to parse Apple Pay token's paymentData JSON: %@", jsonError);
        NSString *tokenDataStr = [[NSString alloc] initWithData:token.paymentData encoding:NSUTF8StringEncoding] ?: @"<Invalid Encoding>";
        completion([[PKPaymentAuthorizationResult alloc] initWithStatus:PKPaymentAuthorizationStatusFailure errors:nil]);

        NSDictionary *userInfo = @{NSLocalizedDescriptionKey: @"Failed to parse Apple Pay token data.",
                                   @"rawData": tokenDataStr,
                                   NSUnderlyingErrorKey: jsonError ?: [NSNull null]};
        [self rejectWithCode:@"token_parse_error" message:@"Failed to parse Apple Pay token data." error:[NSError errorWithDomain:ApplePayModuleErrorDomain code:ApplePayModuleErrorTokenParse userInfo:userInfo]];
        return;
    }
    NSDictionary *tokenDataDict = (NSDictionary *)tokenDataObj;

    // --- Step 3: Handle EveryPay Integration ---
    if (!self.paymentContext.everypayAlreadyInitialized) {
        RCTLogInfo(@"[ApplePayModule] Performing late EveryPay initialization");
        
        // Create configuration for late initialization
        NSDictionary *lateInitConfig = @{
            @"auth": @{
                @"apiUsername": self.paymentContext.apiUsername,
                @"apiSecret": self.paymentContext.apiSecret
            },
            @"endpoints": @{
                @"mobileOneoffUrl": self.paymentContext.mobileOneoffUrl.absoluteString
            },
            @"data": @{
                @"amount": self.paymentContext.amount,
                @"accountName": self.paymentContext.accountName,
                @"locale": self.paymentContext.locale ?: @"en",
                @"orderReference": self.paymentContext.orderReference ?: @""
                // Include any other required data
            }
        };
        
        // We need to initialize EveryPay now, before proceeding
        __weak typeof(self) weakSelf = self;
        [self.networkService initializePaymentWithConfig:lateInitConfig
                                              completion:^(NSDictionary *initResult, NSError *networkError) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;
            
            if (networkError || !initResult) {
                RCTLogError(@"[ApplePayModule] Late EveryPay initialization failed: %@",
                            networkError.localizedDescription);
                completion([[PKPaymentAuthorizationResult alloc]
                            initWithStatus:PKPaymentAuthorizationStatusFailure errors:nil]);
                [strongSelf rejectWithCode:@"late_init_failed"
                                  message:@"Payment initialization failed during checkout"
                                    error:networkError];
                return;
            }
            
            // Update payment context with the new information
            NSString *paymentReference = initResult[@"payment_reference"];
            if (!paymentReference) {
                RCTLogError(@"[ApplePayModule] Late init succeeded but missing payment reference");
                completion([[PKPaymentAuthorizationResult alloc]
                            initWithStatus:PKPaymentAuthorizationStatusFailure errors:nil]);
                [strongSelf rejectWithCode:@"invalid_init_data"
                                  message:@"Invalid initialization data received"
                                    error:nil];
                return;
            }
            
            // Update our context with the new payment reference
            [strongSelf.paymentContext updateWithLateInitResult:initResult];
            
            RCTLogInfo(@"[ApplePayModule] Late EveryPay initialization successful, reference: %@",
                      paymentReference);
            [self proceedWithAuthorization:completion tokenDataDict:tokenDataDict];
        }];
        
        return; // Return here as we're handling completion in the callbacks
    }

    // If we reach here, we already have a valid payment reference
    RCTLogInfo(@"[ApplePayModule] Using existing payment reference for EveryPay: %@",
              self.paymentContext.paymentReference);
    // --- Step 4: Send Token to Backend via Network Service ---
    [self proceedWithAuthorization:completion tokenDataDict:tokenDataDict];
}


/** Delegate method called when the payment authorization process finishes (iOS 8+). Called AFTER the didAuthorizePayment handler completes OR on cancellation. CRITICAL for cleanup. */
- (void)paymentAuthorizationControllerDidFinish:(PKPaymentAuthorizationController *)controller {
    RCTLogInfo(@"[ApplePayModule] paymentAuthorizationControllerDidFinish called.");

    // --- Step 1: Dismiss the Apple Pay Sheet ---
    // Ensure dismissal happens on the main thread.
    dispatch_async(dispatch_get_main_queue(), ^{
        [controller dismissWithCompletion:^{
            RCTLogInfo(@"[ApplePayModule] Apple Pay sheet dismissed via didFinish.");
        }];
    });

    // --- Step 2: Check if Promise is Still Pending (Indicates Cancellation or Pre-Auth Error) ---
    // If `didAuthorizePayment` successfully resolved or rejected, `currentResolve`/`currentReject` should be nil here.
    // If they are NOT nil, it means the flow finished *before* authorization completed (e.g., user cancelled).
    if (self.currentReject) { // Check reject first
        RCTLogWarn(@"[ApplePayModule] Payment finished, but promise was still pending. Assuming cancellation or pre-authorization error.");
        // Reject the promise indicating cancellation.
        NSError *cancelError = [NSError errorWithDomain:NSCocoaErrorDomain // Standard domain for user cancellation
                                                   code:NSUserCancelledError
                                               userInfo:@{NSLocalizedDescriptionKey: @"Payment was cancelled by the user or finished prematurely."}];
        // Use a specific code for cancellation initiated via the sheet
        [self rejectWithCode:@"cancelled" message:@"Payment cancelled or finished prematurely." error:cancelError];
        // Note: rejectWithCode already calls clearPromiseCallbacks
    } else if (self.currentResolve) {
        // This is less likely if resolve/reject logic is correct, but possible if called very close to finishing.
        RCTLogWarn(@"[ApplePayModule] Payment finished, promise was resolved but cleanup is happening now. Ensuring callbacks cleared.");
        [self clearPromiseCallbacks]; // Ensure cleared
    }

    // --- Step 3: Perform Final State Cleanup ---
    // This MUST be called regardless of whether the promise was resolved, rejected, or cancelled here.
    // It resets isPaymentInProgress and nils the context/session.
    [self clearPaymentState];

    // Double-check promise callbacks are cleared (should be redundant, but safe)
    [self clearPromiseCallbacks];

    RCTLogInfo(@"[ApplePayModule] Finished cleanup in didFinish.");
}


/** Older delegate method for iOS < 11. Included for completeness but ideally not used. */
- (void)paymentAuthorizationController:(PKPaymentAuthorizationController *)controller
                   didAuthorizePayment:(PKPayment *)payment
                            completion:(void (^)(PKPaymentAuthorizationStatus status))completion API_DEPRECATED("Use paymentAuthorizationController:didAuthorizePayment:handler: instead", ios(8.0, 11.0), watchos(1.0, 4.0)) {

    RCTLogWarn(@"[ApplePayModule] WARNING: Deprecated didAuthorizePayment:completion: (iOS 8-10) delegate called. Payment will be marked as failed.");

    // Immediately fail the payment for this deprecated path.
    completion(PKPaymentAuthorizationStatusFailure);

    // Reject the RN Promise with a clear error message.
    NSError *legacyError = [NSError errorWithDomain:ApplePayModuleErrorDomain
                                               code:ApplePayModuleErrorLegacyDelegate
                                           userInfo:@{NSLocalizedDescriptionKey: @"Payment authorization used a deprecated iOS delegate method. Operation aborted."}];
    [self rejectWithCode:@"legacy_delegate_error"
                 message:@"Payment flow used deprecated delegate method. Authorization not performed."
                   error:legacyError];

    // Cleanup should still happen in paymentAuthorizationControllerDidFinish
}

- (BOOL)shouldUseMockPayment {
    #ifdef DEBUG
        return [[NSUserDefaults standardUserDefaults] boolForKey:@"EP_MOCK_PAYMENTS_ENABLED"];
    #else
        return NO;
    #endif
}

RCT_EXPORT_METHOD(setMockPaymentsEnabled:(BOOL)enabled
                  resolve:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject) {
    #ifdef DEBUG
        [[NSUserDefaults standardUserDefaults] setBool:enabled forKey:@"EP_MOCK_PAYMENTS_ENABLED"];
        [[NSUserDefaults standardUserDefaults] synchronize];
        resolve(@{@"success": @YES});
    #else
        resolve(@{@"success": @NO, @"reason": @"Mock payments can only be enabled in debug builds"});
    #endif
}

@end
