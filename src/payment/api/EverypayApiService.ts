/**
 * EverypayApiService - HTTP client for EveryPay backend API
 *
 * This service handles all backend communication for SDK Mode.
 * In Backend Mode, the user's backend handles these calls instead.
 */

import {
  API_ONEOFF_PATH,
  API_AUTHORIZE_PAYMENT_PATH,
  API_PAYMENT_METHODS_PATH,
} from '../constants';

// --- Types ---

export interface InitConfig {
  baseUrl: string;
  auth: {
    apiUsername: string;
    apiSecret: string;
  };
  data: {
    accountName: string;
    amount: number;
    orderReference?: string;
    customerUrl?: string;
    locale?: string;
    customerEmail?: string;
    customerIp?: string;
  };
}

export interface InitResponse {
  paymentReference: string;
  mobileAccessToken: string;
  accountName: string;
  apiUsername: string;
  orderReference: string;
  amount: number;
  currencyCode: string;
  paymentState: string;
  originalResponse: Record<string, unknown>;
}

export interface PaymentMethodsConfig {
  baseUrl: string;
  apiUsername: string;
  accountName: string;
  amount: number;
}

export interface PaymentMethodsResponse {
  applePayMerchantIdentifier: string;
  applePayAvailable: boolean;
}

export interface AuthorizeParams {
  authorizeUrl: string;
  accessToken: string;
  paymentReference: string;
  paymentData: Record<string, unknown>;
}

export interface AuthorizeResponse {
  state: string;
  [key: string]: unknown;
}

// --- Helpers ---

/**
 * Creates Basic Auth header value
 */
function createBasicAuthHeader(username: string, secret: string): string {
  const credentials = `${username}:${secret}`;
  const base64 = btoa(credentials);
  return `Basic ${base64}`;
}

/**
 * Generates ISO8601 timestamp
 */
function getISO8601Timestamp(): string {
  return new Date().toISOString().replace(/\.\d{3}Z$/, 'Z');
}

/**
 * Generates UUID v4
 */
function generateUUID(): string {
  return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, (c) => {
    const r = (Math.random() * 16) | 0;
    const v = c === 'x' ? r : (r & 0x3) | 0x8;
    return v.toString(16);
  });
}

/**
 * Formats amount to 2 decimal places
 */
function formatAmount(amount: number): string {
  return amount.toFixed(2);
}

// --- API Service ---

export class EverypayApiService {
  /**
   * Initialize payment with EveryPay backend
   * POST /api/v4/payments/oneoff
   */
  async initializePayment(config: InitConfig): Promise<InitResponse> {
    const { baseUrl, auth, data } = config;
    const url = `${baseUrl}${API_ONEOFF_PATH}`;

    // Prepare request body
    const orderReference =
      data.orderReference || `ios-payment-${generateUUID()}`;

    const body = {
      api_username: auth.apiUsername,
      account_name: data.accountName,
      amount: formatAmount(data.amount),
      order_reference: orderReference,
      nonce: generateUUID(),
      timestamp: getISO8601Timestamp(),
      mobile_payment: true,
      customer_url: data.customerUrl || 'https://example.com/mobile/callback',
      locale: data.locale || 'en',
      customer_ip: data.customerIp || '',
      ...(data.customerEmail && { customer_email: data.customerEmail }),
    };

    console.log(`[EverypayApiService] Sending init request to: ${url}`);

    const response = await fetch(url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json; charset=utf-8',
        Accept: 'application/json',
        Authorization: createBasicAuthHeader(auth.apiUsername, auth.apiSecret),
      },
      body: JSON.stringify(body),
    });

    if (!response.ok) {
      const errorBody = await response.text();
      console.error(
        `[EverypayApiService] Init failed with HTTP ${response.status}: ${errorBody}`
      );
      throw new Error(`Init failed with HTTP status ${response.status}`);
    }

    const jsonResponse = await response.json();
    console.log('[EverypayApiService] Init response received');

    // Validate required fields
    if (
      !jsonResponse.payment_reference ||
      !jsonResponse.mobile_access_token
    ) {
      console.error(
        '[EverypayApiService] Missing required fields in init response'
      );
      throw new Error(
        'Missing required fields in init response: payment_reference or mobile_access_token'
      );
    }

    // Map response to our interface
    return {
      paymentReference: jsonResponse.payment_reference,
      mobileAccessToken: jsonResponse.mobile_access_token,
      accountName: jsonResponse.account_name,
      apiUsername: jsonResponse.api_username,
      orderReference: jsonResponse.order_reference,
      amount: parseFloat(jsonResponse.standing_amount),
      currencyCode: jsonResponse.currency,
      paymentState: jsonResponse.payment_state,
      originalResponse: jsonResponse,
    };
  }

  /**
   * Get payment methods including Apple Pay merchant identifier
   * GET /api/v4/sdk/payment_methods/{account_name}
   */
  async getPaymentMethods(config: PaymentMethodsConfig): Promise<PaymentMethodsResponse> {
    const { baseUrl, apiUsername, accountName, amount } = config;
    const url = `${baseUrl}${API_PAYMENT_METHODS_PATH}/${accountName}?api_username=${apiUsername}&amount=${formatAmount(amount)}`;

    console.log(`[EverypayApiService] Fetching payment methods from: ${url}`);

    const response = await fetch(url, {
      method: 'GET',
      headers: {
        Accept: 'application/json',
      },
    });

    if (!response.ok) {
      const errorBody = await response.text();
      console.error(
        `[EverypayApiService] Payment methods request failed with HTTP ${response.status}: ${errorBody}`
      );
      throw new Error(`Payment methods request failed with HTTP status ${response.status}`);
    }

    const jsonResponse = await response.json();
    console.log('[EverypayApiService] Payment methods response received');

    // Find Apple Pay entry in payment_methods array
    const paymentMethods = jsonResponse.payment_methods || [];
    const applePayMethod = paymentMethods.find(
      (method: { source: string }) => method.source === 'apple_pay'
    );

    if (!applePayMethod) {
      throw new Error('Apple Pay is not available for this account');
    }

    if (!applePayMethod.ios_identifier) {
      throw new Error('Apple Pay merchant identifier (ios_identifier) not found in response');
    }

    console.log(`[EverypayApiService] Apple Pay merchant ID: ${applePayMethod.ios_identifier}`);

    return {
      applePayMerchantIdentifier: applePayMethod.ios_identifier,
      applePayAvailable: applePayMethod.available === true,
    };
  }

  /**
   * Authorize payment with Apple Pay token
   * POST /api/v4/apple_pay/payment_data
   */
  async authorizePayment(params: AuthorizeParams): Promise<AuthorizeResponse> {
    const { authorizeUrl, accessToken, paymentReference, paymentData } = params;

    const body = {
      payment_reference: paymentReference,
      ios_app: true,
      paymentData: paymentData,
    };

    console.log(`[EverypayApiService] Sending authorization request to: ${authorizeUrl}`);

    const response = await fetch(authorizeUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json; charset=utf-8',
        Accept: 'application/json',
        Authorization: `Bearer ${accessToken}`,
      },
      body: JSON.stringify(body),
    });

    if (!response.ok) {
      const errorBody = await response.text();
      console.error(
        `[EverypayApiService] Authorization failed with HTTP ${response.status}: ${errorBody}`
      );
      throw new Error(
        `Authorization failed with HTTP status ${response.status}`
      );
    }

    const jsonResponse = await response.json();
    console.log(
      `[EverypayApiService] Authorization response received with state: ${jsonResponse.state}`
    );

    return jsonResponse as AuthorizeResponse;
  }
}

// Export singleton instance
export const everypayApiService = new EverypayApiService();
