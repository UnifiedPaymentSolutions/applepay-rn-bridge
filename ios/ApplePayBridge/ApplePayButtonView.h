//
//  ApplePayButtonView.h
//  ApplePayBridge
//
//  Native PKPaymentButton wrapper for React Native.
//

#import <UIKit/UIKit.h>
#import <PassKit/PassKit.h>
#import <React/RCTComponent.h>

NS_ASSUME_NONNULL_BEGIN

@interface ApplePayButtonView : UIView

/**
 * Button style: "black", "white", "whiteOutline", "automatic"
 * Maps to PKPaymentButtonStyle enum
 */
@property (nonatomic, copy) NSString *buttonStyle;

/**
 * Button type: "plain", "buy", "setUp", "inStore", "donate", "checkout",
 *              "book", "subscribe", "reload", "addMoney", "topUp",
 *              "order", "rent", "support", "contribute", "tip", "continue"
 * Maps to PKPaymentButtonType enum
 */
@property (nonatomic, copy) NSString *buttonType;

/**
 * Corner radius (default: 4)
 */
@property (nonatomic, assign) CGFloat cornerRadius;

/**
 * Callback when button is pressed
 */
@property (nonatomic, copy, nullable) RCTBubblingEventBlock onPress;

/**
 * Recreates the button with current properties
 */
- (void)updateButton;

@end

NS_ASSUME_NONNULL_END
