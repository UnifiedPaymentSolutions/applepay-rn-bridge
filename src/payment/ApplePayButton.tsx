/**
 * ApplePayButton - Native Apple Pay Button Component
 *
 * Renders the native PKPaymentButton and handles payment flow.
 * Supports two modes:
 * - Backend Mode (recommended): User provides data from their backend
 * - SDK Mode: Library makes API calls
 */

import * as React from 'react';
import { useEffect, useState, useRef } from 'react';
import {
  Platform,
  requireNativeComponent,
  StyleSheet,
  TouchableOpacity,
  View,
  ViewStyle,
  StyleProp,
} from 'react-native';
import ApplePay from './ApplePayModule';
import type {
  ApplePayBackendData,
  ApplePayTokenResult,
  ApplePayButtonStyle,
  ApplePayButtonType,
  ApplePaySDKConfig,
  PaymentResult,
} from './types';

// =============================================================================
// NATIVE COMPONENT
// =============================================================================

interface NativeApplePayButtonProps {
  buttonStyle: string;
  buttonType: string;
  cornerRadius: number;
  onPress: () => void;
  style?: StyleProp<ViewStyle>;
}

// Load native component only on iOS
const NativeApplePayButton = Platform.OS === 'ios'
  ? requireNativeComponent<NativeApplePayButtonProps>('ApplePayButton')
  : null;

// =============================================================================
// COMPONENT PROPS
// =============================================================================

/**
 * Common props for ApplePayButton
 */
interface ApplePayButtonCommonProps {
  /** Button style (default: 'black') */
  buttonStyle?: ApplePayButtonStyle;
  /** Button type - determines the text shown (default: 'plain') */
  buttonType?: ApplePayButtonType;
  /** Corner radius in points (default: 4) */
  cornerRadius?: number;
  /** Whether the button is disabled */
  disabled?: boolean;
  /** Custom style for the button container */
  style?: StyleProp<ViewStyle>;
  /** Called when payment fails */
  onPaymentError?: (error: Error) => void;
  /** Called when user cancels */
  onPaymentCanceled?: () => void;
}

/**
 * Backend Mode props - user provides data from their backend
 */
interface ApplePayButtonBackendProps extends ApplePayButtonCommonProps {
  /** Backend-provided payment data */
  backendData: ApplePayBackendData;
  /** Callback to process the token (send to your backend) */
  onPressCallback: (tokenData: ApplePayTokenResult) => Promise<unknown>;
  /** Called when payment succeeds (Backend Mode returns ApplePayTokenResult) */
  onPaymentSuccess?: (result: ApplePayTokenResult) => void;
  // Exclude SDK mode props
  config?: never;
  amount?: never;
  label?: never;
  orderReference?: never;
}

/**
 * SDK Mode props - library makes API calls
 */
interface ApplePayButtonSDKProps extends ApplePayButtonCommonProps {
  /** SDK configuration with API credentials */
  config: ApplePaySDKConfig;
  /** Payment amount */
  amount: number;
  /** Payment label/description */
  label: string;
  /** Order reference (optional, generated if not provided) */
  orderReference?: string;
  /** Callback to process the result */
  onPressCallback: (result: PaymentResult) => Promise<unknown>;
  /** Called when payment succeeds (SDK Mode returns PaymentResult) */
  onPaymentSuccess?: (result: PaymentResult) => void;
  // Exclude Backend mode props
  backendData?: never;
}

/**
 * ApplePayButton props - either Backend Mode or SDK Mode
 */
export type ApplePayButtonProps = ApplePayButtonBackendProps | ApplePayButtonSDKProps;

// =============================================================================
// HELPER FUNCTIONS
// =============================================================================

/**
 * Check if props are for Backend Mode
 */
function isBackendMode(props: ApplePayButtonProps): props is ApplePayButtonBackendProps {
  return 'backendData' in props && props.backendData !== undefined;
}

// =============================================================================
// COMPONENT
// =============================================================================

/**
 * ApplePayButton Component
 *
 * Renders a native Apple Pay button that handles the complete payment flow.
 *
 * @example Backend Mode (Recommended)
 * ```tsx
 * <ApplePayButton
 *   backendData={backendData}
 *   onPressCallback={async (tokenData) => {
 *     // Send tokenData to your backend
 *     return await fetch('/api/process-payment', { body: JSON.stringify(tokenData) });
 *   }}
 *   onPaymentSuccess={(result) => console.log('Payment succeeded:', result)}
 *   onPaymentError={(error) => console.error('Payment failed:', error)}
 *   buttonStyle="black"
 *   buttonType="buy"
 * />
 * ```
 *
 * @example SDK Mode
 * ```tsx
 * <ApplePayButton
 *   config={{
 *     apiUsername: 'your_username',
 *     apiSecret: 'your_secret',
 *     baseUrl: 'https://payment.sandbox.lhv.ee',
 *     accountName: 'EUR3D1',
 *   }}
 *   amount={10.50}
 *   label="Product Purchase"
 *   onPressCallback={async (result) => {
 *     console.log('Payment result:', result);
 *     return result;
 *   }}
 *   onPaymentSuccess={(result) => console.log('Payment succeeded:', result)}
 *   buttonStyle="black"
 *   buttonType="buy"
 * />
 * ```
 */
export function ApplePayButton(props: ApplePayButtonProps): React.ReactElement | null {
  const {
    buttonStyle = 'black',
    buttonType = 'plain',
    cornerRadius = 4,
    disabled = false,
    style,
    onPaymentError,
    onPaymentCanceled,
  } = props;

  const [isReady, setIsReady] = useState(false);
  const [isProcessing, setIsProcessing] = useState(false);
  const isMounted = useRef(true);

  // Track mounted state
  useEffect(() => {
    isMounted.current = true;
    return () => {
      isMounted.current = false;
    };
  }, []);

  // Check Apple Pay availability on mount
  useEffect(() => {
    async function checkAvailability() {
      if (Platform.OS !== 'ios') {
        console.log('[ApplePayButton] Apple Pay is only available on iOS');
        return;
      }

      try {
        const canPay = await ApplePay.canMakePayments();
        if (isMounted.current) {
          setIsReady(canPay);
          if (!canPay) {
            console.log('[ApplePayButton] Apple Pay is not available on this device');
          }
        }
      } catch (error) {
        console.error('[ApplePayButton] Error checking Apple Pay availability:', error);
        if (isMounted.current) {
          setIsReady(false);
        }
      }
    }

    checkAvailability();
  }, []);

  /**
   * Handle button press - start payment flow
   */
  const handlePress = async () => {
    if (isProcessing || disabled || !isReady) {
      return;
    }

    setIsProcessing(true);

    try {
      if (isBackendMode(props)) {
        // Backend Mode: Use makePaymentWithBackendData
        const tokenResult = await ApplePay.makePaymentWithBackendData(props.backendData);

        // Call the user's callback to process the token
        await props.onPressCallback(tokenResult);

        if (isMounted.current) {
          props.onPaymentSuccess?.(tokenResult);
        }
      } else {
        // SDK Mode: Use startApplePayPayment
        const result = await ApplePay.startApplePayPayment({
          auth: {
            apiUsername: props.config.apiUsername,
            apiSecret: props.config.apiSecret,
          },
          baseUrl: props.config.baseUrl,
          data: {
            accountName: props.config.accountName,
            amount: props.amount,
            label: props.label,
            countryCode: props.config.countryCode || 'EE',
            orderReference: props.orderReference,
          },
        });

        // Call the user's callback with the result
        await props.onPressCallback(result);

        if (isMounted.current) {
          props.onPaymentSuccess?.(result);
        }
      }
    } catch (error: unknown) {
      if (!isMounted.current) return;

      const errorObj = error instanceof Error ? error : new Error(String(error));

      // Check if user cancelled
      if (errorObj.message?.includes('cancelled') ||
          (error && typeof error === 'object' && 'code' in error && error.code === 'cancelled')) {
        onPaymentCanceled?.();
      } else {
        onPaymentError?.(errorObj);
      }
    } finally {
      if (isMounted.current) {
        setIsProcessing(false);
      }
    }
  };

  // Don't render on non-iOS platforms
  if (Platform.OS !== 'ios' || !NativeApplePayButton) {
    console.log('[ApplePayButton] Apple Pay is only available on iOS');
    return null;
  }

  // Don't render if Apple Pay is not available
  if (!isReady) {
    return null;
  }

  return (
    <TouchableOpacity
      onPress={handlePress}
      disabled={disabled || isProcessing}
      activeOpacity={0.7}
      style={[
        styles.container,
        style,
        (disabled || isProcessing) && styles.disabled,
      ]}
    >
      <View style={styles.buttonWrapper}>
        <NativeApplePayButton
          buttonStyle={buttonStyle}
          buttonType={buttonType}
          cornerRadius={cornerRadius}
          onPress={handlePress}
          style={styles.nativeButton}
        />
      </View>
    </TouchableOpacity>
  );
}

// =============================================================================
// STYLES
// =============================================================================

const styles = StyleSheet.create({
  container: {
    overflow: 'hidden',
  },
  buttonWrapper: {
    minHeight: 44, // Apple's minimum touch target
  },
  nativeButton: {
    flex: 1,
    minHeight: 44,
  },
  disabled: {
    opacity: 0.4,
  },
});

export default ApplePayButton;
