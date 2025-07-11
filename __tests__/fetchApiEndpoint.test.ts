import { fetchEverypayApiEndpoints } from '../src/payment/utils/fetchEverypayApiEndpoint';
import {
  API_PAYMENT_SESSION_PATH,
  API_AUTHORIZE_PAYMENT_PATH,
  API_PAYMENT_DETAIL_PATH
} from '../src/payment/constants/everypayApplePay';

describe('fetchApiEndpoint', () => {
  it('should build correct URLs from payment link', () => {
    const everypayBaseUrl = 'https://example.com';
    const result = fetchEverypayApiEndpoints(everypayBaseUrl);

    expect(result.paymentSessionUrl).toBe(`https://example.com${API_PAYMENT_SESSION_PATH}`);
    expect(result.authorizePaymentUrl).toBe(`https://example.com${API_AUTHORIZE_PAYMENT_PATH}`);
    expect(result.paymentDetailUrl).toBe(`https://example.com${API_PAYMENT_DETAIL_PATH}`);
  });

  it('should throw if payment link is invalid', () => {
    expect(() => fetchEverypayApiEndpoints('invalid-url')).toThrow();
    expect(() => fetchEverypayApiEndpoints('')).toThrow();
  });
});
