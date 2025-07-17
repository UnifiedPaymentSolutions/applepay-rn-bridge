#import "ApplePayNetworkService.h"
#import <React/RCTConvert.h> // Still useful for parsing config data safely

// Error Domain for errors originating from this service
static NSString * const ApplePayNetworkErrorDomain = @"com.yourapp.ApplePayNetworkService";

typedef NS_ENUM(NSInteger, ApplePayNetworkErrorCode) {
    ApplePayNetworkErrorInvalidInput = 400,
    ApplePayNetworkErrorAuthFailed = 401,
    ApplePayNetworkErrorServerError = 500,
    ApplePayNetworkErrorBadResponse = 502, // Like invalid JSON or unexpected format
    ApplePayNetworkErrorRequestSerialization = 503,
    ApplePayNetworkErrorMissingConfiguration = 504,
};


@implementation ApplePayNetworkService

// Shared Date Formatter for ISO8601 Timestamps
- (NSDateFormatter *)iso8601Formatter {
    static NSDateFormatter *formatter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [[NSDateFormatter alloc] init];
        formatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
        formatter.dateFormat = @"yyyy-MM-dd'T'HH:mm:ss'Z'";
        formatter.timeZone = [NSTimeZone timeZoneWithAbbreviation:@"UTC"];
    });
    return formatter;
}

- (NSString *)iso8601Timestamp {
    NSDateFormatter *formatter = [self iso8601Formatter];
    @synchronized(formatter) { // Ensure thread safety
        return [formatter stringFromDate:[NSDate date]];
    }
}

// Shared Amount Formatter
- (NSNumberFormatter *)amountFormatter {
    static NSNumberFormatter *formatter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [[NSNumberFormatter alloc] init];
        formatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"]; // Ensure '.' decimal separator
        formatter.numberStyle = NSNumberFormatterDecimalStyle;
        formatter.minimumFractionDigits = 2;
        formatter.maximumFractionDigits = 2;
        formatter.usesGroupingSeparator = NO; // No thousands separator
    });
    return formatter;
}


- (void)initializePaymentWithConfig:(NSDictionary *)config
                         completion:(void (^)(NSDictionary * _Nullable response, NSError * _Nullable error))completion {
    
    NSDictionary *auth = config[@"auth"];
    NSDictionary *endpoints = config[@"endpoints"];
    NSDictionary *payload = config[@"data"];
    
    // --- Input Validation ---
    if (!auth || ![auth isKindOfClass:[NSDictionary class]] ||
        !endpoints || ![endpoints isKindOfClass:[NSDictionary class]] ||
        !payload || ![payload isKindOfClass:[NSDictionary class]]) {
        NSError *error = [NSError errorWithDomain:ApplePayNetworkErrorDomain
                                             code:ApplePayNetworkErrorMissingConfiguration
                                         userInfo:@{NSLocalizedDescriptionKey: @"Missing required sections in config: auth, endpoints, or data"}];
        completion(nil, error);
        return;
    }
    
    NSLog(@"[ApplePayModule] Auth dictionary: %@", auth);
    NSLog(@"[ApplePayModule] Endpoints dictionary: %@", endpoints);
    NSLog(@"[ApplePayModule] Payload (data) dictionary: %@", payload);
    
    NSString *apiUsername = [RCTConvert NSString:auth[@"apiUsername"]];
    NSString *apiSecret = [RCTConvert NSString:auth[@"apiSecret"]];
    NSString *initUrlString = [RCTConvert NSString:endpoints[@"mobileOneoffUrl"]];
    
    if (!apiUsername || apiUsername.length == 0) {
        NSError *error = [NSError errorWithDomain:ApplePayNetworkErrorDomain
                                             code:ApplePayNetworkErrorMissingConfiguration
                                         userInfo:@{NSLocalizedDescriptionKey: @"Missing API username in config"}];
        completion(nil, error);
        return;
    }

    if (!apiSecret || apiSecret.length == 0) {
        NSError *error = [NSError errorWithDomain:ApplePayNetworkErrorDomain
                                             code:ApplePayNetworkErrorMissingConfiguration
                                         userInfo:@{NSLocalizedDescriptionKey: @"Missing API secret in config"}];
        completion(nil, error);
        return;
    }

    if (!initUrlString || initUrlString.length == 0) {
        NSError *error = [NSError errorWithDomain:ApplePayNetworkErrorDomain
                                             code:ApplePayNetworkErrorMissingConfiguration
                                         userInfo:@{NSLocalizedDescriptionKey: @"Missing mobile oneoff URL in config"}];
        completion(nil, error);
        return;
    }
    
    NSURL *url = [NSURL URLWithString:initUrlString];
    if (!url) {
        NSError *error = [NSError errorWithDomain:ApplePayNetworkErrorDomain
                                             code:ApplePayNetworkErrorInvalidInput
                                         userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Invalid init URL string: %@", initUrlString]}];
        completion(nil, error);
        return;
    }
    
    // --- Prepare Request Body ---
    NSString *orderReference = [RCTConvert NSString:payload[@"orderReference"]];
    if (!orderReference || orderReference.length == 0) {
        orderReference = [NSString stringWithFormat:@"ios-payment-%@", [[NSUUID UUID] UUIDString]];
    }
    NSString *customerIp = @""; // Include if available
    
    NSNumber *amountNumber = [RCTConvert NSNumber:payload[@"amount"]];
    if (!amountNumber) {
        NSError *error = [NSError errorWithDomain:ApplePayNetworkErrorDomain
                                             code:ApplePayNetworkErrorInvalidInput
                                         userInfo:@{NSLocalizedDescriptionKey: @"Missing payment amount in data payload"}];
        completion(nil, error);
        return;
    }
    
    NSString *amountString = nil;
    NSNumberFormatter *formatter = [self amountFormatter];
    @synchronized(formatter) {
        amountString = [formatter stringFromNumber:amountNumber];
    }
    
    if (!amountString || amountString.length == 0) {
        NSError *error = [NSError errorWithDomain:ApplePayNetworkErrorDomain
                                             code:ApplePayNetworkErrorInvalidInput
                                         userInfo:@{NSLocalizedDescriptionKey: @"Failed to format payment amount", @"originalAmount": amountNumber}];
        completion(nil, error);
        return;
    }
    
    NSMutableDictionary *body = [NSMutableDictionary dictionaryWithDictionary:@{
        @"api_username": apiUsername,
        @"account_name": [RCTConvert NSString:payload[@"accountName"]] ?: @"EUR3D1",
        @"amount": amountString,
        @"order_reference": orderReference,
        @"nonce": [[NSUUID UUID] UUIDString],
        @"timestamp": [self iso8601Timestamp],
        @"mobile_payment": @YES,
        @"customer_url": [RCTConvert NSString:payload[@"customerUrl"]] ?: @"https://example.com/mobile/callback",
        @"locale": [RCTConvert NSString:payload[@"locale"]] ?: @"en",
        @"customer_ip": customerIp
    }];
    
    NSString *customerEmail = [RCTConvert NSString:payload[@"customerEmail"]];
    if (customerEmail) body[@"customer_email"] = customerEmail;
    // Add other optional fields...
    
    NSError *jsonError;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:body options:0 error:&jsonError];
    if (jsonError) {
        NSLog(@"[ApplePayNetworkService] Failed to serialize init request body: %@", jsonError);
        NSError *error = [NSError errorWithDomain:ApplePayNetworkErrorDomain
                                             code:ApplePayNetworkErrorRequestSerialization
                                         userInfo:@{NSLocalizedDescriptionKey: @"Failed to serialize init request body.", NSUnderlyingErrorKey: jsonError}];
        completion(nil, error);
        return;
    }
    
    // --- Prepare Request ---
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:30.0];
    [request setHTTPMethod:@"POST"];
    [request setValue:@"application/json; charset=utf-8" forHTTPHeaderField:@"Content-Type"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    [request setHTTPBody:jsonData];
    
    // Basic Authentication
    NSString *loginString = [NSString stringWithFormat:@"%@:%@", apiUsername, apiSecret];
    NSData *loginData = [loginString dataUsingEncoding:NSUTF8StringEncoding];
    if (loginData) {
        NSString *base64LoginString = [loginData base64EncodedStringWithOptions:0];
        [request setValue:[NSString stringWithFormat:@"Basic %@", base64LoginString] forHTTPHeaderField:@"Authorization"];
    } else {
        NSLog(@"[ApplePayNetworkService] Failed to encode basic auth credentials.");
        NSError *error = [NSError errorWithDomain:ApplePayNetworkErrorDomain
                                             code:ApplePayNetworkErrorAuthFailed
                                         userInfo:@{NSLocalizedDescriptionKey: @"Failed to encode credentials for Basic Authentication."}];
        completion(nil, error);
        return;
    }
    
    // --- Send Request ---
    NSURLSessionConfiguration *sessionConfig = [NSURLSessionConfiguration defaultSessionConfiguration];
    NSURLSession *session = [NSURLSession sessionWithConfiguration:sessionConfig];
    
    NSLog(@"[ApplePayNetworkService] Sending init request to: %@ with body: %@", url, [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding] ?: @"<invalid body>");
    
    NSURLSessionDataTask *task = [session dataTaskWithRequest:request
                                            completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        // Network Error (e.g., connection refused, timeout)
        if (error) {
            NSLog(@"[ApplePayNetworkService] Network error during init: %@", error.localizedDescription);
            // Pass the original network error back
            completion(nil, error);
            return;
        }
        
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
        NSString *responseBodyStr = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] ?: @"";
        NSLog(@"[ApplePayNetworkService] Init response status code: %ld", (long)httpResponse.statusCode);
        
        // HTTP Error Status
        if (httpResponse.statusCode < 200 || httpResponse.statusCode >= 300) {
            NSLog(@"[ApplePayNetworkService] HTTP error during init: %ld Body: %@", (long)httpResponse.statusCode, responseBodyStr);
            NSDictionary *userInfo = @{
                NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Init failed with HTTP status %ld.", (long)httpResponse.statusCode],
                @"statusCode": @(httpResponse.statusCode),
                @"responseBody": responseBodyStr
            };
            NSError *httpError = [NSError errorWithDomain:NSURLErrorDomain // Use standard domain for HTTP errors
                                                     code:httpResponse.statusCode // Use HTTP status as code
                                                 userInfo:userInfo];
            completion(nil, httpError);
            return;
        }
        
        // Check for empty data
        if (!data || data.length == 0) {
            NSLog(@"[ApplePayNetworkService] No data received from init despite HTTP success.");
            NSError *emptyDataError = [NSError errorWithDomain:ApplePayNetworkErrorDomain
                                                          code:ApplePayNetworkErrorBadResponse
                                                      userInfo:@{NSLocalizedDescriptionKey: @"No data received from init endpoint."}];
            completion(nil, emptyDataError);
            return;
        }
        
        // Parse JSON Response
        NSError *parseError;
        id jsonObject = [NSJSONSerialization JSONObjectWithData:data options:0 error:&parseError];
        
        if (parseError) {
            NSLog(@"[ApplePayNetworkService] Invalid JSON received from init: %@ Raw Data: %@", parseError.localizedDescription, responseBodyStr);
            NSDictionary *userInfo = @{
                NSLocalizedDescriptionKey: @"Invalid JSON response from init.",
                NSUnderlyingErrorKey: parseError,
                @"rawData": responseBodyStr
            };
            NSError *jsonParseError = [NSError errorWithDomain:NSCocoaErrorDomain // Standard domain for JSON errors
                                                          code:NSPropertyListReadCorruptError // Appropriate code
                                                      userInfo:userInfo];
            completion(nil, jsonParseError);
            return;
        }
        
        if (![jsonObject isKindOfClass:[NSDictionary class]]) {
            NSLog(@"[ApplePayNetworkService] Init JSON response is not a dictionary: %@", jsonObject);
            NSDictionary *userInfo = @{
                NSLocalizedDescriptionKey: @"Init JSON response is not a dictionary.",
                @"rawData": responseBodyStr
            };
            NSError *formatError = [NSError errorWithDomain:ApplePayNetworkErrorDomain
                                                       code:ApplePayNetworkErrorBadResponse
                                                   userInfo:userInfo];
            completion(nil, formatError);
            return;
        }
        NSDictionary *jsonDict = (NSDictionary *)jsonObject;
        
        // Validate required fields in the response (adjust as per your API contract)
        if (!jsonDict[@"payment_reference"] || !jsonDict[@"mobile_access_token"] || !jsonDict[@"applepay_merchant_identifier"]) {
            NSLog(@"[ApplePayNetworkService] Missing required fields in init response: payment_reference, mobile_access_token, or applepay_merchant_identifier. Response: %@", jsonDict);
            NSDictionary *userInfo = @{
                NSLocalizedDescriptionKey: @"Missing required fields in init response.",
                @"responseBody": jsonDict
            };
            NSError *backendError = [NSError errorWithDomain:ApplePayNetworkErrorDomain
                                                        code:ApplePayNetworkErrorBadResponse // Or ServerError?
                                                    userInfo:userInfo];
            completion(nil, backendError);
            return;
        }
        
        NSLog(@"[ApplePayNetworkService] Init request successful.");
        completion(jsonDict, nil); // Success
    }];
    [task resume];
}


- (void)fetchLinkDataWithDetailURL:(NSURL *)detailURL
                  paymentReference:(NSString *)paymentReference
                       accessToken:(NSString *)accessToken
                        completion:(void (^)(NSDictionary * _Nullable linkData, NSError * _Nullable error))completion {
    
    // --- Input Validation ---
    if (!detailURL || !paymentReference || !accessToken) {
        NSError *error = [NSError errorWithDomain:ApplePayNetworkErrorDomain
                                             code:ApplePayNetworkErrorInvalidInput
                                         userInfo:@{NSLocalizedDescriptionKey: @"Missing required parameters for fetchLinkData."}];
        completion(nil, error);
        return;
    }
    
    NSURLComponents *urlComponents = [NSURLComponents componentsWithURL:detailURL resolvingAgainstBaseURL:NO];
    if (!urlComponents) {
        NSError *error = [NSError errorWithDomain:ApplePayNetworkErrorDomain
                                             code:ApplePayNetworkErrorInvalidInput
                                         userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Invalid paymentDetailUrl: %@", detailURL.absoluteString]}];
        completion(nil, error);
        return;
    }
    
    NSMutableArray *queryItems = [urlComponents.queryItems mutableCopy] ?: [NSMutableArray array];
    [queryItems addObject:[NSURLQueryItem queryItemWithName:@"payment_reference" value:paymentReference]];
    urlComponents.queryItems = queryItems;
    
    NSURL *url = urlComponents.URL;
    if (!url) {
        NSError *error = [NSError errorWithDomain:ApplePayNetworkErrorDomain
                                             code:ApplePayNetworkErrorInvalidInput
                                         userInfo:@{NSLocalizedDescriptionKey: @"Failed to construct URL for getLinkData from components."}];
        completion(nil, error);
        return;
    }
    
    // --- Prepare Request ---
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:30.0];
    [request setHTTPMethod:@"GET"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    [request setValue:[NSString stringWithFormat:@"Bearer %@", accessToken] forHTTPHeaderField:@"Authorization"];
    
    // --- Send Request ---
    NSURLSessionConfiguration *sessionConfig = [NSURLSessionConfiguration defaultSessionConfiguration];
    NSURLSession *session = [NSURLSession sessionWithConfiguration:sessionConfig];
    
    NSLog(@"[ApplePayNetworkService] Fetching link data from: %@", url);
    NSURLSessionDataTask *task = [session dataTaskWithRequest:request
                                            completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        // Network Error
        if (error) {
            NSLog(@"[ApplePayNetworkService] Network error fetching link data: %@ (URL: %@)", error.localizedDescription, url);
            completion(nil, error);
            return;
        }
        
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
        NSString *responseBodyStr = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] ?: @"";
        NSLog(@"[ApplePayNetworkService] Link data response status code: %ld", (long)httpResponse.statusCode);
        
        // HTTP Error Status
        if (httpResponse.statusCode < 200 || httpResponse.statusCode >= 300) {
            NSLog(@"[ApplePayNetworkService] HTTP error fetching link data: %ld Body: %@", (long)httpResponse.statusCode, responseBodyStr);
            NSDictionary *userInfo = @{
                NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Failed fetching link data with HTTP status %ld.", (long)httpResponse.statusCode],
                @"statusCode": @(httpResponse.statusCode),
                @"responseBody": responseBodyStr
            };
            NSError *httpError = [NSError errorWithDomain:NSURLErrorDomain code:httpResponse.statusCode userInfo:userInfo];
            completion(nil, httpError);
            return;
        }
        
        // Check for empty data
        if (!data || data.length == 0) {
            NSLog(@"[ApplePayNetworkService] No data received for link data despite HTTP success.");
            NSError *emptyDataError = [NSError errorWithDomain:ApplePayNetworkErrorDomain
                                                          code:ApplePayNetworkErrorBadResponse
                                                      userInfo:@{NSLocalizedDescriptionKey: @"No data received for link data."}];
            completion(nil, emptyDataError);
            return;
        }
        
        // Parse JSON
        NSError *jsonError;
        id jsonObject = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
        
        if (jsonError) {
            NSLog(@"[ApplePayNetworkService] Invalid JSON received for link data: %@ Raw Data: %@", jsonError.localizedDescription, responseBodyStr);
            NSDictionary *userInfo = @{
                NSLocalizedDescriptionKey: @"Invalid JSON response for link data.",
                NSUnderlyingErrorKey: jsonError,
                @"rawData": responseBodyStr
            };
            NSError *jsonParseError = [NSError errorWithDomain:NSCocoaErrorDomain code:NSPropertyListReadCorruptError userInfo:userInfo];
            completion(nil, jsonParseError);
            return;
        }
        
        if (![jsonObject isKindOfClass:[NSDictionary class]]) {
            NSLog(@"[ApplePayNetworkService] Link data JSON is not a dictionary: %@", jsonObject);
            NSDictionary *userInfo = @{
                NSLocalizedDescriptionKey: @"Link data JSON response is not a dictionary.",
                @"rawData": responseBodyStr
            };
            NSError *formatError = [NSError errorWithDomain:ApplePayNetworkErrorDomain code:ApplePayNetworkErrorBadResponse userInfo:userInfo];
            completion(nil, formatError);
            return;
        }
        
        NSLog(@"[ApplePayNetworkService] Link data fetched successfully.");
        completion((NSDictionary *)jsonObject, nil); // Success
    }];
    [task resume];
}


- (void)authorizePaymentWithTokenData:(NSDictionary *)tokenData
                     paymentReference:(NSString *)paymentReference
                         authorizeURL:(NSURL *)authorizeURL
                          accessToken:(NSString *)accessToken
                           completion:(void (^)(NSDictionary * _Nullable backendResponse, NSError * _Nullable error))completion {
    
    // --- Input Validation ---
    if (!tokenData || !paymentReference || !authorizeURL || !accessToken) {
        NSError *error = [NSError errorWithDomain:ApplePayNetworkErrorDomain
                                             code:ApplePayNetworkErrorInvalidInput
                                         userInfo:@{NSLocalizedDescriptionKey: @"Missing required parameters for authorizePayment."}];
        completion(nil, error);
        return;
    }
    
    // --- Prepare Request Body ---
    // Structure depends on your backend API. Example: send reference and the token data.
    NSDictionary *requestBody = @{
        @"payment_reference": paymentReference,
        @"ios_app": @YES,
        @"paymentData": tokenData // Embed the parsed Apple Pay token data
        // Add any other required fields for your authorize endpoint
    };
    
    NSError *jsonError;
    NSData *requestBodyData = [NSJSONSerialization dataWithJSONObject:requestBody options:0 error:&jsonError];
    if (jsonError) {
        NSLog(@"[ApplePayNetworkService] Failed to serialize authorization request body: %@", jsonError);
        NSError *error = [NSError errorWithDomain:ApplePayNetworkErrorDomain
                                             code:ApplePayNetworkErrorRequestSerialization
                                         userInfo:@{NSLocalizedDescriptionKey: @"Failed to serialize authorization request body.", NSUnderlyingErrorKey: jsonError}];
        completion(nil, error);
        return;
    }
    
    // --- Prepare Request ---
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:authorizeURL cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:60.0]; // Longer timeout maybe needed
    [request setHTTPMethod:@"POST"];
    [request setValue:@"application/json; charset=utf-8" forHTTPHeaderField:@"Content-Type"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    [request setValue:[NSString stringWithFormat:@"Bearer %@", accessToken] forHTTPHeaderField:@"Authorization"];
    [request setHTTPBody:requestBodyData];
    
    
    
    // --- Send Request ---
    NSURLSessionConfiguration *sessionConfig = [NSURLSessionConfiguration defaultSessionConfiguration];
    NSURLSession *urlSession = [NSURLSession sessionWithConfiguration:sessionConfig];
    
    NSLog(@"[ApplePayNetworkService] Sending authorization request to: %@ with body: %@", authorizeURL, [[NSString alloc] initWithData:requestBodyData encoding:NSUTF8StringEncoding] ?: @"<invalid body>");
    
    NSURLSessionDataTask *task = [urlSession dataTaskWithRequest:request
                                               completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        // Network Error
        if (error) {
            NSLog(@"[ApplePayNetworkService] Network error during authorization: %@", error.localizedDescription);
            completion(nil, error);
            return;
        }
        
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
        NSString *responseBodyStr = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] ?: @"";
        NSLog(@"[ApplePayNetworkService] Authorization response status code: %ld", (long)httpResponse.statusCode);
        
        // HTTP Error Status (Treat non-2xx as failure for authorization)
        if (httpResponse.statusCode < 200 || httpResponse.statusCode >= 300) {
            NSLog(@"[ApplePayNetworkService] Authorization failed (HTTP %ld). Body: %@", (long)httpResponse.statusCode, responseBodyStr);
            NSDictionary *userInfo = @{
                NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Authorization failed with HTTP status %ld.", (long)httpResponse.statusCode],
                @"statusCode": @(httpResponse.statusCode),
                @"responseBody": responseBodyStr
            };
            NSError *httpError = [NSError errorWithDomain:NSURLErrorDomain code:httpResponse.statusCode userInfo:userInfo];
            completion(nil, httpError); // Indicate failure
            return;
        }
        
        // Check for empty data on success? Depends on API. Assume response body is expected.
        if (!data || data.length == 0) {
            NSLog(@"[ApplePayNetworkService] Authorization received HTTP success but no data.");
            NSError *emptyDataError = [NSError errorWithDomain:ApplePayNetworkErrorDomain
                                                          code:ApplePayNetworkErrorBadResponse
                                                      userInfo:@{NSLocalizedDescriptionKey: @"Authorization successful (HTTP 2xx) but received no data."}];
            // Decide: Return nil response, or error? Returning error is safer if response expected.
            completion(nil, emptyDataError);
            return;
        }
        
        // Parse JSON Response
        NSError *parseError;
        id jsonObject = [NSJSONSerialization JSONObjectWithData:data options:0 error:&parseError];
        if (parseError) {
            NSLog(@"[ApplePayNetworkService] Invalid JSON received from authorization: %@ Raw Data: %@", parseError.localizedDescription, responseBodyStr);
            NSDictionary *userInfo = @{
                NSLocalizedDescriptionKey: @"Invalid JSON response from authorization.",
                NSUnderlyingErrorKey: parseError,
                @"rawData": responseBodyStr
            };
            NSError *jsonParseError = [NSError errorWithDomain:NSCocoaErrorDomain code:NSPropertyListReadCorruptError userInfo:userInfo];
            completion(nil, jsonParseError);
            return;
        }
        
        if (![jsonObject isKindOfClass:[NSDictionary class]]) {
            NSLog(@"[ApplePayNetworkService] Authorization JSON response is not a dictionary: %@", jsonObject);
            NSDictionary *userInfo = @{
                NSLocalizedDescriptionKey: @"Authorization JSON response is not a dictionary.",
                @"rawData": responseBodyStr
            };
            NSError *formatError = [NSError errorWithDomain:ApplePayNetworkErrorDomain code:ApplePayNetworkErrorBadResponse userInfo:userInfo];
            completion(nil, formatError);
            return;
        }
        
        NSLog(@"[ApplePayNetworkService] Authorization request successful (HTTP %ld).", (long)httpResponse.statusCode);
        // Return the parsed dictionary. The caller (`ApplePayModule`) will interpret its contents.
        completion((NSDictionary *)jsonObject, nil); // Success
    }];
    [task resume];
}

/**
 * Fetches and validates Apple Pay identifier for the given account
 *
 * @param accountName The account name to fetch Apple Pay identifier for
 * @param apiUsername The API username for authentication
 * @param amount The transaction amount
 * @param paymentMethodsURL The base URL for payment methods endpoint
 * @param completion Completion handler with success (BOOL), applepay_ios_identifier (NSString) and error message (NSString) if any
 */
- (void)fetchApplePayIdentifierForAccount:(NSString *)accountName
                              apiUsername:(NSString *)apiUsername
                                   amount:(NSDecimalNumber *)amount
                        paymentMethodsURL:(NSString *)paymentMethodsURL
                               completion:(void (^)(BOOL success, NSString *applePayIdentifier, NSString *errorMessage))completion {
    
    // Validate inputs and provide specific error messages
    if (!accountName || [accountName length] == 0) {
        completion(NO, nil, @"Account name is empty or nil");
        return;
    }
    
    if (!apiUsername || [apiUsername length] == 0) {
        completion(NO, nil, @"API username is empty or nil");
        return;
    }
    
    if (!amount) {
        completion(NO, nil, @"Amount is nil");
        return;
    }
    
    if (!paymentMethodsURL || [paymentMethodsURL length] == 0) {
        completion(NO, nil, @"Payment methods URL is empty or nil");
        return;
    }
    
    // Format the decimal number properly for URL
    NSString *amountString = [NSString stringWithFormat:@"%.2f", [amount doubleValue]];
    
    // Log request details
    NSLog(@"[NetworkService] Fetching Apple Pay ID for account: %@, username: %@, amount: %@, URL: %@",
          accountName, apiUsername, amountString, paymentMethodsURL);
    
    // Build the URL
    NSString *urlString = [NSString stringWithFormat:@"%@/%@?api_username=%@&amount=%@",
                           paymentMethodsURL, accountName, apiUsername, amountString];
    NSURL *url = [NSURL URLWithString:urlString];
    
    if (!url) {
        completion(NO, nil, [NSString stringWithFormat:@"Invalid URL: %@", urlString]);
        return;
    }
    
    // Create request
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:30.0];
    [request setHTTPMethod:@"GET"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    
    // Log full request details for debugging
    NSLog(@"[NetworkService] Full request URL: %@", [url absoluteString]);
    
    // Perform request
    NSURLSession *session = [NSURLSession sharedSession];
    [[session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        
        // Handle network error
        if (error) {
            NSString *errorMsg = [NSString stringWithFormat:@"Network error: %@ (code %ld)",
                                 error.localizedDescription, (long)error.code];
            NSLog(@"[NetworkService] %@", errorMsg);
            completion(NO, nil, errorMsg);
            return;
        }
        
        // Log response for debugging
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
        NSLog(@"[NetworkService] Response status code: %ld", (long)httpResponse.statusCode);
        
        // Handle HTTP error
        if (httpResponse.statusCode != 200) {
            NSString *errorBody = @"<no response body>";
            if (data) {
                errorBody = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] ?: @"<invalid data encoding>";
            }
            
            NSString *errorMsg = [NSString stringWithFormat:@"HTTP error %ld: %@",
                                 (long)httpResponse.statusCode, errorBody];
            NSLog(@"[NetworkService] %@", errorMsg);
            completion(NO, nil, errorMsg);
            return;
        }
        
        // Handle empty response
        if (!data || [data length] == 0) {
            NSString *errorMsg = @"Empty response from server";
            NSLog(@"[NetworkService] %@", errorMsg);
            completion(NO, nil, errorMsg);
            return;
        }
        
        // Parse JSON response
        NSError *jsonError;
        NSDictionary *jsonResponse = [NSJSONSerialization JSONObjectWithData:data
                                                                     options:0
                                                                       error:&jsonError];
        
        // Handle JSON parsing error
        if (jsonError || ![jsonResponse isKindOfClass:[NSDictionary class]]) {
            NSString *responseString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] ?: @"<invalid data>";
            NSString *errorMsg = [NSString stringWithFormat:@"JSON parsing error: %@ - Raw data: %@",
                                 jsonError.localizedDescription ?: @"Invalid JSON", responseString];
            NSLog(@"[NetworkService] %@", errorMsg);
            completion(NO, nil, errorMsg);
            return;
        }
        
        // Log full response for debugging
        NSLog(@"[NetworkService] Response: %@", jsonResponse);
        
        // Extract payment methods array
        NSArray *paymentMethods = jsonResponse[@"payment_methods"];
        if (!paymentMethods || ![paymentMethods isKindOfClass:[NSArray class]] || [paymentMethods count] == 0) {
            NSString *errorMsg = @"No payment methods found in response";
            NSLog(@"[NetworkService] %@", errorMsg);
            completion(NO, nil, errorMsg);
            return;
        }
        
        // Look for card payment method
        NSDictionary *cardMethod = nil;
        for (NSDictionary *method in paymentMethods) {
            if ([method[@"source"] isEqualToString:@"card"]) {
                cardMethod = method;
                break;
            }
        }
        
        if (!cardMethod) {
            NSString *errorMsg = @"Card payment method not found in response";
            NSLog(@"[NetworkService] %@", errorMsg);
            completion(NO, nil, errorMsg);
            return;
        }
        
        // Check if Apple Pay is available
        BOOL applePayAvailable = [cardMethod[@"applepay_available"] boolValue];
        if (!applePayAvailable) {
            NSString *errorMsg = [NSString stringWithFormat:@"Apple Pay is not available for account %@", accountName];
            NSLog(@"[NetworkService] %@", errorMsg);
            completion(NO, nil, errorMsg);
            return;
        }
        
        // Check if Apple Pay is registered
        BOOL applePayRegistered = [cardMethod[@"applepay_ios_register"] boolValue];
        if (!applePayRegistered) {
            NSString *errorMsg = [NSString stringWithFormat:@"Apple Pay is not registered for account %@", accountName];
            NSLog(@"[NetworkService] %@", errorMsg);
            completion(NO, nil, errorMsg);
            return;
        }
        
        // Extract Apple Pay iOS identifier
        NSString *applePayIdentifier = cardMethod[@"applepay_ios_identifier"];
        if (!applePayIdentifier || [applePayIdentifier length] == 0) {
            NSString *errorMsg = [NSString stringWithFormat:@"Apple Pay identifier is empty for account %@", accountName];
            NSLog(@"[NetworkService] %@", errorMsg);
            completion(NO, nil, errorMsg);
            return;
        }
        
        // Success
        NSLog(@"[NetworkService] Successfully retrieved Apple Pay identifier: %@", applePayIdentifier);
        completion(YES, applePayIdentifier, nil);
        
    }] resume];
}

@end
