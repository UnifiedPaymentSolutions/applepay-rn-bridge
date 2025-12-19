// =============================================================================
// APPLE PAY BUTTON TYPES
// =============================================================================

/**
 * Apple Pay button style (PKPaymentButtonStyle)
 */
export type ApplePayButtonStyle = 'black' | 'white' | 'whiteOutline' | 'automatic';

/**
 * Apple Pay button type (PKPaymentButtonType)
 * These map to the text shown on the button
 */
export type ApplePayButtonType =
  | 'plain'      // Apple Pay logo only
  | 'buy'        // "Buy with Apple Pay"
  | 'setUp'      // "Set Up Apple Pay"
  | 'inStore'    // "Pay with Apple Pay"
  | 'donate'     // "Donate with Apple Pay"
  | 'checkout'   // "Check out with Apple Pay"
  | 'book'       // "Book with Apple Pay"
  | 'subscribe'  // "Subscribe with Apple Pay"
  | 'reload'     // "Reload with Apple Pay"
  | 'addMoney'   // "Add Money with Apple Pay"
  | 'topUp'      // "Top Up with Apple Pay"
  | 'order'      // "Order with Apple Pay"
  | 'rent'       // "Rent with Apple Pay"
  | 'support'    // "Support with Apple Pay"
  | 'contribute' // "Contribute with Apple Pay"
  | 'tip'        // "Tip with Apple Pay"
  | 'continue';  // "Continue with Apple Pay"

/**
 * SDK Configuration for the button component
 */
export interface ApplePaySDKConfig {
  /** Backend API username */
  apiUsername: string;
  /** Backend API secret */
  apiSecret: string;
  /** Backend API base URL */
  baseUrl: string;
  /** Account name (e.g., "EUR3D1") */
  accountName: string;
  /** ISO 3166-1 alpha-2 country code (e.g., "EE") */
  countryCode?: string;
}

// =============================================================================
// BACKEND MODE TYPES (Recommended)
// =============================================================================

/**
 * Backend Mode data - user fetches this from their backend.
 * Contains all data needed to present Apple Pay sheet.
 */
export interface ApplePayBackendData {
  /** Apple Pay merchant identifier (e.g., "merchant.com.example") */
  merchantIdentifier: string;
  /** Merchant display name shown on payment sheet */
  merchantName: string;
  /** Payment amount */
  amount: number;
  /** ISO 4217 currency code (e.g., "EUR") */
  currencyCode: string;
  /** ISO 3166-1 alpha-2 country code (e.g., "EE") */
  countryCode: string;
  /** Payment reference from EveryPay init */
  paymentReference: string;
  /** Mobile access token from EveryPay init */
  mobileAccessToken: string;
  /** Optional: Enable recurring token request (iOS 16+) */
  recurring?: RecurringConfig;
}

/**
 * Recurring payment configuration (iOS 16+)
 */
export interface RecurringConfig {
  /** Description shown in payment sheet (e.g., "Save card for future payments") */
  description: string;
  /** URL where users can manage their recurring payment */
  managementURL: string;
  /** Optional: Label for billing item */
  billingLabel?: string;
  /** Optional: Billing agreement text */
  billingAgreement?: string;
}

/**
 * Token result returned from Apple Pay (Backend Mode).
 * User sends this to their backend for processing.
 */
export interface ApplePayTokenResult {
  /** Whether Apple Pay authorization was successful */
  success: boolean;
  /** Base64 encoded Apple Pay token data */
  paymentData: string;
  /** Apple Pay transaction identifier */
  transactionIdentifier: string;
  /** Payment method information */
  paymentMethod: PaymentMethodInfo;
  /** Payment reference (from backend data) */
  paymentReference: string;
  /** Mobile access token (from backend data) */
  mobileAccessToken: string;
}

/**
 * Payment method information from Apple Pay
 */
export interface PaymentMethodInfo {
  /** Display name (e.g., "Visa 1234") */
  displayName: string;
  /** Payment network (e.g., "Visa", "MasterCard") */
  network: string;
  /** Payment method type (PKPaymentMethodType enum value) */
  type: number;
}

// =============================================================================
// SDK MODE TYPES
// =============================================================================

/**
 * Authentication credentials for the backend API.
 */
export interface AuthCredentials {
  /** Backend API username. */
  apiUsername: string;
  /** Backend API secret. */
  apiSecret: string;
}

/**
 * Backend API endpoint URLs.
 */
export interface InitEndpoints {

  mobileOneoffUrl: string;

}

/**
 * Backend API endpoint URLs.
 */
export interface StartEndpoints {
  /**
   * URL for authorizing the Apple Pay payment (where the token is sent).
   * Required for the `didAuthorizePayment` method.
   */
  authorizePaymentUrl: string;

  /**
   * URL for validating the Apple Pay session (if you use 'paymentSessionUrl').
   * NOTE: This is not currently used in your native code but might be necessary
   * for `paymentAuthorizationController:didRequestMerchantSessionUpdate:handler:`.
   * If you don't implement that delegate method, this is not needed.
   */
  paymentSessionUrl?: string; // Present in native code, but not actively used

  mobileOneoffUrl?: string;
}

/**
 * Payment-related data sent in the backend initialization request
 * and used to configure the Apple Pay sheet.
 */
export interface InitRequestData {
  /** Payment amount as a number (e.g., 10.99). */
  amount: number;

  /** Payment description displayed on the Apple Pay sheet (e.g., "Payment for Order"). */
  label: string;

  /** ISO 4217 currency code (e.g., "EUR"). */
  currencyCode: string; // Added here, though native can also get it from init response

  /** ISO 3166-1 alpha-2 country code (e.g., "EE"). */
  countryCode: string;

  /** Order reference number in your system (optional, generated if missing). */
  orderReference?: string;

  /** Backend account name (optional, defaults to "EUR3D1" in native code). */
  accountName: string;

  /** Customer redirect URL (optional, defaults to example.com in native code). */
  customerUrl?: string;

  /** Locale (e.g., "en", "et", optional, defaults to "en" in native code). */
  locale?: string;

  /** Customer IP address (optional). */
  customerIp?: string;

  /** Customer email address (optional). */
  customerEmail?: string;

  // Add other fields here that your backend init endpoint requires
  // [key: string]: any;
}

/**
 * Payment-related data sent in the backend initialization request
 * and used to configure the Apple Pay sheet.
 */
export interface PaymentRequestData {

  /** Backend account name (optional, defaults to "EUR3D1" in native code). */
  accountName: string;

  /** Payment amount as a number (e.g., 10.99). */
  amount: string | number;

  /** Everypay payment reference */
  paymentReference?: string;

  /** Everypay order reference */
  orderReference?: string;

  /** Everypay access token */
  mobileAccessToken?: string;

  /** ISO 4217 currency code (e.g., "EUR"). */
  currencyCode?: string; // Added here, though native can also get it from init response

  /** ISO 3166-1 alpha-2 country code (e.g., "EE"). */
  countryCode?: string;

  /** Payment description displayed on the Apple Pay sheet (e.g., "Payment for Order"). */
  label?: string;

}

export interface InitRequest {
  auth: AuthCredentials;
  baseUrl: string;
  data: InitRequestData;
}

/**
 * The complete configuration object for the `startPayment` method.
 */
export interface PaymentRequest {
  auth: AuthCredentials;
  baseUrl: string;
  data: PaymentRequestData;
}

export interface MockPaymentResult {
  success: boolean;
  reason?: string;
}

// --- Result Types ---

/**
 * Successful payment result returned when the `startPayment` promise resolves.
 * This is based on the `resolveWithSuccess` call in the native code.
 */
export interface PaymentResult {
  /** Always indicates `true` for a successful result. */
  success: true;

  /** Payment reference generated/received from the backend. */
  paymentReference: string;

  /**
   * Backend response from the authorization request (`authorizePaymentUrl`).
   * The structure depends on your backend API.
   */
  response: Record<string, any>; // Or a more specific type if you know the structure

  /**
   * Backend response from the initialization request (`mobileOneoffUrl`).
   * The structure depends on your backend API.
   */
  initData: Record<string, any>; // Or a more specific type
}

/**
 * Error object returned when the `startPayment` promise is rejected.
 */
export class PaymentError extends Error {
  /**
   * Error code from the native module (e.g., 'cancelled', 'init_failed', 'authorization_failed', etc.).
   */
  code: string;

  constructor(message: string, code: string) {
    super(message);
    this.name = 'ApplePayError';
    this.code = code;
    // Restore prototype chain (necessary for Error subclasses in TypeScript)
    Object.setPrototypeOf(this, PaymentError.prototype);
  }
}

/**
 * TypeScript description of the native module's methods.
 * This MUST exactly match what is exported in the Objective-C code.
 */
export interface NativeApplePayModule {
  /** Checks if the device supports Apple Pay payments with the specified networks. */
  canMakePayments(): Promise<boolean>;

  /**
   * Starts the payment process: communicates with the backend for initialization
   * and then presents the Apple Pay sheet.
   * @param startPaymentRequest The payment request object.
   * @returns Promise that resolves with successful payment data (`ApplePaySuccessResult`)
   *          or rejects with an error (`ApplePayError`).
   */
  startApplePay(startPaymentRequest: {
    auth: PaymentRequest['auth'];
    data: PaymentRequest['data'];
    endpoints: StartEndpoints; // Use inferred type
  }): Promise<PaymentResult>;

  initPayment(config: {
    auth: InitRequest['auth'];
    data: InitRequest['data'];
    endpoints: InitEndpoints; // Use inferred type
  }): Promise<InitResult>; // Resolves with data for startApplePay

  setMockPaymentsEnabled(enabled: boolean): Promise<MockPaymentResult>;
}

/**
 * Data structure returned by the native initPayment method,
 * containing all necessary information to start the Apple Pay UI flow.
 * Keys should match what native initPayment resolves with.
 */
export interface InitResult {
  accountName: string;
  apiUsername: string;
  paymentReference: string;
  orderReference: string;
  mobileAccessToken: string;
  amount: number;
  currencyCode: string;
  paymentState: string;
  originalInitResponse?: Record<string, any>; // Optional original full response
}

// =============================================================================
// NATIVE MODULE INTERFACE (SDK Wrapper)
// =============================================================================

/**
 * Configuration for the native SDK wrapper.
 * Used by both Backend Mode and SDK Mode to configure the Apple Pay sheet.
 */
export interface SDKConfigureRequest {
  /** Payment amount */
  amount: number;
  /** Apple Pay merchant identifier */
  merchantIdentifier: string;
  /** Merchant display name shown on payment sheet */
  merchantName: string;
  /** ISO 4217 currency code (e.g., "EUR") */
  currencyCode: string;
  /** ISO 3166-1 alpha-2 country code (e.g., "EE") */
  countryCode: string;
  /** Optional recurring payment configuration */
  recurring?: RecurringConfig;
}

/**
 * Result from native presentPayment method.
 * Contains serialized Apple Pay token.
 */
export interface NativeTokenResult {
  /** Whether Apple Pay authorization was successful */
  success: boolean;
  /** Base64 encoded Apple Pay token data */
  paymentData: string;
  /** Apple Pay transaction identifier */
  transactionIdentifier: string;
  /** Payment method information */
  paymentMethod: PaymentMethodInfo;
}

/**
 * New native module interface (SDK wrapper).
 * This is a thin wrapper around EPApplePayManager.
 */
export interface NativeApplePayModuleV2 {
  /** Check if Apple Pay is available on this device */
  canMakePayments(): Promise<boolean>;

  /** Check if device supports recurring payment tokens (iOS 16+) */
  canRequestRecurringToken(): Promise<boolean>;

  /** Configure the SDK before presenting payment sheet */
  configure(config: SDKConfigureRequest): Promise<{ success: boolean }>;

  /** Present Apple Pay sheet and return serialized token */
  presentPayment(): Promise<NativeTokenResult>;

  /** Enable/disable mock payments (debug builds only) */
  setMockPaymentsEnabled(enabled: boolean): Promise<MockPaymentResult>;
}
