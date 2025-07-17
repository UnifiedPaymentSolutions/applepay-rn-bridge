import {
  API_AUTHORIZE_PAYMENT_PATH,
  API_ONEOFF_PATH,
  API_PAYMENT_METHODS_PATH,
  API_PAYMENT_SESSION_PATH,
} from '../constants';
import { InitEndpoints, StartEndpoints } from '../types';

export function getInitPaymentEndpoints(everypayBaseUrl: string): InitEndpoints {
  if (!everypayBaseUrl) {
    throw new Error('Payment link is required');
  }

  try {
    return {
      mobileOneoffUrl: `${everypayBaseUrl}${API_ONEOFF_PATH}`,
    };
  } catch (error) {
    throw new Error(`Invalid payment link: ${everypayBaseUrl}` + error);
  }
}

export function getStartPaymentEndpoints(everypayBaseUrl: string): StartEndpoints {
  if (!everypayBaseUrl) {
    throw new Error('Payment link is required');
  }

  try {
    return {
      paymentSessionUrl: `${everypayBaseUrl}${API_PAYMENT_SESSION_PATH}`,
      authorizePaymentUrl: `${everypayBaseUrl}${API_AUTHORIZE_PAYMENT_PATH}`,
      paymentMethodsUrl: `${everypayBaseUrl}${API_PAYMENT_METHODS_PATH}`,
      mobileOneoffUrl: `${everypayBaseUrl}${API_ONEOFF_PATH}`,
    };
  } catch (error) {
    throw new Error(`Invalid payment link: ${everypayBaseUrl}` + error);
  }
}
