#import "ApplePayPaymentContext.h"
#import <React/RCTConvert.h> // For safe dictionary data extraction

@implementation ApplePayPaymentContext

- (void)updateWithApplePayMerchantIdentifier:(NSString *)merchantId {
    // Use direct ivar access to bypass readonly property
    _merchantId = [merchantId copy];
}

- (void)updateWithLateInitResult:(NSDictionary *)initResult {
    // Update the payment reference
    _paymentReference = initResult[@"payment_reference"];
    
    // Set the flag to indicate we now have the reference
    _everypayAlreadyInitialized = (_paymentReference != nil && _paymentReference.length > 0);
    
    // Update any other necessary properties based on init result
    _accessToken = initResult[@"mobile_access_token"] ?: _accessToken;
    // Update other properties as needed...
}

- (nullable instancetype)initWithPaymentInitData:(NSDictionary *)paymentInitData {
    self = [super init];
    if (self) {
        // Extract nested dictionaries from the request structure
        NSDictionary *auth = [RCTConvert NSDictionary:paymentInitData[@"auth"]];
        NSDictionary *endpoints = [RCTConvert NSDictionary:paymentInitData[@"endpoints"]];
        NSDictionary *data = [RCTConvert NSDictionary:paymentInitData[@"data"]];
        
        if (!auth || !endpoints || !data) {
            NSLog(@"[ApplePayPaymentContext] ERROR: Missing required sections in payment request");
            return nil;
        }
        _paymentReference = [RCTConvert NSString:data[@"paymentReference"]];
        _accessToken = [RCTConvert NSString:data[@"mobileAccessToken"]];
        _everypayAlreadyInitialized = (_paymentReference != nil && _paymentReference.length > 0);
        
        if (_everypayAlreadyInitialized) {
            NSLog(@"[ApplePayPaymentContext] Payment reference found, EveryPay initialization is available");
        } else {
            NSLog(@"[ApplePayPaymentContext] No payment reference found, late EveryPay initialization will be needed");
        }
        _orderReference = [RCTConvert NSString:data[@"orderReference"]];
        _apiUsername = [RCTConvert NSString:auth[@"apiUsername"]];
        _apiSecret = [RCTConvert NSString:auth[@"apiSecret"]];
        _accountName = [RCTConvert NSString:data[@"accountName"]];
        _locale = [RCTConvert NSString:data[@"locale"]] ?: @"en";
        
        _accessToken = [RCTConvert NSString:data[@"mobileAccessToken"]]; // Key might differ
        _currencyCode = [RCTConvert NSString:data[@"currency"]] ?: @"EUR";

        _countryCode = [RCTConvert NSString:data[@"countryCode"]] ?: @"EE";
        _paymentLabel = [RCTConvert NSString:data[@"label"]] ?: @"Total";

        // Handle amount carefully
        // Amount might be Number or String from JS/backend. Convert robustly.
        id amountValue = data[@"amount"];
        NSNumber *amountNumber = nil;
        if ([amountValue isKindOfClass:[NSString class]]) {
             // Try converting string to number if needed, depends on backend format
             // Using NSDecimalNumber directly is often safer for currency strings
             NSDecimalNumber *decAmount = [NSDecimalNumber decimalNumberWithString:(NSString *)amountValue
                                                                           locale:[NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"]]; // Use POSIX for '.' decimal sep
              if (![decAmount isEqualToNumber:NSDecimalNumber.notANumber]) {
                  _amount = decAmount;
              }
        } else {
            amountNumber = [RCTConvert NSNumber:amountValue];
             if (amountNumber != nil) {
                 NSDecimalNumber *decimalAmount = [NSDecimalNumber decimalNumberWithDecimal:[amountNumber decimalValue]];
                 if (![decimalAmount isEqualToNumber:NSDecimalNumber.notANumber]) {
                     _amount = decimalAmount;
                 }
             }
        }

        NSString *mobileOneoffUrl = [RCTConvert NSString:endpoints[@"mobileOneoffUrl"]];
        if (mobileOneoffUrl) _mobileOneoffUrl = [NSURL URLWithString:mobileOneoffUrl];

        NSString *authUrlString = [RCTConvert NSString:endpoints[@"authorizePaymentUrl"]];
        if (authUrlString) _authorizePaymentURL = [NSURL URLWithString:authUrlString];
        
        // Optional fields
        NSString *sessionUrlString = [RCTConvert NSString:endpoints[@"paymentSessionUrl"]];
        if (sessionUrlString) _paymentSessionURL = [NSURL URLWithString:sessionUrlString];
        
        _initializationResponse = [RCTConvert NSDictionary:paymentInitData[@"originalInitResponse"]]; // If passed

        // --- Validation ---
        if (![self isContextValidForStartingPayment]) {
             NSLog(@"[ApplePayPaymentContext] ERROR: Context initialized with invalid or missing essential data from paymentInitData.");
            // Log the received data for debugging
            NSLog(@"[ApplePayPaymentContext] Received Data: %@", paymentInitData);
            // Return nil or allow creation but check validity later? Returning self for now.
        } else {
             NSLog(@"[ApplePayPaymentContext] Context initialized successfully from paymentInitData for reference: %@", _paymentReference);
        }
    }
    return self;
}

- (BOOL)isContextValidForStartingPayment {
    NSMutableArray *missingFields = [NSMutableArray array];
    
    // Check common required fields
    if (!_merchantId || _merchantId.length == 0) [missingFields addObject:@"merchantId"];
    if (!_apiUsername || _apiUsername.length == 0) [missingFields addObject:@"apiUsername"]; // Fixed typo here
    if (!_currencyCode || _currencyCode.length == 0) [missingFields addObject:@"currencyCode"];
    if (!_countryCode || _countryCode.length == 0) [missingFields addObject:@"countryCode"];
    if (!_paymentLabel || _paymentLabel.length == 0) [missingFields addObject:@"paymentLabel"];
    if (!_amount) [missingFields addObject:@"amount"];
    if (!_authorizePaymentURL) [missingFields addObject:@"authorizePaymentURL"];
    
    // Check fields specific to EveryPay initialization state
    if (_everypayAlreadyInitialized) {
        if (!_accessToken || _accessToken.length == 0) [missingFields addObject:@"accessToken"];
        if (!_paymentReference || _paymentReference.length == 0) [missingFields addObject:@"paymentReference"];
    } else {
        if (!_apiSecret || _apiSecret.length == 0) [missingFields addObject:@"apiSecret"];
        if (!_accountName || _accountName.length == 0) [missingFields addObject:@"accountName"];
        if (!_locale || _locale.length == 0) [missingFields addObject:@"locale"];
        if (!_mobileOneoffUrl) [missingFields addObject:@"mobileOneoffUrl"]; // Added this check
    }
    
    // Log specific missing fields if validation failed
    if (missingFields.count > 0) {
        NSLog(@"[ApplePayPaymentContext] Context validation failed - Missing or invalid fields: %@",
              [missingFields componentsJoinedByString:@", "]);
        
        // Optional: Log the values we do have for debugging
        NSLog(@"[ApplePayPaymentContext] Current values - Ref:%@ MerchID:%@ TokenOK:%@ Currency:%@ Country:%@ Label:%@ Amount:%@ AuthURLOK:%@ DetailURLOK:%@",
              _paymentReference ?: @"<nil>",
              _merchantId ?: @"<nil>",
              _accessToken ? @"YES" : @"NO",
              _currencyCode ?: @"<nil>",
              _countryCode ?: @"<nil>",
              _paymentLabel ?: @"<nil>",
              _amount ?: @"<nil>",
              _authorizePaymentURL ? @"YES" : @"NO",
              _paymentDetailURL ? @"YES" : @"NO");
    }
    
    return (missingFields.count == 0);
}

@end
