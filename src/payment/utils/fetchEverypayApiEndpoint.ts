import {
  API_PAYMENT_SESSION_PATH,
  API_AUTHORIZE_PAYMENT_PATH,
  API_PAYMENT_DETAIL_PATH
} from '../constants/everypayApplePay';

export interface ApiEndpoints {
  paymentSessionUrl: string;
  authorizePaymentUrl: string;
  paymentDetailUrl: string;
}

export function fetchEverypayApiEndpoints(everypayBaseUrl: string): ApiEndpoints {
  if (!everypayBaseUrl) {
    throw new Error('Payment link is required');
  }
  
  try {
    const origin = new URL(everypayBaseUrl);
    
    return {
      paymentSessionUrl: `${everypayBaseUrl}${API_PAYMENT_SESSION_PATH}`,
      authorizePaymentUrl: `${everypayBaseUrl}${API_AUTHORIZE_PAYMENT_PATH}`,
      paymentDetailUrl: `${everypayBaseUrl}${API_PAYMENT_DETAIL_PATH}`,
    };
  } catch (error) {
    throw new Error(`Invalid payment link: ${everypayBaseUrl}` + error);
  }
}
