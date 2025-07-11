import { NativeEventEmitter, NativeModules } from 'react-native';

let emitter: NativeEventEmitter | null = null;

export const getApplePayEmitter = (): NativeEventEmitter => {
  if (!emitter) {
    emitter = new NativeEventEmitter(NativeModules.ApplePayModule);
    console.log('[ApplePay] Emitter initialized in app');
  }
  return emitter;
};

export const onApplePaySuccess = (eventEmitter:NativeEventEmitter, callback: (event: any) => void) => {
  if (!eventEmitter) {
    console.error('[ApplePay] Emitter not available');
    return null;
  }
  return eventEmitter.addListener('onPaymentSuccess', callback);
};

export const onApplePayFailed = (eventEmitter:NativeEventEmitter, callback: (event: any) => void) => {
  if (!eventEmitter) {
    console.error('[ApplePay] Emitter not available');
    return null;
  }
  return eventEmitter.addListener('onPaymentFailed', callback);
};