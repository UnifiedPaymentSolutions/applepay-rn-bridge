// ApplePayModule.test.ts
import { NativeModules } from 'react-native';
import { startApplePay, canMakeApplePay } from '../src/payment/ApplePayModule';

describe('ApplePayModule', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('calls native startPayment with config', () => {
    const config = {
      paymentReference: 'ref123',
      paymentLink: 'https://merchant.example.com/pay/1',
      countryCode: 'US',
      currencyCode: 'USD',
      amount: '9.99',
      label: 'Test Item',
      paymentSessionUrl: 'https://merchant.example.com/api/v4/apple_pay/payment_session',
      authorizePaymentUrl: 'https://merchant.example.com/api/v4/apple_pay/payment_data',
      paymentDetailUrl: 'https://merchant.example.com/api/v4/apple_pay/link_data',
      merchantId: 'merchant.com.test',
      version: 12,
      accessToken: 'test-token',
      apiUsername: 'test-username',
    };
    
    startApplePay(config);
    expect(NativeModules.ApplePayModule.startPayment).toHaveBeenCalledWith(config);
  });

  it('checks if device can make Apple Pay payments', async () => {
    const result = await canMakeApplePay();
    expect(result).toBe(true);
    expect(NativeModules.ApplePayModule.canMakePayments).toHaveBeenCalled();
  });
});