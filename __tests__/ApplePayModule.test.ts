// ApplePayModule.test.ts
import { NativeModules } from 'react-native';
import { startApplePayPayment, canMakePayments } from '../src';

describe.skip('ApplePayModule', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('calls native startApplePay with properly structured config', () => {
    // Create config matching your PaymentRequest interface
    const config = {
      auth: {
        apiUsername: 'test-username',
        apiSecret: 'test-secret',
      },
      baseUrl: 'https://merchant.example.com',
      data: {
        accountName: 'EUR3D1',
        paymentReference: 'ref123',
        mobileAccessToken: 'test-token',
        amount: '9.99',
        currencyCode: 'USD',
        countryCode: 'US',
        label: 'Test Item',
      },
    };

    startApplePayPayment(config);
    expect(NativeModules.ApplePayModule.startApplePay).toHaveBeenCalledWith(
      config
    );
  });

  it('checks if device can make Apple Pay payments', async () => {
    // Mock the native module response
    NativeModules.ApplePayModule.canMakePayments.mockResolvedValue(true);

    const result = await canMakePayments();
    expect(result).toBe(true);
    expect(NativeModules.ApplePayModule.canMakePayments).toHaveBeenCalled();
  });
});
