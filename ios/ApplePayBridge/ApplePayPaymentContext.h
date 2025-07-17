#import <Foundation/Foundation.h>
#import <PassKit/PassKit.h> // Vajalik NSDecimalNumber jaoks

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief Holds all necessary data for an ongoing Apple Pay payment session,
 * derived from the initial backend response and configuration.
 */
@interface ApplePayPaymentContext : NSObject

- (void)updateWithApplePayMerchantIdentifier:(NSString *)merchantId;

- (void)updateWithLateInitResult:(NSDictionary *)initResult;

@property (nonatomic, copy, readonly) NSString *apiUsername;
@property (nonatomic, copy, readonly) NSString *apiSecret;
@property (nonatomic, copy, readonly) NSString *accountName;
@property (nonatomic, copy, readonly) NSString *locale;

// --- Properties derived from backend init response ---
@property (nonatomic, assign, readonly) BOOL everypayAlreadyInitialized; // URL for fetching link/recurring details
@property (nonatomic, copy, readonly) NSString *paymentReference;
@property (nonatomic, copy, readonly) NSString *orderReference;
@property (nonatomic, copy, readonly) NSString *accessToken; // Mobile access token for subsequent calls

@property (nonatomic, copy, readonly) NSString *merchantId; // Apple Pay Merchant Identifier
@property (nonatomic, copy, readonly) NSString *currencyCode; // e.g., "EUR"
@property (nonatomic, copy, readonly, nullable) NSDictionary *initializationResponse; // Store the full original init response

// --- Properties derived from original RN config ---
@property (nonatomic, copy, readonly) NSString *countryCode; // e.g., "EE"
@property (nonatomic, copy, readonly) NSString *paymentLabel; // Label shown on the payment sheet (e.g., "Total")
@property (nonatomic, copy, readonly) NSDecimalNumber *amount; // The payment amount

// --- Properties derived from endpoints config ---
@property (nonatomic, copy, readonly) NSURL *paymentSessionURL; // URL for fetching session details (if needed)
@property (nonatomic, copy, readonly) NSURL *authorizePaymentURL; // URL for sending the Apple Pay token for authorization
@property (nonatomic, copy, readonly) NSURL *paymentDetailURL; // URL for fetching link/recurring details
@property (nonatomic, copy, readonly) NSURL *mobileOneoffUrl; //URL for initilizing Everypay payment

/**
 * @brief Initializes the payment context with data from the backend initialization
 * response and the original configuration provided from React Native.
 *
 /**
  * Initializes context from pre-fetched data (e.g., from initPayment or server-side).
  * Expects a dictionary containing keys like:
  * paymentReference, applepayMerchantIdentifier, mobileAccessToken, currency,
  * countryCode, label, amount, authorizePaymentUrl, paymentDetailUrl,
  * [optional] paymentSessionUrl, [optional] originalInitResponse
  */
 - (nullable instancetype)initWithPaymentInitData:(NSDictionary *)paymentInitData NS_DESIGNATED_INITIALIZER;

// Prevent default init
- (instancetype)init NS_UNAVAILABLE;

/**
 * @brief Checks if the essential properties required to start the Apple Pay flow are valid.
 */
- (BOOL)isContextValidForStartingPayment;

@end

NS_ASSUME_NONNULL_END
