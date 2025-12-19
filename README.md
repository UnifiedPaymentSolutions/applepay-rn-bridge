# @everypay/applepay-rn-bridge

EveryPay Apple Pay React Native Bridge (iOS Only). Built on [EveryPay Apple Pay iOS SDK](../everypay-applepay-sdk-client). Full TypeScript support.

- **Backend Mode**: Keep API credentials secure on your backend (recommended)
- **SDK Integration**: Built on EveryPay iOS SDK for better maintainability
- **Enhanced Security**: API credentials never exposed in mobile app
- **Dual Mode Support**: Backend Mode (recommended) + SDK Mode
- **Recurring Payments**: Request tokens for recurring payments (iOS 16+)

## Installation

```sh
npm install @everypay/applepay-rn-bridge
```

```sh
yarn add @everypay/applepay-rn-bridge
```

## Quick Start

### Backend Mode (Recommended)

Most secure approach - API credentials stay on your backend. You have full control over when and how API requests are made.

**Step 1:** Implement 2 backend endpoints ([see guide](./BACKEND_INTEGRATION.md))

Your backend needs these endpoints:

- **POST /api/applepay/create-payment** - Combines EveryPay `payment_methods` + `payments/oneoff` API calls
- **POST /api/applepay/process-token** - Calls EveryPay `apple_pay/payment_data` API to process the token

**Step 2:** Use ApplePayButton component:

```typescript
import React, { useState, useEffect } from 'react';
import { ApplePayButton } from '@everypay/applepay-rn-bridge';
import type {
  ApplePayBackendData,
  ApplePayTokenResult
} from '@everypay/applepay-rn-bridge';

function PaymentScreen() {
  const [backendData, setBackendData] = useState<ApplePayBackendData | null>(null);

  // Fetch payment data when component mounts
  useEffect(() => {
    const fetchPaymentData = async () => {
      try {
        const response = await fetch('https://your-backend.com/api/applepay/create-payment', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            amount: 10.50,
            label: 'Product Purchase',
            orderReference: 'ORDER-123',
            customerEmail: 'customer@example.com',
          }),
        });
        const data = await response.json();
        setBackendData(data);
      } catch (error) {
        console.error('Failed to prepare payment:', error);
      }
    };

    fetchPaymentData();
  }, []);

  // Process the Apple Pay token
  const handlePaymentToken = async (tokenData: ApplePayTokenResult) => {
    try {
      const result = await fetch('https://your-backend.com/api/applepay/process-token', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(tokenData)
      });
      return result.json();
    } catch (error) {
      console.error('Failed to process token:', error);
      throw error;
    }
  };

  // Show Apple Pay button only when backend data is ready
  if (!backendData) {
    return null; // Or show a loading indicator
  }

  return (
    <ApplePayButton
      backendData={backendData}
      onPressCallback={handlePaymentToken}
      // Handle your back-end response here
      onPaymentSuccess={(result) => result.state === 'failed' ? console.error('Error:', result) : console.log('Success!', result)}
      onPaymentError={(error) => console.error('Payment failed:', error)}
      onPaymentCanceled={() => console.log('Payment canceled')}
      buttonStyle="black"
      buttonType="buy"  // Options: buy, plain, checkout, donate, order, subscribe, etc.
    />
  );
}
```

**How it works:**

1. Component mounts → **automatically fetches** payment data from your `/create-payment` endpoint (this should internally call both EveryPay `payment_methods` and `payments/oneoff` APIs)
2. When data arrives → Apple Pay button appears (component initializes automatically)
3. User presses Apple Pay button → SDK shows Apple Pay UI and retrieves token
4. `onPressCallback` is called with the token → **you send** it to your `/process-token` endpoint
5. Your backend processes the payment and returns the result

**Full Backend Setup Guide:** [BACKEND_INTEGRATION.md](./BACKEND_INTEGRATION.md)

---

### SDK Mode

API keys are stored in the app, no back-end service needed

Use ApplePayButton with SDK configuration:

```typescript
import { ApplePayButton } from '@everypay/applepay-rn-bridge';
import type { ApplePaySDKConfig } from '@everypay/applepay-rn-bridge';

function PaymentScreen() {
  const config: ApplePaySDKConfig = {
    // Everypay API credentials in app
    apiUsername: 'your_username',
    apiSecret: 'your_secret',
    baseUrl: 'https://payment.sandbox.lhv.ee', // or production URL
    accountName: 'EUR3D1',
    countryCode: 'EE',
  };

  const handlePayment = async (result: any) => {
    // Payment already processed by SDK
    console.log('Payment result:', result);
    return result;
  };

  return (
    <ApplePayButton
      config={config}
      amount={10.50}
      label="Product Purchase"
      orderReference="ORDER-123"
      customerEmail="customer@example.com"
      onPressCallback={handlePayment}
      onPaymentSuccess={(result) => console.log('Success!', result)}
      onPaymentError={(error) => console.error('Error:', error)}
      buttonStyle="black"
      buttonType="buy"
    />
  );
}
```

**How it works:**

1. Component auto-detects SDK mode (no `backendData`, but has `config` with API credentials)
2. Initializes SDK with your credentials
3. On button press, shows Apple Pay and processes payment via EveryPay API
4. Calls your `onPressCallback` with the payment result

---

### Component Features

- **Auto-mode detection** - Automatically uses Backend or SDK mode based on config
- **User-controlled flow** - You decide when to fetch data and make API calls
- **Single callback** - Simple `onPressCallback` handles payment flow
- **Native button** - Official PKPaymentButton with multiple types
- **Type-safe** - Pass typed data directly, full TypeScript support
- **Availability check** - Only renders when Apple Pay is available

## Requirements

### System Requirements

- iOS only (Android not supported)
- React Native >= 0.60 (for autolinking)
- iOS >= 15.0
- Xcode >= 14

### iOS Requirements

Add EverypayApplePay SDK to your Podfile:

```ruby
pod 'EverypayApplePay', :path => '../path/to/everypay-applepay-sdk-client/EverypayApplePay'
```

Install native dependencies:

```bash
cd ios
pod install
```

### Apple Pay Configuration

1. **Apple Developer Account Setup**
   - Create a Merchant ID in your [Apple Developer Account](https://developer.apple.com)
   - Navigate to Certificates, Identifiers & Profiles → Merchant IDs

2. **EveryPay Setup**
   - Login to EveryPay Merchant portal
   - Go to E-Shop Settings → Apple Pay (in apps)
   - Enter your Apple Pay Merchant Identifier
   - Download CSR, upload to Apple, download certificate, upload back to EveryPay

3. **Xcode Project Configuration**
   - Open your project in Xcode
   - Select your target → Signing & Capabilities
   - Add "Apple Pay" capability
   - Select your Merchant ID

## API Reference

### Configuration Types

#### ApplePayBackendData

Data structure from backend for payment initialization:

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

#### ApplePayTokenResult

Token data returned from SDK to be sent to backend:

```typescript
interface ApplePayTokenResult {
  success: boolean;
  paymentData: string;             // Base64 encoded Apple Pay token
  transactionIdentifier: string;   // Apple Pay transaction ID
  paymentMethod: {
    displayName: string;           // e.g., "Visa 1234"
    network: string;               // e.g., "Visa"
    type: number;
  };
  paymentReference: string;        // Pass-through from backend data
  mobileAccessToken: string;       // Pass-through from backend data
}
```

#### ApplePaySDKConfig

SDK mode configuration:

```typescript
interface ApplePaySDKConfig {
  apiUsername: string;
  apiSecret: string;
  baseUrl: string;
  accountName: string;
  countryCode?: string;
}
```

### Native Methods

#### Backend Mode Methods

```typescript
// Check Apple Pay availability
canMakePayments(): Promise<boolean>

// Check if recurring tokens supported (iOS 16+)
canRequestRecurringToken(): Promise<boolean>

// Make payment with backend data
makePaymentWithBackendData(
  backendData: ApplePayBackendData
): Promise<ApplePayTokenResult>

// Request recurring token with backend data
requestTokenWithBackendData(
  backendData: ApplePayBackendData
): Promise<ApplePayTokenResult>
```

#### SDK Mode Methods

```typescript
// Initialize payment with EveryPay
initEverypayPayment(config: InitRequest): Promise<InitResult>

// Full payment flow (init + present + authorize)
startApplePayPayment(paymentRequest: PaymentRequest): Promise<PaymentResult>

// Enable/disable mock payments (debug only)
setMockPaymentsEnabled(enabled: boolean): Promise<boolean>
```

### Button Styles

| Style | Description |
|-------|-------------|
| `black` | Black background (default) |
| `white` | White background |
| `whiteOutline` | White background with black outline |
| `automatic` | Adapts to the current appearance (iOS 14+) |

### Button Types

| Type | Button Text |
|------|-------------|
| `plain` | Apple Pay logo only (default) |
| `buy` | "Buy with Apple Pay" |
| `checkout` | "Check out with Apple Pay" |
| `donate` | "Donate with Apple Pay" |
| `book` | "Book with Apple Pay" |
| `subscribe` | "Subscribe with Apple Pay" |
| `order` | "Order with Apple Pay" |
| `inStore` | "Pay with Apple Pay" |
| `continue` | "Continue with Apple Pay" |
| `reload` | "Reload with Apple Pay" |
| `addMoney` | "Add Money with Apple Pay" |
| `topUp` | "Top Up with Apple Pay" |
| `rent` | "Rent with Apple Pay" |
| `support` | "Support with Apple Pay" |
| `contribute` | "Contribute with Apple Pay" |
| `tip` | "Tip with Apple Pay" |

### Error Codes

| Code | Description |
|------|-------------|
| `cancelled` | User canceled payment |
| `invalid_config` | Invalid configuration |
| `payment_error` | Payment processing error |
| `payment_in_progress` | Another payment is already in progress |
| `presentation_failed` | Failed to present Apple Pay sheet |

## Documentation

- [Backend Integration Guide](./BACKEND_INTEGRATION.md) - How to implement backend endpoints
- [Custom Button Implementation](./CUSTOM_BUTTON_GUIDE.md) - Using programmatic API with custom buttons
- [TypeScript Types](./src/payment/types.ts) - Full type definitions

## Mode Comparison

| Feature | Backend Mode | SDK Mode |
|---------|--------------|----------|
| Recommended | Yes | No |
| Security | Credentials on backend | Credentials in app |
| Complexity | Medium (requires backend) | Low |
| Maintainability | Easy to update logic | Requires app update |

## Troubleshooting

### "Apple Pay not available"

- Ensure device has Apple Pay configured
- Check that merchant ID is correctly set up in Apple Developer portal
- Verify Apple Pay capability is added in Xcode

### "Payment already in progress"

- Wait for current payment to complete before starting new one
- Check that you're not calling payment methods multiple times

### "Invalid configuration"

- Verify all required fields in `ApplePayBackendData` are present
- Check that merchant identifier matches your Apple Developer setup

### "Authorization failed"

- Verify API credentials on backend
- Check that mobileAccessToken is being passed correctly

## Security Best Practices

1. **Use Backend Mode if possible**
2. **Never commit API credentials** to version control
3. **Validate all inputs** on your backend
4. **Use HTTPS** for all backend communications
5. **Implement rate limiting** on backend endpoints
6. **Log security events** on backend

## Testing

### Test Environment

Use EveryPay sandbox URL (`https://payment.sandbox.lhv.ee`) with sandbox credentials.

For Apple Pay testing:
- Use [Apple Pay Sandbox Testing](https://developer.apple.com/apple-pay/sandbox-testing/)
- Add sandbox tester accounts in App Store Connect

## Important Notes

- iOS only (Android not supported)
- Requires Apple Developer account with Apple Pay configured
- Complies with [Apple Pay Guidelines](https://developer.apple.com/apple-pay/marketing/)

## License

MIT

---

Made with [create-react-native-library](https://github.com/callstack/react-native-builder-bob)
