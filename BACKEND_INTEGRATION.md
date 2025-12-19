# Backend Integration Guide

This guide explains how to implement the backend for Apple Pay integration using the **Backend Mode** (recommended approach).

## Overview

In Backend Mode:

- **Backend** makes all EveryPay API calls (keeps credentials secure)
- **React Native app** only handles Apple Pay UI
- **Security**: API credentials never leave your backend

## Architecture

```
1. Create Payment:
   React Native App → Backend → EveryPay API
                                  ↓
                          (payment reference + merchant ID)
                                  ↓
   React Native App ← Backend ← EveryPay

2. Show Apple Pay:
   React Native App → Apple Pay UI
                           ↓
                      (user pays)
                           ↓
   React Native App ← Token

3. Process Payment:
   React Native App → Backend → EveryPay API
      (with token)              (process token)
                                  ↓
   React Native App ← Backend ← Result
```

## Required Backend Endpoints

Your backend needs to implement two endpoints:

### 1. Create Payment: `POST /api/applepay/create-payment`

Initializes the payment and fetches the Apple Pay merchant identifier from EveryPay (combines `payments/oneoff` and `payment_methods` API calls).

**Request Body:**

```json
{
  "amount": 10.50,
  "label": "Product Purchase",
  "orderReference": "ORDER-123",
  "customerEmail": "customer@example.com",
  "customerIp": "192.168.1.1"
}
```

**Backend Implementation:**

```javascript
app.post('/api/applepay/create-payment', async (req, res) => {
  const { amount, label, orderReference, customerEmail, customerIp } = req.body;

  try {
    // 1. Get payment methods to retrieve Apple Pay merchant identifier
    const methodsResponse = await fetch(
      `${EVERYPAY_API_URL}/api/v4/sdk/payment_methods/${ACCOUNT_NAME}?api_username=${API_USERNAME}&amount=${amount.toFixed(2)}`,
      {
        method: 'GET',
        headers: {
          'Accept': 'application/json',
        },
      }
    );

    const methodsData = await methodsResponse.json();
    const applePayMethod = methodsData.payment_methods.find(m => m.source === 'apple_pay');

    if (!applePayMethod || !applePayMethod.ios_identifier) {
      throw new Error('Apple Pay not available for this account');
    }

    // 2. Create payment
    const paymentResponse = await fetch(
      `${EVERYPAY_API_URL}/api/v4/payments/oneoff`,
      {
        method: 'POST',
        headers: {
          'Authorization': `Basic ${Buffer.from(`${API_USERNAME}:${API_SECRET}`).toString('base64')}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          api_username: API_USERNAME,
          account_name: ACCOUNT_NAME,
          amount: amount.toFixed(2),
          order_reference: orderReference,
          nonce: generateNonce(),
          timestamp: new Date().toISOString(),
          mobile_payment: true,
          customer_url: CUSTOMER_URL,
          customer_ip: customerIp || '',
          customer_email: customerEmail,
        }),
      }
    );

    const paymentData = await paymentResponse.json();

    // 3. Combine data for app
    res.json({
      merchantIdentifier: applePayMethod.ios_identifier,
      merchantName: MERCHANT_NAME,
      amount: parseFloat(paymentData.standing_amount),
      currencyCode: paymentData.currency,
      countryCode: paymentData.descriptor_country || 'EE',
      paymentReference: paymentData.payment_reference,
      mobileAccessToken: paymentData.mobile_access_token,
      authorizePaymentUrl: `${EVERYPAY_API_URL}/api/v4/apple_pay/payment_data`,
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});
```

**Response:**

```json
{
  "merchantIdentifier": "merchant.com.yourcompany.app",
  "merchantName": "Your Store",
  "amount": 10.50,
  "currencyCode": "EUR",
  "countryCode": "EE",
  "paymentReference": "abc123...",
  "mobileAccessToken": "xyz789...",
  "authorizePaymentUrl": "https://payment.sandbox.lhv.ee/api/v4/apple_pay/payment_data"
}
```

### 2. Process Token: `POST /api/applepay/process-token`

Processes the Apple Pay token received from the app.

**Request Body:**

```json
{
  "paymentReference": "abc123...",
  "mobileAccessToken": "xyz789...",
  "paymentData": "eyJhbGciOiJSU0EtT0FFUC0yNTYi...",
  "transactionIdentifier": "ABC123DEF456..."
}
```

**Backend Implementation:**

```javascript
app.post('/api/applepay/process-token', async (req, res) => {
  const {
    paymentReference,
    mobileAccessToken,
    paymentData,
    transactionIdentifier,
  } = req.body;

  try {
    // Decode base64 payment data
    const decodedPaymentData = JSON.parse(
      Buffer.from(paymentData, 'base64').toString('utf8')
    );

    // Process payment with EveryPay
    const processResponse = await fetch(
      `${EVERYPAY_API_URL}/api/v4/apple_pay/payment_data`,
      {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${mobileAccessToken}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          payment_reference: paymentReference,
          ios_app: true,
          paymentData: decodedPaymentData,
        }),
      }
    );

    const result = await processResponse.json();

    // Check payment state
    if (result.state === 'settled' || result.state === 'authorized' || result.state === 'completed') {
      res.json({
        success: true,
        state: result.state,
        paymentReference: paymentReference,
      });
    } else {
      res.status(400).json({
        success: false,
        state: result.state,
        error: `Payment failed with state: ${result.state}`,
      });
    }
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

function generateNonce() {
  return require('crypto').randomBytes(16).toString('hex');
}
```

**Response (Success):**

```json
{
  "success": true,
  "state": "settled",
  "paymentReference": "abc123..."
}
```

**Response (Failure):**

```json
{
  "success": false,
  "state": "failed",
  "error": "Payment failed with state: failed"
}
```

## EveryPay API Reference

| Endpoint | Method | Auth | Purpose |
|----------|--------|------|---------|
| `/api/v4/sdk/payment_methods/{account}` | GET | Query params | Get Apple Pay merchant ID |
| `/api/v4/payments/oneoff` | POST | Basic Auth | Create payment reference |
| `/api/v4/apple_pay/payment_data` | POST | Bearer Token | Process Apple Pay token |

### API Details

#### Get Payment Methods

```
GET /api/v4/sdk/payment_methods/{account_name}?api_username={username}&amount={amount}

Response:
{
  "payment_methods": [
    {
      "source": "apple_pay",
      "ios_identifier": "merchant.com.example.app",
      "available": true
    }
  ]
}
```

#### Create Payment (oneoff)

```
POST /api/v4/payments/oneoff
Authorization: Basic {base64(username:secret)}
Content-Type: application/json

Body:
{
  "api_username": "YOUR_USERNAME",
  "account_name": "EUR3D1",
  "amount": "10.50",
  "order_reference": "ORDER-123",
  "nonce": "random_hex_string",
  "timestamp": "2024-01-01T00:00:00Z",
  "mobile_payment": true,
  "customer_url": "https://example.com/callback",
  "customer_ip": "192.168.1.1",
  "customer_email": "customer@example.com"
}

Response:
{
  "payment_reference": "abc123...",
  "mobile_access_token": "xyz789...",
  "standing_amount": "10.50",
  "currency": "EUR",
  "descriptor_country": "EE",
  "payment_state": "initial"
}
```

#### Process Apple Pay Token

```
POST /api/v4/apple_pay/payment_data
Authorization: Bearer {mobileAccessToken}
Content-Type: application/json

Body:
{
  "payment_reference": "abc123...",
  "ios_app": true,
  "paymentData": {
    // Decoded Apple Pay token JSON
  }
}

Response:
{
  "state": "settled",
  "payment_reference": "abc123...",
  ...
}
```

## Troubleshooting

### "Apple Pay not available for this account"

- Ensure Apple Pay is configured in EveryPay merchant portal
- Verify the merchant identifier matches your Apple Developer setup

### "Payment reference required"

- Ensure create-payment endpoint returns `paymentReference`

### "Invalid token"

- Verify token data is decoded correctly from base64
- Check that `ios_app: true` is included in the request

### "Authentication failed"

- Verify API credentials on backend
- Check Authorization header format (Basic vs Bearer)

### "Payment already processed"

- Payment references are single-use
- Create new payment for each transaction

## Security Best Practices

1. **Never expose API credentials** in the mobile app
2. **Validate all inputs** on your backend
3. **Use HTTPS** for all backend communications
4. **Implement rate limiting** on backend endpoints
5. **Log security events** on backend
6. **Store tokens securely** - mobileAccessToken is sensitive

## Additional Resources

- [EveryPay API Documentation](https://support.every-pay.com/api-documentation/)
- [Apple Pay Programming Guide](https://developer.apple.com/apple-pay/)
- [Apple Pay Sandbox Testing](https://developer.apple.com/apple-pay/sandbox-testing/)
