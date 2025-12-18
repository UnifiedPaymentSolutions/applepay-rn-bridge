# Custom Apple Pay Button Implementation Guide

This guide explains how to implement Apple Pay using your own custom-styled button instead of the native Apple Pay button, giving you full control over the payment flow and UI.

## Overview

The `@everypay/applepay-rn-bridge` library exposes methods that you can call from your own button component. This approach is useful when:

- You need custom button styling to match your app's design
- You want to integrate the payment button into existing UI flows
- You need additional validation or logic before presenting Apple Pay

## Prerequisites

Before following this guide, ensure you have:
- Completed the [installation and Apple Pay setup](./README.md#installation)
- Configured your Merchant ID in Xcode
- Set up certificates with EveryPay

## Custom Button Component

Here's a complete custom Apple Pay button component with proper styling and states:

```typescript
// ApplePayButton.tsx
import React from 'react';
import { TouchableOpacity, Text, View, StyleSheet, Platform } from 'react-native';

interface ApplePayButtonProps {
  onPress: () => void;
  disabled?: boolean;
  loading?: boolean;
}

const ApplePayButton: React.FC<ApplePayButtonProps> = ({
  onPress,
  disabled = false,
  loading = false
}) => (
  <TouchableOpacity
    style={[styles.button, disabled && styles.disabled]}
    onPress={onPress}
    disabled={disabled}
    activeOpacity={0.8}
  >
    <View style={styles.content}>
      <Text style={styles.text}>
        {loading ? 'Processing...' : 'Buy with '}
      </Text>
      <Text style={styles.appleLogoText}>
        {loading ? '' : ''}
      </Text>
      <Text style={styles.text}>
        {loading ? '' : 'Pay'}
      </Text>
    </View>
  </TouchableOpacity>
);

const styles = StyleSheet.create({
  button: {
    backgroundColor: '#000000',
    borderRadius: 8,
    height: 44,
    paddingHorizontal: 16,
    justifyContent: 'center',
    alignItems: 'center',
  },
  content: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
  },
  text: {
    color: '#FFFFFF',
    fontSize: 16,
    fontWeight: '600',
    fontFamily: Platform.OS === 'ios' ? '-apple-system' : 'System',
  },
  appleLogoText: {
    color: '#FFFFFF',
    fontSize: 20,
    fontWeight: '600',
    fontFamily: Platform.OS === 'ios' ? '-apple-system' : 'System',
    paddingBottom: 3,
    paddingRight: 1
  },
  disabled: {
    opacity: 0.6,
  },
});

export default ApplePayButton;
```

### Styling Guidelines

- **Minimum height**: 44pt (Apple HIG requirement for touch targets)
- **Background**: Black (#000000) for standard appearance
- **Text color**: White (#FFFFFF)
- **Apple logo**: Use the Unicode character `` (Apple logo) with `-apple-system` font
- **Disabled state**: Reduce opacity to indicate unavailability

## SDK Mode Implementation

SDK Mode handles the complete payment flow including backend communication. This is simpler to set up but stores API credentials in the app.

### Complete Example

```typescript
import React, { useEffect, useState } from 'react';
import { View, Alert, ActivityIndicator, Text, StyleSheet } from 'react-native';
import {
  canMakePayments,
  setMockPaymentsEnabled,
  startApplePayPayment,
} from '@everypay/applepay-rn-bridge';
import ApplePayButton from './ApplePayButton';

const PaymentScreen = () => {
  const [loading, setLoading] = useState(false);
  const [canPay, setCanPay] = useState<boolean | null>(null);

  // Step 1: Check Apple Pay availability on mount
  useEffect(() => {
    checkApplePaySupport();
  }, []);

  const checkApplePaySupport = async () => {
    try {
      const isSupported = await canMakePayments();
      setCanPay(isSupported);
    } catch (error) {
      console.error('Error checking Apple Pay:', error);
      setCanPay(false);
    }
  };

  // Step 2: Create payment handler
  const handlePay = async () => {
    if (!canPay) {
      Alert.alert('Not Available', 'Apple Pay is not available on this device.');
      return;
    }

    setLoading(true);

    try {
      const result = await startApplePayPayment({
        auth: {
          apiUsername: 'YOUR_API_USERNAME',
          apiSecret: 'YOUR_API_SECRET',
        },
        baseUrl: 'https://payment.sandbox.lhv.ee',
        data: {
          accountName: 'EUR3D1',
          amount: 10.50,
          label: 'Product Purchase',
          currencyCode: 'EUR',
          countryCode: 'EE',
        },
      });

      console.log('Payment response:', result);
      Alert.alert('Success', 'Payment completed successfully!');
    } catch (error: any) {
      // Special handling for user cancellation
      if ('code' in error && error.code === 'cancelled') {
        // User cancelled - don't show error
        return;
      }
      console.error('Payment error:', JSON.stringify(error));
      Alert.alert('Error', 'Failed to process payment');
    } finally {
      setLoading(false);
    }
  };

  // Step 3: Optional validation before payment
  const validateAndPay = () => {
    // Add your custom validation logic here
    // e.g., check if cart is not empty, user is logged in, etc.
    handlePay();
  };

  return (
    <View style={styles.container}>
      {/* Show availability status */}
      {canPay === null ? (
        <ActivityIndicator size="small" />
      ) : canPay ? (
        <Text style={styles.available}>Apple Pay is available</Text>
      ) : (
        <Text style={styles.unavailable}>Apple Pay not available</Text>
      )}

      {/* Custom Apple Pay button */}
      <ApplePayButton
        onPress={validateAndPay}
        disabled={!canPay || loading}
        loading={loading}
      />
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    padding: 20,
  },
  available: {
    color: 'green',
    marginBottom: 20,
    textAlign: 'center',
  },
  unavailable: {
    color: 'orange',
    marginBottom: 20,
    textAlign: 'center',
  },
});

export default PaymentScreen;
```

## Backend Mode Implementation

Backend Mode is the recommended approach for production apps. API credentials stay secure on your backend server.

### Complete Example

```typescript
import React, { useEffect, useState } from 'react';
import { View, Alert, StyleSheet } from 'react-native';
import {
  canMakePayments,
  makePaymentWithBackendData,
} from '@everypay/applepay-rn-bridge';
import type { ApplePayBackendData } from '@everypay/applepay-rn-bridge';
import ApplePayButton from './ApplePayButton';

const PaymentScreen = () => {
  const [loading, setLoading] = useState(false);
  const [canPay, setCanPay] = useState<boolean | null>(null);

  // Step 1: Check Apple Pay availability on mount
  useEffect(() => {
    const checkSupport = async () => {
      try {
        const isSupported = await canMakePayments();
        setCanPay(isSupported);
      } catch (error) {
        setCanPay(false);
      }
    };
    checkSupport();
  }, []);

  const handlePay = async () => {
    if (!canPay) {
      Alert.alert('Not Available', 'Apple Pay is not available on this device.');
      return;
    }

    setLoading(true);

    try {
      // Step 2: Fetch payment data from YOUR backend
      const response = await fetch('https://your-backend.com/api/applepay/create-payment', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          amount: 10.50,
          orderId: 'order-123',
        }),
      });
      const backendData: ApplePayBackendData = await response.json();

      // Step 3: Present Apple Pay sheet and get token
      const tokenResult = await makePaymentWithBackendData(backendData);

      // Step 4: Send token to YOUR backend for processing
      const processResponse = await fetch('https://your-backend.com/api/applepay/process-token', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          paymentReference: tokenResult.paymentReference,
          mobileAccessToken: tokenResult.mobileAccessToken,
          paymentData: tokenResult.paymentData,
          transactionIdentifier: tokenResult.transactionIdentifier,
        }),
      });

      const result = await processResponse.json();

      if (result.success) {
        Alert.alert('Success', 'Payment completed successfully!');
      } else {
        Alert.alert('Error', 'Payment processing failed');
      }
    } catch (error: any) {
      if ('code' in error && error.code === 'cancelled') {
        return; // User cancelled - don't show error
      }
      console.error('Payment error:', error);
      Alert.alert('Error', 'Failed to process payment');
    } finally {
      setLoading(false);
    }
  };

  return (
    <View style={styles.container}>
      <ApplePayButton
        onPress={handlePay}
        disabled={!canPay || loading}
        loading={loading}
      />
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    padding: 20,
  },
});

export default PaymentScreen;
```

## Error Handling

The library throws `PaymentError` for various failure scenarios:

```typescript
import { PaymentError } from '@everypay/applepay-rn-bridge';

try {
  const result = await startApplePayPayment(config);
} catch (error) {
  if (error instanceof PaymentError) {
    switch (error.code) {
      case 'cancelled':
        // User dismissed the Apple Pay sheet - typically don't show an error
        break;
      case 'invalid_config':
        Alert.alert('Configuration Error', 'Please check your payment settings');
        break;
      case 'payment_error':
        Alert.alert('Payment Failed', error.message);
        break;
      default:
        Alert.alert('Error', `Payment failed: ${error.message}`);
    }
  } else {
    Alert.alert('Error', 'An unexpected error occurred');
  }
}
```

### Important: Handle Cancellation Gracefully

When users dismiss the Apple Pay sheet by tapping outside or pressing cancel, the library throws an error with `code: 'cancelled'`. This is normal user behavior and should not show an error alert:

```typescript
if ('code' in error && error.code === 'cancelled') {
  // User cancelled - silently return without showing error
  return;
}
```

## Testing with Mock Payments

For testing on the iOS Simulator (which doesn't support real Apple Pay), enable mock payments:

```typescript
import { setMockPaymentsEnabled } from '@everypay/applepay-rn-bridge';
import { Switch, Text, View } from 'react-native';

// In your component
const [mockEnabled, setMockEnabled] = useState(false);

<View>
  <Text>Enable mock payment (for iOS Simulator)</Text>
  <Switch
    value={mockEnabled}
    onValueChange={(value) => {
      setMockPaymentsEnabled(value);
      setMockEnabled(value);
    }}
  />
</View>
```

**Note:** Mock payments only work in debug builds and should never be enabled in production.

## Best Practices

### UX Recommendations

1. **Check availability early** - Call `canMakePayments()` on component mount
2. **Show availability status** - Let users know if Apple Pay is available
3. **Disable button when unavailable** - Prevent confusion from tapping a non-functional button
4. **Show loading state** - Display "Processing..." while payment is in progress
5. **Handle all error cases** - Provide user-friendly messages for failures

### Security Considerations

1. **Use Backend Mode for production** - Keeps API credentials off the device
2. **Validate on your backend** - Never trust client-side validation alone
3. **Use HTTPS** - All API communication should be encrypted

### Performance Tips

1. **Cache availability check** - Don't call `canMakePayments()` on every render
2. **Pre-fetch backend data** - Consider fetching payment config before user taps the button
3. **Debounce button presses** - Prevent double-submissions

## See Also

- [Main README](./README.md) - Installation, setup, and API reference
- [Backend Integration Guide](./README.md#backend-integration-guide) - How to implement backend endpoints
- [Demo App](https://github.com/example/applepaybridgedemo) - Complete working example
