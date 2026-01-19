//
//  ApplePayButtonView.m
//  ApplePayBridge
//
//  Native PKPaymentButton wrapper for React Native.
//

#import "ApplePayButtonView.h"
#import <React/RCTLog.h>

@interface ApplePayButtonView ()

@property (nonatomic, strong, nullable) PKPaymentButton *paymentButton;

@end

@implementation ApplePayButtonView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        _buttonStyle = @"black";
        _buttonType = @"plain";
        _cornerRadius = 4.0;
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    if (self.paymentButton) {
        self.paymentButton.frame = self.bounds;
    }
}

#pragma mark - Property Setters

- (void)setButtonStyle:(NSString *)buttonStyle {
    if (![_buttonStyle isEqualToString:buttonStyle]) {
        _buttonStyle = [buttonStyle copy];
        [self updateButton];
    }
}

- (void)setButtonType:(NSString *)buttonType {
    if (![_buttonType isEqualToString:buttonType]) {
        _buttonType = [buttonType copy];
        [self updateButton];
    }
}

- (void)setCornerRadius:(CGFloat)cornerRadius {
    if (_cornerRadius != cornerRadius) {
        _cornerRadius = cornerRadius;
        [self updateButton];
    }
}

#pragma mark - Button Management

- (void)updateButton {
    // Remove existing button if any
    if (self.paymentButton) {
        [self.paymentButton removeFromSuperview];
        self.paymentButton = nil;
    }

    // Create new button with current properties
    PKPaymentButtonType type = [self buttonTypeFromString:self.buttonType];
    PKPaymentButtonStyle style = [self buttonStyleFromString:self.buttonStyle];

    PKPaymentButton *button = [[PKPaymentButton alloc] initWithPaymentButtonType:type
                                                              paymentButtonStyle:style];
    button.cornerRadius = self.cornerRadius;
    button.frame = self.bounds;
    button.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;

    [button addTarget:self
               action:@selector(handleButtonPress)
     forControlEvents:UIControlEventTouchUpInside];

    [self addSubview:button];
    self.paymentButton = button;

    RCTLogInfo(@"[ApplePayButtonView] Button created with type: %@, style: %@", self.buttonType, self.buttonStyle);
}

- (void)handleButtonPress {
    RCTLogInfo(@"[ApplePayButtonView] Button pressed");
    if (self.onPress) {
        self.onPress(@{});
    }
}

#pragma mark - Type Conversion Helpers

- (PKPaymentButtonType)buttonTypeFromString:(NSString *)typeString {
    static NSDictionary<NSString *, NSNumber *> *typeMap = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        typeMap = @{
            @"plain": @(PKPaymentButtonTypePlain),
            @"buy": @(PKPaymentButtonTypeBuy),
            @"setUp": @(PKPaymentButtonTypeSetUp),
            @"inStore": @(PKPaymentButtonTypeInStore),
            @"donate": @(PKPaymentButtonTypeDonate),
            @"checkout": @(PKPaymentButtonTypeCheckout),
            @"book": @(PKPaymentButtonTypeBook),
            @"subscribe": @(PKPaymentButtonTypeSubscribe),
            @"reload": @(PKPaymentButtonTypeReload),
            @"addMoney": @(PKPaymentButtonTypeAddMoney),
            @"topUp": @(PKPaymentButtonTypeTopUp),
            @"order": @(PKPaymentButtonTypeOrder),
            @"rent": @(PKPaymentButtonTypeRent),
            @"support": @(PKPaymentButtonTypeSupport),
            @"contribute": @(PKPaymentButtonTypeContribute),
            @"tip": @(PKPaymentButtonTypeTip),
            @"continue": @(PKPaymentButtonTypeContinue),
        };
    });

    NSNumber *typeValue = typeMap[typeString.lowercaseString];
    if (typeValue) {
        return (PKPaymentButtonType)[typeValue integerValue];
    }

    RCTLogWarn(@"[ApplePayButtonView] Unknown button type: %@, defaulting to plain", typeString);
    return PKPaymentButtonTypePlain;
}

- (PKPaymentButtonStyle)buttonStyleFromString:(NSString *)styleString {
    static NSDictionary<NSString *, NSNumber *> *styleMap = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        styleMap = @{
            @"black": @(PKPaymentButtonStyleBlack),
            @"white": @(PKPaymentButtonStyleWhite),
            @"whiteoutline": @(PKPaymentButtonStyleWhiteOutline),
            @"automatic": @(PKPaymentButtonStyleAutomatic),
        };
    });

    NSNumber *styleValue = styleMap[styleString.lowercaseString];
    if (styleValue) {
        return (PKPaymentButtonStyle)[styleValue integerValue];
    }

    RCTLogWarn(@"[ApplePayButtonView] Unknown button style: %@, defaulting to black", styleString);
    return PKPaymentButtonStyleBlack;
}

@end
