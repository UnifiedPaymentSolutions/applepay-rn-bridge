# React Native Apple Pay Bridge for EveryPay

## Description

This module provides a React Native bridge for integrating Apple Pay, specifically tailored for payment flows similar to EveryPay's API. It allows you to:

1.  Check if the device supports Apple Pay.
2.  Initialize a payment transaction with your backend (`initPayment`).
3.  Present the native Apple Pay sheet to the user using the initialization data (`startApplePay`).
4.  Receive the payment result (success, failure, or cancellation) back in your React Native application.

The native implementation follows a modular approach, separating network communication and data handling from the main bridge logic.

## Features

- Check Apple Pay device capability.
- Separate backend initialization step (`initPayment`).
- Native Apple Pay UI presentation (`startApplePay`).
- Handles payment authorization token processing via your backend.
- Provides clear success, error, and cancellation feedback via Promises and a custom `EPError` class.
- Typed interface for React Native integration using TypeScript.
- Modular native Objective-C code (`ApplePayModule`, `ApplePayNetworkService`, `ApplePayPaymentContext`).

## Requirements

- React Native >= 0.60 (for autolinking)
- iOS >= 15.0 (as specified in `.podspec`, adjust if needed)
- Xcode >= 14 (or compatible with your RN version)
- Cocoapods
- An Apple Developer account with Apple Pay configured (Merchant ID).
- A backend compatible with the initialization and authorization flow used by this module.

## Installation

1.  **Add the package to your project:**

    ```bash
    npm install @everypay/applepay-rn-bridge
    # or
    yarn add @everypay/applepay-rn-bridge
    ```

2.  **Install Native Dependencies (iOS):**

    Navigate to your project's `ios` directory and run `pod install`:

    ```bash
    cd ios
    pod install
    
    ```

    



## Usage Example

```typescript
import React, { useState, useEffect } from 'react';
import { View, Button, Text, Alert, Platform } from 'react-native';
import { canMakePayments, initPayment, startApplePay, EPError } from '@everypay/applepay-rn-bridge'; 
import type { StartPaymentInput, PaymentInitData, EPSuccessResult } from '@everypay/applepay-rn-bridge';

const MyPaymentScreen = () => {
  const [isApplePayAvailable, setIsApplePayAvailable] = useState(false);
  const [isLoading, setIsLoading] = useState(false);
  const [paymentResult, setPaymentResult] = useState<string | null>(null);

  useEffect(() => {
    async function checkAvailability() {
      if(Platform.OS !== 'ios') {
        return;
      }
      try {
        const available = await canMakePayments();
        setIsApplePayAvailable(available);
        console.log('Apple Pay Available:', available);
      } catch (error) {
        console.error('Error checking Apple Pay availability:', error);
        setIsApplePayAvailable(false);
      }
    }
    checkAvailability();
  }, []);

  const handleApplePayPress = async () => {
    if (!isApplePayAvailable) {
      Alert.alert('Error', 'Apple Pay is not available on this device or not configured.');
      return;
    }

    setIsLoading(true);
    setPaymentResult(null);

    try {
      // --- Configuration ---
      const config: StartPaymentInput = {
        // Use 'sandbox' or 'production' or your full custom URL
        baseUrl: 'sandbox',
        auth: {
          apiUsername: 'YOUR_API_USERNAME', // Replace with actual credentials
          apiSecret: 'YOUR_API_SECRET', // Replace with actual credentials
        },
        data: {
          accountName: 'EUR3D1', // Or as needed
          amount: 15.99, // Example amount
          // currency is handled by backend response in this setup usually
          orderReference: `rn-order-${Date.now()}`,
          customerUrl: 'https://example.com/mobile/callback', // Your callback URL
          locale: 'en', // Or 'et', 'lv', 'lt', 'ru' etc.
          // Optional fields:
          // customerEmail: 'test@example.com',
        },
      };

      // --- Step 1: Initialize Payment ---
      console.log('Initializing payment...');
      const initData: PaymentInitData = await initPayment(config);
      console.log('Payment Initialized:', initData);

      // --- Step 2: Start Apple Pay UI ---
      console.log('Starting Apple Pay UI...');
      const result: EPSuccessResult = await startApplePay(initData);
      console.log('Apple Pay Successful:', result);
      setPaymentResult(`Success! Ref: ${result.paymentReference}`);
      // Navigate to success screen, show confirmation, etc.
    } catch (error) {
      if (error instanceof EPError) {
        console.error(`Apple Pay Error (Code: ${error.code}): ${error.message}`);
        setPaymentResult(`Error: ${error.message} (Code: ${error.code})`);
        if (error.code === 'cancelled') {
          Alert.alert('Cancelled', 'Payment was cancelled.');
        } else {
          Alert.alert('Payment Failed', `Error: ${error.message}`);
        }
      } else {
        console.error('An unexpected error occurred:', error);
        setPaymentResult(`Unexpected Error: ${error}`);
        Alert.alert('Error', 'An unexpected error occurred during payment.');
      }
    } finally {
      setIsLoading(false);
    }
  };

  return (
    {Platform.OS === 'ios' && (
      <View style={{ flex: 1, justifyContent: 'center', alignItems: 'center', padding: 20 }}>
        <Button title="Pay with Apple Pay" onPress={handleApplePayPress} disabled={!isApplePayAvailable || isLoading} />
        {isLoading && <Text style={{ marginTop: 10 }}>Processing...</Text>}
        {paymentResult && <Text style={{ marginTop: 20, textAlign: 'center' }}>{paymentResult}</Text>}
        {!isApplePayAvailable && <Text style={{ marginTop: 20, color: 'red' }}>Apple Pay Not Available</Text>}
      </View>
    )}
  );
};

export default MyPaymentScreen;
```
