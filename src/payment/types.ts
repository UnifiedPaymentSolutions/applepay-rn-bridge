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

  paymentMethodsUrl: string;

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
