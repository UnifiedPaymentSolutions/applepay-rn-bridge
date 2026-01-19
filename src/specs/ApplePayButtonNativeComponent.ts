import type { HostComponent, ViewProps } from 'react-native';
import type {
  BubblingEventHandler,
  Double,
} from 'react-native/Libraries/Types/CodegenTypes';
import codegenNativeComponent from 'react-native/Libraries/Utilities/codegenNativeComponent';

/**
 * Event payload for onPress callback
 */
type OnPressEvent = Readonly<{}>;

/**
 * Native props for ApplePayButton Fabric component
 */
export interface NativeProps extends ViewProps {
  /**
   * Button style: "black", "white", "whiteOutline", "automatic"
   * Maps to PKPaymentButtonStyle enum
   */
  buttonStyle?: string;

  /**
   * Button type: "plain", "buy", "setUp", "inStore", "donate", "checkout",
   *              "book", "subscribe", "reload", "addMoney", "topUp",
   *              "order", "rent", "support", "contribute", "tip", "continue"
   * Maps to PKPaymentButtonType enum
   */
  buttonType?: string;

  /**
   * Corner radius (default: 4)
   */
  cornerRadius?: Double;

  /**
   * Callback when button is pressed
   */
  onPress?: BubblingEventHandler<OnPressEvent> | null;
}

// Direct export required for React Native codegen to parse the component
export default codegenNativeComponent<NativeProps>(
  'ApplePayButton'
) as HostComponent<NativeProps>;
