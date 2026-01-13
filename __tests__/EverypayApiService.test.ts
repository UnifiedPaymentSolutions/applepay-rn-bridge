import { EverypayApiService } from '../src/payment/api/EverypayApiService';

// Mock fetch globally
const mockFetch = jest.fn();
global.fetch = mockFetch;

describe('EverypayApiService', () => {
  let service: EverypayApiService;

  beforeEach(() => {
    service = new EverypayApiService();
    mockFetch.mockClear();
    jest.spyOn(console, 'log').mockImplementation(() => {});
    jest.spyOn(console, 'error').mockImplementation(() => {});
  });

  afterEach(() => {
    jest.restoreAllMocks();
  });

  describe('initializePayment', () => {
    const validConfig = {
      baseUrl: 'https://api.example.com',
      auth: {
        apiUsername: 'test-user',
        apiSecret: 'test-secret',
      },
      data: {
        accountName: 'EUR3D1',
        amount: 10.99,
        orderReference: 'order-123',
      },
    };

    const mockSuccessResponse = {
      payment_reference: 'pay-ref-123',
      mobile_access_token: 'token-abc',
      account_name: 'EUR3D1',
      api_username: 'test-user',
      order_reference: 'order-123',
      standing_amount: '10.99',
      currency: 'EUR',
      payment_state: 'initial',
    };

    it('should successfully initialize payment', async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: async () => mockSuccessResponse,
      });

      const result = await service.initializePayment(validConfig);

      expect(result.paymentReference).toBe('pay-ref-123');
      expect(result.mobileAccessToken).toBe('token-abc');
      expect(result.accountName).toBe('EUR3D1');
      expect(result.currencyCode).toBe('EUR');
      expect(result.amount).toBe(10.99);
    });

    it('should send correct request body', async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: async () => mockSuccessResponse,
      });

      await service.initializePayment(validConfig);

      expect(mockFetch).toHaveBeenCalledWith(
        'https://api.example.com/api/v4/payments/oneoff',
        expect.objectContaining({
          method: 'POST',
          headers: expect.objectContaining({
            'Content-Type': 'application/json; charset=utf-8',
            'Accept': 'application/json',
          }),
        })
      );

      const requestBody = JSON.parse(mockFetch.mock.calls[0][1].body);
      expect(requestBody.api_username).toBe('test-user');
      expect(requestBody.account_name).toBe('EUR3D1');
      expect(requestBody.amount).toBe('10.99');
      expect(requestBody.order_reference).toBe('order-123');
      expect(requestBody.mobile_payment).toBe(true);
    });

    it('should generate order reference if not provided', async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: async () => mockSuccessResponse,
      });

      const configWithoutOrderRef = {
        ...validConfig,
        data: { ...validConfig.data, orderReference: undefined },
      };

      await service.initializePayment(configWithoutOrderRef);

      const requestBody = JSON.parse(mockFetch.mock.calls[0][1].body);
      expect(requestBody.order_reference).toMatch(/^ios-payment-/);
    });

    it('should throw error on HTTP failure', async () => {
      mockFetch.mockResolvedValueOnce({
        ok: false,
        status: 400,
        text: async () => 'Bad Request',
      });

      await expect(service.initializePayment(validConfig)).rejects.toThrow(
        'Init failed with HTTP status 400'
      );
    });

    it('should throw error when payment_reference is missing', async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({ mobile_access_token: 'token' }),
      });

      await expect(service.initializePayment(validConfig)).rejects.toThrow(
        'Missing required fields in init response'
      );
    });

    it('should throw error when mobile_access_token is missing', async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({ payment_reference: 'ref' }),
      });

      await expect(service.initializePayment(validConfig)).rejects.toThrow(
        'Missing required fields in init response'
      );
    });

    it('should include optional customer fields when provided', async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: async () => mockSuccessResponse,
      });

      const configWithOptionals = {
        ...validConfig,
        data: {
          ...validConfig.data,
          customerEmail: 'test@example.com',
          customerIp: '192.168.1.1',
          locale: 'et',
          customerUrl: 'https://custom.url/callback',
        },
      };

      await service.initializePayment(configWithOptionals);

      const requestBody = JSON.parse(mockFetch.mock.calls[0][1].body);
      expect(requestBody.customer_email).toBe('test@example.com');
      expect(requestBody.customer_ip).toBe('192.168.1.1');
      expect(requestBody.locale).toBe('et');
      expect(requestBody.customer_url).toBe('https://custom.url/callback');
    });
  });

  describe('getPaymentMethods', () => {
    const validConfig = {
      baseUrl: 'https://api.example.com',
      apiUsername: 'test-user',
      accountName: 'EUR3D1',
      amount: 10.99,
    };

    it('should successfully get payment methods', async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({
          payment_methods: [
            {
              source: 'apple_pay',
              ios_identifier: 'merchant.com.example',
              available: true,
            },
          ],
        }),
      });

      const result = await service.getPaymentMethods(validConfig);

      expect(result.applePayMerchantIdentifier).toBe('merchant.com.example');
      expect(result.applePayAvailable).toBe(true);
    });

    it('should construct correct URL with query params', async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({
          payment_methods: [
            { source: 'apple_pay', ios_identifier: 'merchant.id', available: true },
          ],
        }),
      });

      await service.getPaymentMethods(validConfig);

      expect(mockFetch).toHaveBeenCalledWith(
        'https://api.example.com/api/v4/sdk/payment_methods/EUR3D1?api_username=test-user&amount=10.99',
        expect.objectContaining({
          method: 'GET',
        })
      );
    });

    it('should throw error when Apple Pay is not available', async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({
          payment_methods: [{ source: 'card', available: true }],
        }),
      });

      await expect(service.getPaymentMethods(validConfig)).rejects.toThrow(
        'Apple Pay is not available for this account'
      );
    });

    it('should throw error when ios_identifier is missing', async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({
          payment_methods: [{ source: 'apple_pay', available: true }],
        }),
      });

      await expect(service.getPaymentMethods(validConfig)).rejects.toThrow(
        'Apple Pay merchant identifier (ios_identifier) not found'
      );
    });

    it('should throw error on HTTP failure', async () => {
      mockFetch.mockResolvedValueOnce({
        ok: false,
        status: 404,
        text: async () => 'Not Found',
      });

      await expect(service.getPaymentMethods(validConfig)).rejects.toThrow(
        'Payment methods request failed with HTTP status 404'
      );
    });

    it('should handle empty payment_methods array', async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({ payment_methods: [] }),
      });

      await expect(service.getPaymentMethods(validConfig)).rejects.toThrow(
        'Apple Pay is not available for this account'
      );
    });
  });

  describe('authorizePayment', () => {
    const validParams = {
      authorizeUrl: 'https://api.example.com/api/v4/apple_pay/payment_data',
      accessToken: 'access-token-123',
      paymentReference: 'pay-ref-123',
      paymentData: { token: 'apple-pay-token-data' },
    };

    it('should successfully authorize payment', async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({ state: 'completed', transaction_id: 'txn-123' }),
      });

      const result = await service.authorizePayment(validParams);

      expect(result.state).toBe('completed');
      expect(result.transaction_id).toBe('txn-123');
    });

    it('should send correct request body and headers', async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({ state: 'completed' }),
      });

      await service.authorizePayment(validParams);

      expect(mockFetch).toHaveBeenCalledWith(
        validParams.authorizeUrl,
        expect.objectContaining({
          method: 'POST',
          headers: expect.objectContaining({
            'Content-Type': 'application/json; charset=utf-8',
            'Accept': 'application/json',
            'Authorization': 'Bearer access-token-123',
          }),
        })
      );

      const requestBody = JSON.parse(mockFetch.mock.calls[0][1].body);
      expect(requestBody.payment_reference).toBe('pay-ref-123');
      expect(requestBody.ios_app).toBe(true);
      expect(requestBody.paymentData).toEqual({ token: 'apple-pay-token-data' });
    });

    it('should throw error on HTTP failure', async () => {
      mockFetch.mockResolvedValueOnce({
        ok: false,
        status: 401,
        text: async () => 'Unauthorized',
      });

      await expect(service.authorizePayment(validParams)).rejects.toThrow(
        'Authorization failed with HTTP status 401'
      );
    });
  });
});
