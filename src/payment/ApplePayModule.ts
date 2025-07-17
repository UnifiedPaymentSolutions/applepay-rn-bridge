import { NativeModules, Platform } from 'react-native'; // Added Platform
import type { PaymentResult, NativeApplePayModule, InitResult, InitRequest, PaymentRequest } from './types'; // Import interfaces
import { PaymentError } from './types'; // Import custom error class
import { getInitPaymentEndpoints, getStartPaymentEndpoints } from './utils';

/**
 * Interface defining the ApplePay module functionality
 */
export interface ApplePayInterface {
  /**
   * Checks if the device supports Apple Pay payments
   * @returns Promise resolving to true if payments are possible
   */
  canMakePayments(): Promise<boolean>;

  /**
   * Initializes a payment with the Everypay backend
   * @param initRequest Configuration for payment initialization
   * @returns Promise with initialization result data
   */
  initEverypayPayment(initRequest: InitRequest): Promise<InitResult>;

  /**
   * Starts the Apple Pay payment flow with prepared payment data
   * @param paymentRequest Payment configuration and data
   * @returns Promise with payment result
   */
  startApplePayPayment(paymentRequest: PaymentRequest): Promise<PaymentResult>;

  /**
   * Presents Apple Pay sheet first, then initializes with Everypay
   * only after Apple Pay authorization is received
   * @param config Configuration for payment
   * @returns Promise with payment result
   */
  startApplePayWithLateEverypayInit(config: InitRequest): Promise<PaymentResult>;

  /**
   * Presents Apple Pay sheet first, then initializes with Everypay
   * only after Apple Pay authorization is received
   * @param config Configuration for payment
   * @returns Promise with payment result
   */
  startApplePayWithLateEverypayInit(config: InitRequest): Promise<PaymentResult>;

  /**
   * Sets whether mock payments are enabled in debug builds
   * @param enabled Whether mock payments should be enabled
   * @returns Promise resolving to true if setting was applied, false if not supported (production build)
   */
  setMockPaymentsEnabled(enabled: boolean): Promise<boolean>;

}

// Define expected module name (must match RCT_EXPORT_MODULE name)
const MODULE_NAME = 'ApplePayModule';

// Get the native module instance
const ApplePayModule = NativeModules[MODULE_NAME];

// Check if the native module exists
if (!ApplePayModule) {
  // Provide more context in the error message
  console.error(
    `Native module "${MODULE_NAME}" not found.` +
      `\nPlatform: ${Platform.OS}` +
      `\nAvailable modules: ${Object.keys(NativeModules).join(', ')}` +
      '\n\nTroubleshooting:' +
      '\n- Ensure you have run "pod install" in the "ios" directory.' +
      '\n- Make sure the native module is linked correctly (autolinking should handle this for recent RN versions).' +
      '\n- Verify the module name ("ApplePayModule") matches exactly in Objective-C (`RCT_EXPORT_MODULE`).' +
      '\n- Rebuild the app (e.g., "npx react-native run-ios").'
  );

  // Throw an error only if essential, or handle gracefully
  throw new Error(`Native module "${MODULE_NAME}" not found. See console for details.`);
}

// Cast the native module to our specific TypeScript interface for type safety
const TypedApplePayModule = ApplePayModule as NativeApplePayModule;

/**
 * Checks if the device supports Apple Pay payments (with configured networks).
 *
 * @returns Promise that resolves to `true` if payments are possible, otherwise `false`.
 * @throws May throw an error if an unexpected issue occurs while communicating with the native module.
 */
async function canMakePayments(): Promise<boolean> {
  try {
    const result = await TypedApplePayModule.canMakePayments();
    console.log('[ApplePay RN] canMakePayments result:', result);
    return result;
  } catch (error: any) {
    throw new Error(`Failed to check payment availability: ${error.message || error}`);
  }
}

/**
 * Performs only the backend payment initialization via the native module.
 *
 * @param config The payment configuration object (`StartPaymentInput`).
 * @returns Promise that resolves with the initialization data (`PaymentInitData`) needed for `startApplePay`.
 * @throws {PaymentError} If the initialization fails on the native side (e.g., network error, invalid config).
 * @throws {Error} If an unexpected error occurs.
 */
async function initEverypayPayment(config: InitRequest): Promise<InitResult> {
  try {
    const { auth, data, baseUrl } = config;
    const endpoints = getInitPaymentEndpoints(baseUrl);
    const result = await TypedApplePayModule.initPayment({ auth, data, endpoints });

    // Basic validation (native side should ensure structure, but good practice)
    if (
      result &&
      result.accountName &&
      result.paymentReference &&
      result.mobileAccessToken &&
      result.amount &&
      result.currencyCode
    ) {
      console.log('[ApplePay RN] initPayment successful, received init data:', result);
      return result;
    } else {
      console.error('[ApplePay RN] initPayment resolved with unexpected or incomplete value:', result);
      throw new Error('Native module resolved initPayment without essential data.');
    }
  } catch (error: any) {
    console.error('[ApplePay RN] Error in initPayment:', error);
    if (error && typeof error.code === 'string' && typeof error.message === 'string') {
      throw new PaymentError(error.message, error.code);
    } else {
      const errorMessage = error instanceof Error ? error.message : String(error);
      throw new Error(`An unexpected error occurred during payment initialization: ${errorMessage}`);
    }
  }
}

/**
 * Starts the EP Apple Pay payment process.
 *
 * First communicates with the backend to initialize the payment according to the configuration,
 * then displays the Apple Pay sheet to the user. If the user authorizes the payment,
 * the payment token is sent to the backend for final processing.
 *
 * @param config The payment configuration object (`StartPaymentInput`).
 * @returns Promise that resolves with successful payment data (`EPSuccessResult`).
 * @throws {PaymentError} If the payment fails or is cancelled.
 *         The error's `code` property contains the error code returned by the native module
 *         (e.g., 'cancelled', 'init_failed', 'authorization_failed').
 * @throws {Error} If an unexpected error occurs during communication with the native module.
 */
async function startApplePayPayment(startPaymentInput: PaymentRequest): Promise<PaymentResult> {
  try {
    const { auth, data, baseUrl } = startPaymentInput;
    const endpoints = getStartPaymentEndpoints(baseUrl);
    const startPaymentRequest = {auth, data, endpoints};
    console.log('[ApplePay RN] startPayment request: ' + JSON.stringify(startPaymentRequest));
    const result = await TypedApplePayModule.startApplePay(startPaymentRequest);

    // Ensure the promise actually resolved with an object containing 'success: true'
    // Native side ensures this, but good practice to double-check
    if (result && result.success === true) {
      return result;
    } else {
      console.error('[ApplePay RN] startPayment resolved with unexpected value:', result);
      throw new Error('Native module resolved startPayment without success flag or valid data.');
    }
  } catch (error: any) {
    console.error('[ApplePay RN] Error in startPayment:', error);
    // Native module should reject with an object containing 'code' and 'message'
    if (error && typeof error.code === 'string' && typeof error.message === 'string') {
      // Create and throw our custom, type-safe error object
      throw new PaymentError(error.message, error.code);
    } else {
      // Unknown error - throw a generic Error
      // Check if it's a standard Error object first
      const errorMessage = error instanceof Error ? error.message : String(error);
      throw new Error(`An unexpected error occurred during Apple Pay: ${errorMessage}`);
    }
  }
}

const startApplePayWithLateEverypayInit = async (config: InitRequest): Promise<PaymentResult> => {
  try {
    const { auth, baseUrl } = config;
    console.log('[ApplePay RN] Going to invoke startPayment:');
    return startApplePayPayment({
      auth,
      baseUrl,
      data: {
        accountName: config.data.accountName,
        amount: config.data.amount,
        label: config.data.label,
        currencyCode: config.data.currencyCode,
        countryCode: config.data.countryCode,
        orderReference: config.data.orderReference
      }
    });
  } catch (error) {
    throw error;
  }
};

/**
 * Sets whether mock payments are enabled for testing
 * Only works in debug builds
 */
async function setMockPaymentsEnabled(enabled: boolean): Promise<boolean> {
  try {
    const result = await TypedApplePayModule.setMockPaymentsEnabled(enabled);
    console.log('[ApplePay RN] setMockPaymentsEnabled result:', result);
    return result.success === true;
  } catch (error: any) {
    console.warn('[ApplePay RN] Failed to set mock payments:', error.message || error);
    return false;
  }
}

// Create and export the module that implements the interface
const ApplePay: ApplePayInterface = {
  canMakePayments,
  initEverypayPayment,
  startApplePayPayment,
  startApplePayWithLateEverypayInit,
  setMockPaymentsEnabled
};

export default ApplePay;

// Export the wrapper functions and types/classes for use in the application
export { canMakePayments, startApplePayPayment, initEverypayPayment, startApplePayWithLateEverypayInit, setMockPaymentsEnabled };

