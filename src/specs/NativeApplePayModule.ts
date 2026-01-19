import type { TurboModule } from 'react-native';
import { TurboModuleRegistry } from 'react-native';

/**
 * Configuration for the native SDK wrapper.
 * Used to configure the Apple Pay sheet.
 */
export interface ConfigureRequest {
  amount: number;
  merchantIdentifier: string;
  merchantName: string;
  currencyCode: string;
  countryCode: string;
  recurring?: {
    description: string;
    managementURL: string;
    billingLabel?: string;
    billingAgreement?: string;
  };
}

/**
 * Payment method information from Apple Pay
 */
export interface PaymentMethodInfo {
  displayName: string;
  network: string;
  type: number;
}

/**
 * Result from native presentPayment method.
 * Contains serialized Apple Pay token.
 */
export interface NativeTokenResult {
  success: boolean;
  paymentData: string;
  transactionIdentifier: string;
  paymentMethod: PaymentMethodInfo;
}

/**
 * Result from setMockPaymentsEnabled
 */
export interface MockPaymentResult {
  success: boolean;
  reason?: string;
}

/**
 * Result from configure method
 */
export interface ConfigureResult {
  success: boolean;
}

/**
 * TurboModule spec for ApplePayModule
 * This spec is used by React Native Codegen to generate native interfaces.
 */
export interface Spec extends TurboModule {
  /**
   * Check if Apple Pay is available on this device
   */
  canMakePayments(): Promise<boolean>;

  /**
   * Check if device supports recurring payment tokens (iOS 16+)
   */
  canRequestRecurringToken(): Promise<boolean>;

  /**
   * Configure the SDK before presenting payment sheet
   */
  configure(config: Object): Promise<Object>;

  /**
   * Present Apple Pay sheet and return serialized token
   */
  presentPayment(): Promise<Object>;

  /**
   * Enable/disable mock payments (debug builds only)
   */
  setMockPaymentsEnabled(enabled: boolean): Promise<Object>;
}

export default TurboModuleRegistry.getEnforcing<Spec>('ApplePayModule');
