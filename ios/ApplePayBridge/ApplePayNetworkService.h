#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief Handles network communication related to the Apple Pay flow.
 * This class is responsible for making API calls to initialize the payment,
 * fetch details, and authorize the payment with the backend. It does not
 * interact directly with React Native promises or PassKit UI.
 */
@interface ApplePayNetworkService : NSObject

/**
 * @brief Calls the backend initialization endpoint.
 *
 * @param config The configuration dictionary containing auth, endpoints, and data payload.
 * @param completion A block called upon completion, containing the backend response dictionary or an error.
 */
- (void)initializePaymentWithConfig:(NSDictionary *)config
                         completion:(void (^)(NSDictionary * _Nullable response, NSError * _Nullable error))completion;

/**
 * @brief Fetches payment link details (e.g., for recurring payments) from the backend.
 *
 * @param detailURL The URL to fetch details from.
 * @param paymentReference The unique payment reference for this transaction.
 * @param accessToken The mobile access token obtained during initialization.
 * @param completion A block called upon completion, containing the link data dictionary or an error.
 */
- (void)fetchLinkDataWithDetailURL:(NSURL *)detailURL
                  paymentReference:(NSString *)paymentReference
                       accessToken:(NSString *)accessToken
                        completion:(void (^)(NSDictionary * _Nullable linkData, NSError * _Nullable error))completion;

/**
 * @brief Sends the Apple Pay payment token data to the backend for authorization.
 *
 * @param tokenData The dictionary parsed from the PKPaymentToken's paymentData.
 * @param paymentReference The unique payment reference for this transaction.
 * @param authorizeURL The backend URL endpoint for authorizing the payment.
 * @param accessToken The mobile access token obtained during initialization.
 * @param completion A block called upon completion, containing the backend authorization response dictionary or an error.
 */
- (void)authorizePaymentWithTokenData:(NSDictionary *)tokenData
                     paymentReference:(NSString *)paymentReference
                         authorizeURL:(NSURL *)authorizeURL
                          accessToken:(NSString *)accessToken
                           completion:(void (^)(NSDictionary * _Nullable backendResponse, NSError * _Nullable error))completion;



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
                               completion:(void (^)(BOOL success, NSString *applePayIdentifier, NSString *errorMessage))completion;

/**
 * @brief Generates an ISO 8601 formatted timestamp string in UTC.
 * @return ISO 8601 timestamp string.
 */
- (NSString *)iso8601Timestamp;


@end

NS_ASSUME_NONNULL_END
