# @everypay/applepay-rn-bridge

EveryPay Apple Pay React Native Bridge (iOS Only).

- **Backend Mode** (recommended): Keep API credentials secure on your backend
- **SDK Integration**: Built on EveryPay Apple Pay iOS SDK
- **Enhanced Security**: API credentials never exposed in mobile app
- **Dual Mode Support**: Backend Mode (recommended) + SDK Mode

## Requirements

- React Native >= 0.60 (for autolinking)
- iOS >= 15.0
- Xcode >= 14
- CocoaPods
- Apple Developer account with Apple Pay configured (Merchant ID)
- EverypayApplePay SDK (local path until published)

## Installation

1. **Add the package to your project:**

   ```bash
   npm install @everypay/applepay-rn-bridge
   # or
   yarn add @everypay/applepay-rn-bridge
   ```

2. **Add EverypayApplePay SDK to your Podfile:**

   Since the SDK is not yet published to CocoaPods, add a local path reference in your app's `ios/Podfile`:

   ```ruby
   pod 'EverypayApplePay', :path => '../path/to/everypay-applepay-sdk-client/EverypayApplePay'
   ```

3. **Install Native Dependencies:**

   ```bash
   cd ios
   pod install
   ```

## Apple Pay Setup

Before using this library, you need to configure Apple Pay in your project:

### 1. Apple Developer Account Setup

1. Log in to your [Apple Developer Account](https://developer.apple.com)
2. Go to **Certificates, Identifiers & Profiles**
3. Create a **Merchant ID**:
   - Navigate to **Identifiers** → **Merchant IDs**
   - Click **+** to create a new Merchant ID
   - Enter an identifier (e.g., `merchant.com.yourcompany.app`)
   - Enter a description

### 2. EveryPay Setup

When the payment processor handles decryption, they need to generate the cryptographic keys and provide the public key via a Certificate Signing Request (CSR) to the merchant. The merchant will then upload this CSR to the Apple Developer portal. In return, Apple will provide the merchant a certificate which the payment processor will need to import.

**Merchant actions:**
1. Login to the Everypay Merchant portal and open E-Shop Settings → select shop → Apple Pay (in apps). To the "Apple Pay Merchant Indentifier" field enter the identifier you created in step 1 and register it.
2. Download the "Payment Processing Certificate CSR" from the same block.
3. Log in to the [Apple Developer Portal](https://developer.apple.com)
4. Navigate to **Certificates, Identifiers & Profiles** > **Certificates**
5. Add new certificate and select **Apple Pay Payment Processing Certificate**
6. Select the merchant ID created in the previous step ("Apple Developer Account Setup")
7. Under the **Apple Pay Payment Processing Certificate** click "Create Certificate" and upload the CSR file provided by Paytech/EveryPay
8. Download the generated certificate (.cer file) from Apple Developer portal
9. Upload the downloaded certificate to the Everypay Merchant portal under **E-Shop Settings** → select shop → **Apple Pay (in apps)** → **Upload Certificate**

### 3. Xcode Project Configuration

1. Open your project in Xcode
2. Select your target
3. Go to **Signing & Capabilities**
4. Click **+ Capability** and add **Apple Pay**
5. Select the Merchant ID you created

### 4. Entitlements

Xcode will automatically add the Apple Pay entitlement to your project. Verify that your entitlements file contains:

```xml
<key>com.apple.developer.in-app-payments</key>
<array>
    <string>merchant.com.yourcompany.app</string>
</array>
```

## Quick Start

### Backend Mode (Recommended)

Most secure approach - API credentials stay on your backend.

**Step 1:** Implement backend endpoints that call EveryPay API:
- `POST /api/applepay/create-payment` - Initialize payment and fetch merchant ID
- `POST /api/applepay/process-token` - Send Apple Pay token to EveryPay

**Step 2:** Use in your app:

```typescript
import ApplePay from '@everypay/applepay-rn-bridge';
import type { ApplePayBackendData } from '@everypay/applepay-rn-bridge';

async function handlePayment() {
  // 1. Check if Apple Pay is available
  const canPay = await ApplePay.canMakePayments();
  if (!canPay) {
    console.log('Apple Pay not available');
    return;
  }

  // 2. Fetch payment data from YOUR backend
  const response = await fetch('https://your-backend.com/api/applepay/create-payment', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ amount: 10.50, orderId: 'order-123' }),
  });
  const backendData: ApplePayBackendData = await response.json();

  // 3. Present Apple Pay sheet and get token
  const tokenResult = await ApplePay.makePaymentWithBackendData(backendData);

  // 4. Send token to YOUR backend for processing
  await fetch('https://your-backend.com/api/applepay/process-token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      paymentReference: tokenResult.paymentReference,
      mobileAccessToken: tokenResult.mobileAccessToken,
      paymentData: tokenResult.paymentData,
      transactionIdentifier: tokenResult.transactionIdentifier,
    }),
  });

  console.log('Payment successful!');
}
```

### SDK Mode

API credentials stored in app (less secure, but simpler setup):

```typescript
import ApplePay from '@everypay/applepay-rn-bridge';

async function handlePayment() {
  const canPay = await ApplePay.canMakePayments();
  if (!canPay) return;

  const result = await ApplePay.startApplePayPayment({
    baseUrl: 'https://payment.sandbox.lhv.ee',  // or production/demo URL
    auth: {
      apiUsername: 'YOUR_API_USERNAME',
      apiSecret: 'YOUR_API_SECRET',
    },
    data: {
      accountName: 'EUR3D1',
      amount: 10.50,
      label: 'Product Purchase',
      currencyCode: 'EUR',
      countryCode: 'EE',
      orderReference: `order-${Date.now()}`,
    },
  });

  console.log('Payment successful:', result.paymentReference);
}
```

## Additional Guides

- **[Custom Button Implementation](./CUSTOM_BUTTON_GUIDE.md)** - Complete guide for implementing Apple Pay with your own custom-styled button, including component code, error handling, and best practices.

## API Reference

### Backend Mode Methods

#### `canMakePayments(): Promise<boolean>`

Check if Apple Pay is available on the device.

```typescript
const available = await ApplePay.canMakePayments();
```

#### `canRequestRecurringToken(): Promise<boolean>`

Check if device supports recurring payment tokens (iOS 16+).

```typescript
const supportsRecurring = await ApplePay.canRequestRecurringToken();
```

#### `makePaymentWithBackendData(backendData: ApplePayBackendData): Promise<ApplePayTokenResult>`

Present Apple Pay sheet with backend-provided data. Returns token for your backend to process.

```typescript
const tokenResult = await ApplePay.makePaymentWithBackendData({
  merchantIdentifier: 'merchant.com.yourcompany',
  merchantName: 'Your Store',
  amount: 10.50,
  currencyCode: 'EUR',
  countryCode: 'EE',
  paymentReference: 'ref_xxx',           // From EveryPay init
  mobileAccessToken: 'token_xxx',        // From EveryPay init
  authorizePaymentUrl: 'https://...',    // EveryPay authorize endpoint
});
```

#### `requestTokenWithBackendData(backendData: ApplePayBackendData): Promise<ApplePayTokenResult>`

Same as `makePaymentWithBackendData` but for recurring payment tokens. Requires `recurring` config.

```typescript
const tokenResult = await ApplePay.requestTokenWithBackendData({
  ...backendData,
  recurring: {
    description: 'Monthly subscription',
    managementURL: 'https://yoursite.com/manage-subscription',
    billingLabel: 'Monthly Fee',
    billingAgreement: 'You agree to be charged monthly.',
  },
});
```

### SDK Mode Methods

#### `initEverypayPayment(config: InitRequest): Promise<InitResult>`

Initialize payment with EveryPay backend (SDK mode only).

```typescript
const initResult = await ApplePay.initEverypayPayment({
  baseUrl: 'https://payment.sandbox.lhv.ee',
  auth: { apiUsername: '...', apiSecret: '...' },
  data: {
    accountName: 'EUR3D1',
    amount: 10.50,
    label: 'Product',
    currencyCode: 'EUR',
    countryCode: 'EE',
  },
});
```

#### `startApplePayPayment(config: PaymentRequest): Promise<PaymentResult>`

Full payment flow - initializes, presents Apple Pay, and authorizes with backend.

```typescript
const result = await ApplePay.startApplePayPayment({
  baseUrl: 'https://payment.sandbox.lhv.ee',
  auth: { apiUsername: '...', apiSecret: '...' },
  data: {
    accountName: 'EUR3D1',
    amount: 10.50,
    label: 'Product',
    currencyCode: 'EUR',
    countryCode: 'EE',
  },
});
```

#### `startApplePayWithLateEverypayInit(config: InitRequest): Promise<PaymentResult>`

Late initialization flow - presents Apple Pay first, then initializes with backend.

### Debug Methods

#### `setMockPaymentsEnabled(enabled: boolean): Promise<boolean>`

Enable/disable mock payments (debug builds only).

## Types

### ApplePayBackendData

Data structure your backend should return:

```typescript
interface ApplePayBackendData {
  merchantIdentifier: string;    // Apple Pay merchant ID (e.g., "merchant.com.example")
  merchantName: string;          // Display name on payment sheet
  amount: number;                // Payment amount
  currencyCode: string;          // ISO 4217 (e.g., "EUR")
  countryCode: string;           // ISO 3166-1 alpha-2 (e.g., "EE")
  paymentReference: string;      // From EveryPay init response
  mobileAccessToken: string;     // From EveryPay init response
  authorizePaymentUrl: string;   // EveryPay authorize endpoint
  recurring?: RecurringConfig;   // Optional recurring payment config
}
```

### ApplePayTokenResult

Token returned from Apple Pay for backend processing:

```typescript
interface ApplePayTokenResult {
  success: boolean;
  paymentData: string;           // Base64 encoded Apple Pay token
  transactionIdentifier: string;
  paymentMethod: {
    displayName: string;         // e.g., "Visa 1234"
    network: string;             // e.g., "Visa"
    type: number;
  };
  paymentReference: string;      // Pass-through from backend data
  mobileAccessToken: string;     // Pass-through from backend data
}
```

### RecurringConfig

Configuration for recurring payment tokens (iOS 16+):

```typescript
interface RecurringConfig {
  description: string;           // Shown in payment sheet
  managementURL: string;         // URL to manage recurring payment
  billingLabel?: string;         // Optional billing item label
  billingAgreement?: string;     // Optional agreement text
}
```

## Backend Integration Guide

For Backend Mode, your backend needs to implement two endpoints:

### 1. Create Payment Endpoint

Combines EveryPay initialization and merchant ID lookup.

```
POST /api/applepay/create-payment

Request body:
{
  "amount": 10.50,
  "orderId": "your-order-id"
}

Your backend calls:
1. POST https://payment.sandbox.lhv.ee/api/v4/payments/oneoff
   → Returns paymentReference, mobileAccessToken

2. GET https://payment.sandbox.lhv.ee/api/v4/sdk/payment_methods/{accountName}?amount={amount}
   → Returns applePayMerchantIdentifier

Response to app:
{
  "merchantIdentifier": "merchant.com.everypay.demo",
  "merchantName": "Your Store",
  "amount": 10.50,
  "currencyCode": "EUR",
  "countryCode": "EE",
  "paymentReference": "ref_xxx",
  "mobileAccessToken": "token_xxx",
  "authorizePaymentUrl": "https://payment.sandbox.lhv.ee/api/v4/apple_pay/payment_data"
}
```

### 2. Process Token Endpoint

Sends Apple Pay token to EveryPay for authorization.

```
POST /api/applepay/process-token

Request body (from app):
{
  "paymentReference": "ref_xxx",
  "mobileAccessToken": "token_xxx",
  "paymentData": "base64-encoded-token",
  "transactionIdentifier": "xxx"
}

Your backend calls:
POST https://payment.sandbox.lhv.ee/api/v4/apple_pay/payment_data
Authorization: Bearer {mobileAccessToken}
{
  "payment_reference": "ref_xxx",
  "payment_data": {decoded paymentData JSON}
}

Response to app:
{
  "success": true,
  "state": "completed"
}
```

## Mode Comparison

| Feature | Backend Mode | SDK Mode |
|---------|-------------|----------|
| Recommended | Yes | No |
| Security | Credentials on backend | Credentials in app |
| Setup Complexity | Medium (requires backend) | Low |
| Maintainability | Easy to update logic | Requires app update |
| Token Handling | User sends to backend | Library handles |

## Error Handling

```typescript
import { PaymentError } from '@everypay/applepay-rn-bridge';

try {
  const result = await ApplePay.makePaymentWithBackendData(backendData);
} catch (error) {
  if (error instanceof PaymentError) {
    switch (error.code) {
      case 'cancelled':
        console.log('User cancelled payment');
        break;
      case 'invalid_config':
        console.log('Invalid configuration');
        break;
      case 'payment_error':
        console.log('Payment failed:', error.message);
        break;
      default:
        console.log('Error:', error.code, error.message);
    }
  }
}
```

## Migration from v1.x

If upgrading from v1.x (SDK Mode only):

1. **No changes required** for existing SDK Mode usage
2. **Recommended**: Migrate to Backend Mode for improved security
3. Update `EverypayApplePay` SDK dependency in Podfile

## License

MIT
