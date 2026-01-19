/**
 * ApplePayModule - React Native Apple Pay Bridge
 *
 * Supports two modes:
 * - Backend Mode (recommended): User provides data from their backend
 * - SDK Mode: Library makes API calls
 */

import { Platform } from 'react-native';
import type {
  PaymentResult,
  InitResult,
  InitRequest,
  PaymentRequest,
  ApplePayBackendData,
  ApplePayTokenResult,
  SDKConfigureRequest,
  NativeTokenResult,
} from './types';
import { PaymentError } from './types';
import { everypayApiService } from './api';
import { API_AUTHORIZE_PAYMENT_PATH } from './constants';

// =============================================================================
// MODULE SETUP
// =============================================================================

// Conditionally import native module (iOS only)
// TurboModuleRegistry handles both Old and New Architecture automatically
const NativeModule =
  Platform.OS === 'ios'
    ? require('../specs/NativeApplePayModule').default
    : null;

// =============================================================================
// BACKEND MODE (Recommended)
// =============================================================================

/**
 * Make payment with backend-provided data.
 * Returns the Apple Pay token for user to send to their backend.
 *
 * @param backendData Data from user's backend containing all payment info
 * @returns Promise with Apple Pay token result
 */
async function makePaymentWithBackendData(
  backendData: ApplePayBackendData
): Promise<ApplePayTokenResult> {
  console.log('[ApplePay RN] makePaymentWithBackendData called');

  try {
    // 1. Configure the SDK
    const configRequest: SDKConfigureRequest = {
      amount: backendData.amount,
      merchantIdentifier: backendData.merchantIdentifier,
      merchantName: backendData.merchantName,
      currencyCode: backendData.currencyCode,
      countryCode: backendData.countryCode,
      recurring: backendData.recurring,
    };

    await NativeModule!.configure(configRequest);
    console.log('[ApplePay RN] SDK configured');

    // 2. Present Apple Pay sheet
    const tokenResult: NativeTokenResult = await NativeModule!.presentPayment();
    console.log('[ApplePay RN] Apple Pay token received');

    // 3. Return token with backend data for user to process
    return {
      success: tokenResult.success,
      paymentData: tokenResult.paymentData,
      transactionIdentifier: tokenResult.transactionIdentifier,
      paymentMethod: tokenResult.paymentMethod,
      paymentReference: backendData.paymentReference,
      mobileAccessToken: backendData.mobileAccessToken,
    };
  } catch (error: unknown) {
    console.error('[ApplePay RN] Error in makePaymentWithBackendData:', error);
    if (
      error &&
      typeof error === 'object' &&
      'code' in error &&
      'message' in error
    ) {
      const typedError = error as { code: string; message: string };
      throw new PaymentError(typedError.message, typedError.code);
    }
    throw error;
  }
}

/**
 * Request recurring token with backend-provided data.
 * Same as makePaymentWithBackendData but ensures recurring is configured.
 *
 * @param backendData Data from user's backend with recurring config
 * @returns Promise with Apple Pay token result
 */
async function requestTokenWithBackendData(
  backendData: ApplePayBackendData
): Promise<ApplePayTokenResult> {
  // Ensure recurring is configured
  if (!backendData.recurring) {
    throw new PaymentError(
      'Recurring configuration is required for token request',
      'invalid_config'
    );
  }
  return makePaymentWithBackendData(backendData);
}

// =============================================================================
// SDK MODE (Existing API - Backwards Compatible)
// =============================================================================

/**
 * Checks if the device supports Apple Pay payments.
 */
async function canMakePayments(): Promise<boolean> {
  if (Platform.OS !== 'ios') {
    return false;
  }
  try {
    const result = await NativeModule!.canMakePayments();
    console.log('[ApplePay RN] canMakePayments result:', result);
    return result;
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : String(error);
    throw new Error(`Failed to check payment availability: ${message}`);
  }
}

/**
 * Check if device supports recurring payment tokens (iOS 16+)
 */
async function canRequestRecurringToken(): Promise<boolean> {
  if (Platform.OS !== 'ios') {
    return false;
  }
  try {
    return await NativeModule!.canRequestRecurringToken();
  } catch (error: unknown) {
    console.warn(
      '[ApplePay RN] Failed to check recurring token support:',
      error
    );
    return false;
  }
}

/**
 * Initialize payment with EveryPay backend (SDK Mode).
 */
async function initEverypayPayment(config: InitRequest): Promise<InitResult> {
  console.log('[ApplePay RN] initEverypayPayment called (SDK Mode)');

  try {
    const initResponse = await everypayApiService.initializePayment({
      baseUrl: config.baseUrl,
      auth: config.auth,
      data: {
        accountName: config.data.accountName,
        amount: config.data.amount,
        orderReference: config.data.orderReference,
        customerUrl: config.data.customerUrl,
        locale: config.data.locale,
        customerEmail: config.data.customerEmail,
        customerIp: config.data.customerIp,
      },
    });

    console.log('[ApplePay RN] initEverypayPayment successful');

    return {
      accountName: initResponse.accountName,
      apiUsername: initResponse.apiUsername,
      paymentReference: initResponse.paymentReference,
      orderReference: initResponse.orderReference,
      mobileAccessToken: initResponse.mobileAccessToken,
      amount: initResponse.amount,
      currencyCode: initResponse.currencyCode,
      paymentState: initResponse.paymentState,
      originalInitResponse: initResponse.originalResponse,
    };
  } catch (error: unknown) {
    console.error('[ApplePay RN] Error in initEverypayPayment:', error);
    if (
      error &&
      typeof error === 'object' &&
      'code' in error &&
      'message' in error
    ) {
      const typedError = error as { code: string; message: string };
      throw new PaymentError(typedError.message, typedError.code);
    }
    const errorMessage = error instanceof Error ? error.message : String(error);
    throw new Error(`Payment initialization failed: ${errorMessage}`);
  }
}

/**
 * Full payment flow (SDK Mode).
 * Fetches merchant ID, initializes payment, presents Apple Pay, authorizes.
 */
async function startApplePayPayment(
  paymentRequest: PaymentRequest
): Promise<PaymentResult> {
  console.log('[ApplePay RN] startApplePayPayment called (SDK Mode)');

  try {
    const { auth, data, baseUrl } = paymentRequest;
    const amount =
      typeof data.amount === 'string' ? parseFloat(data.amount) : data.amount;

    // 1. Get payment methods to retrieve Apple Pay merchant identifier
    const paymentMethods = await everypayApiService.getPaymentMethods({
      baseUrl,
      apiUsername: auth.apiUsername,
      accountName: data.accountName,
      amount,
    });
    console.log(
      '[ApplePay RN] Got Apple Pay merchant ID:',
      paymentMethods.applePayMerchantIdentifier
    );

    // 2. Initialize payment with backend
    const initResponse = await everypayApiService.initializePayment({
      baseUrl,
      auth,
      data: {
        accountName: data.accountName,
        amount,
        orderReference: data.orderReference,
      },
    });
    console.log(
      '[ApplePay RN] Payment initialized, reference:',
      initResponse.paymentReference
    );

    // 3. Configure SDK
    const configRequest: SDKConfigureRequest = {
      amount: initResponse.amount,
      merchantIdentifier: paymentMethods.applePayMerchantIdentifier,
      merchantName: data.label || data.accountName,
      currencyCode: initResponse.currencyCode,
      countryCode: data.countryCode || 'EE',
    };

    await NativeModule!.configure(configRequest);
    console.log('[ApplePay RN] SDK configured');

    // 4. Present Apple Pay sheet
    const tokenResult = await NativeModule!.presentPayment();
    console.log('[ApplePay RN] Apple Pay token received');

    // 5. Decode and authorize with backend
    const paymentDataJson = JSON.parse(atob(tokenResult.paymentData));

    const authorizeResponse = await everypayApiService.authorizePayment({
      authorizeUrl: `${baseUrl}${API_AUTHORIZE_PAYMENT_PATH}`,
      accessToken: initResponse.mobileAccessToken,
      paymentReference: initResponse.paymentReference,
      paymentData: paymentDataJson,
    });
    console.log(
      '[ApplePay RN] Payment authorized, state:',
      authorizeResponse.state
    );

    // 6. Check authorization result
    const successStates = ['completed', 'authorized', 'captured'];
    if (!successStates.includes(authorizeResponse.state)) {
      throw new PaymentError(
        `Payment rejected by backend (state: ${authorizeResponse.state})`,
        'backend_rejected'
      );
    }

    return {
      success: true,
      paymentReference: initResponse.paymentReference,
      response: authorizeResponse,
      initData: initResponse.originalResponse,
    };
  } catch (error: unknown) {
    console.error('[ApplePay RN] Error in startApplePayPayment:', error);
    if (error instanceof PaymentError) {
      throw error;
    }
    if (
      error &&
      typeof error === 'object' &&
      'code' in error &&
      'message' in error
    ) {
      const typedError = error as { code: string; message: string };
      throw new PaymentError(typedError.message, typedError.code);
    }
    const errorMessage = error instanceof Error ? error.message : String(error);
    throw new Error(`Apple Pay payment failed: ${errorMessage}`);
  }
}

/**
 * Enable/disable mock payments (debug builds only)
 */
async function setMockPaymentsEnabled(enabled: boolean): Promise<boolean> {
  if (Platform.OS !== 'ios') {
    return false;
  }
  try {
    const result = await NativeModule!.setMockPaymentsEnabled(enabled);
    console.log('[ApplePay RN] setMockPaymentsEnabled result:', result);
    return result.success === true;
  } catch (error: unknown) {
    console.warn('[ApplePay RN] Failed to set mock payments:', error);
    return false;
  }
}

// =============================================================================
// PUBLIC API INTERFACE
// =============================================================================

export interface ApplePayInterface {
  // Backend Mode (Recommended)
  makePaymentWithBackendData(
    backendData: ApplePayBackendData
  ): Promise<ApplePayTokenResult>;
  requestTokenWithBackendData(
    backendData: ApplePayBackendData
  ): Promise<ApplePayTokenResult>;

  // SDK Mode (Backwards Compatible)
  canMakePayments(): Promise<boolean>;
  canRequestRecurringToken(): Promise<boolean>;
  initEverypayPayment(config: InitRequest): Promise<InitResult>;
  startApplePayPayment(paymentRequest: PaymentRequest): Promise<PaymentResult>;
  setMockPaymentsEnabled(enabled: boolean): Promise<boolean>;
}

// Create and export the module
const ApplePay: ApplePayInterface =
  Platform.OS === 'ios'
    ? {
        // Backend Mode
        makePaymentWithBackendData,
        requestTokenWithBackendData,

        // SDK Mode
        canMakePayments,
        canRequestRecurringToken,
        initEverypayPayment,
        startApplePayPayment,
        setMockPaymentsEnabled,
      }
    : {
        // Non-iOS platform stubs
        makePaymentWithBackendData: () =>
          Promise.resolve({} as ApplePayTokenResult),
        requestTokenWithBackendData: () =>
          Promise.resolve({} as ApplePayTokenResult),
        canMakePayments: () => Promise.resolve(false),
        canRequestRecurringToken: () => Promise.resolve(false),
        initEverypayPayment: () => Promise.resolve({} as InitResult),
        startApplePayPayment: () => Promise.resolve({} as PaymentResult),
        setMockPaymentsEnabled: () => Promise.resolve(false),
      };

export default ApplePay;

// Export individual functions
export {
  // Backend Mode
  makePaymentWithBackendData,
  requestTokenWithBackendData,

  // SDK Mode
  canMakePayments,
  canRequestRecurringToken,
  initEverypayPayment,
  startApplePayPayment,
  setMockPaymentsEnabled,
};
