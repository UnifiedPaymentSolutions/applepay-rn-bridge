import { Platform } from 'react-native';

// This file should never be imported on iOS due to platform-specific file resolution
// React Native will automatically use .android.ts files on Android and .ios.ts files on iOS

const throwAndroidError = () => {
  throw new Error(
    '@everypay/applepay-rn-bridge is not supported on Android. ' +
    'This library provides Apple Pay functionality which is only available on iOS devices. ' +
    'Please use this library only in iOS applications or implement platform-specific code to handle Android separately.'
  );
};

export interface ApplePayInterface {
  canMakePayments(): Promise<boolean>;
  initEverypayPayment(initRequest: any): Promise<any>;
  startApplePayPayment(paymentRequest: any): Promise<any>;
  startApplePayWithLateEverypayInit(config: any): Promise<any>;
  setMockPaymentsEnabled(enabled: boolean): Promise<boolean>;
}

const ApplePay: ApplePayInterface = {
  canMakePayments: throwAndroidError,
  initEverypayPayment: throwAndroidError,
  startApplePayPayment: throwAndroidError,
  startApplePayWithLateEverypayInit: throwAndroidError,
  setMockPaymentsEnabled: throwAndroidError,
};

export default ApplePay;
export { throwAndroidError as canMakePayments, throwAndroidError as startApplePayPayment, throwAndroidError as initEverypayPayment, throwAndroidError as startApplePayWithLateEverypayInit, throwAndroidError as setMockPaymentsEnabled };
