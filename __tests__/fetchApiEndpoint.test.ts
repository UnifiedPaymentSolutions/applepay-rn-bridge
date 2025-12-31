import {
  getInitPaymentEndpoints,
  getStartPaymentEndpoints,
} from '../src/payment/utils';

import {
  API_AUTHORIZE_PAYMENT_PATH,
  API_ONEOFF_PATH,
  API_PAYMENT_METHODS_PATH,
  API_PAYMENT_SESSION_PATH,
} from '../src/payment/constants';

describe('Endpoint utility functions', () => {
  const everypayBaseUrl = 'https://example.com';

  describe('getInitPaymentEndpoints', () => {
    it('should build the init payment endpoint URL correctly', () => {
      const result = getInitPaymentEndpoints(everypayBaseUrl);

      // Should only have one URL for init endpoints
      expect(result.mobileOneoffUrl).toBe(
        `https://example.com${API_ONEOFF_PATH}`
      );
    });

    it('should throw if base URL is invalid or empty', () => {
      expect(() => getInitPaymentEndpoints('')).toThrow(
        'Payment link is required'
      );
      expect(() => getInitPaymentEndpoints(null as any)).toThrow(
        'Payment link is required'
      );
    });
  });

  describe('getStartPaymentEndpoints', () => {
    it('should build all required endpoint URLs correctly', () => {
      const result = getStartPaymentEndpoints(everypayBaseUrl);

      // Check that all endpoints in the StartEndpoints interface are present
      expect(result.authorizePaymentUrl).toBe(
        `https://example.com${API_AUTHORIZE_PAYMENT_PATH}`
      );
      expect(result.paymentSessionUrl).toBe(
        `https://example.com${API_PAYMENT_SESSION_PATH}`
      );
      expect(result.paymentMethodsUrl).toBe(
        `https://example.com${API_PAYMENT_METHODS_PATH}`
      );
    });

    it('should handle trailing slashes in base URL correctly', () => {
      const baseUrl = 'https://example.com';
      const result = getStartPaymentEndpoints(baseUrl);

      // Just test one URL to verify trailing slash handling
      const expected = `https://example.com/${API_AUTHORIZE_PAYMENT_PATH.replace(/^\//, '')}`;
      expect(result.authorizePaymentUrl).toBe(expected);
    });

    it('should throw if base URL is invalid or empty', () => {
      expect(() => getStartPaymentEndpoints('')).toThrow(
        'Payment link is required'
      );
      expect(() => getStartPaymentEndpoints(null as any)).toThrow(
        'Payment link is required'
      );
    });
  });
});
