//
//  ApplePayButtonManager.m
//  ApplePayBridge
//
//  ViewManager for ApplePayButtonView - exposes native PKPaymentButton to React Native.
//

#import "ApplePayButtonManager.h"
#import "ApplePayButtonView.h"
#import <React/RCTLog.h>

@implementation ApplePayButtonManager

RCT_EXPORT_MODULE(ApplePayButton)

- (UIView *)view {
    ApplePayButtonView *buttonView = [[ApplePayButtonView alloc] init];
    // Create initial button
    [buttonView updateButton];
    return buttonView;
}

// Button style: "black", "white", "whiteOutline", "automatic"
RCT_EXPORT_VIEW_PROPERTY(buttonStyle, NSString)

// Button type: "plain", "buy", "checkout", "donate", etc.
RCT_EXPORT_VIEW_PROPERTY(buttonType, NSString)

// Corner radius
RCT_EXPORT_VIEW_PROPERTY(cornerRadius, CGFloat)

// Press callback
RCT_EXPORT_VIEW_PROPERTY(onPress, RCTBubblingEventBlock)

// Custom setter to trigger button update after all props are set
RCT_CUSTOM_VIEW_PROPERTY(updateTrigger, NSNumber, ApplePayButtonView) {
    // This is a dummy prop that triggers a button update
    // Call this after other props are set
    [view updateButton];
}

@end
