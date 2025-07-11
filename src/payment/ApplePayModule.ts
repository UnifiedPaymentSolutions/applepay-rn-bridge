import {
  NativeModules
} from 'react-native';
import {
  InitAndStartPaymentInput,
  InitPaymentInput,
  InitPaymentOutput,
  PaymentOutput,
  StartPaymentInput
} from './types/payment';

const { ApplePayModule } = NativeModules;

if (!ApplePayModule) {
  console.warn('⚠️ ApplePayModule is not available. Check native linking and iOS build.');
}

// 🟩 Start Apple Pay directly (e.g. after init done separately)
export const startApplePay = (config: StartPaymentInput): Promise<void> => {
  if (!ApplePayModule) {
    console.error('ApplePayModule is not available. Are you running on iOS?');
    return Promise.reject(new Error('ApplePayModule not available'));
  }
  try {
    ApplePayModule.startPayment(config);
    return Promise.resolve();
  }
  catch (error) {
    return Promise.reject(error);
  }
}

// 🟩 Init Apple Pay without starting payment
export const initApplePay = (config: InitPaymentInput): Promise<InitPaymentOutput> => {
  if (!ApplePayModule) {
    return Promise.reject({
      success: false,
      errorMessage: 'ApplePayModule not available. Are you running on iOS?',
    });
  }

  return ApplePayModule.initPayment(config);
}

// 🟩 Init and then start in one go
export const initAndStartApplePay = (config: InitAndStartPaymentInput): Promise<PaymentOutput> => {
  if (!ApplePayModule) {
    return Promise.reject({
      success: false,
      status: 'native_module_unavailable',
      message: 'ApplePayModule not available. Are you running on iOS?',
    });
  }

  return ApplePayModule.initAndStartPayment(config);
}

// 🟩 Check availability
export const canMakeApplePay = (): Promise<boolean> => {
  if (!ApplePayModule) {
    return Promise.resolve(false);
  }

  return ApplePayModule.canMakePayments();
}
