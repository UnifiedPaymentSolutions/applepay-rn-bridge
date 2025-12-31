//
//  ApplePayButtonComponentView.mm
//  ApplePayBridge
//
//  Fabric component wrapper for ApplePayButtonView (New Architecture only).
//

#ifdef RCT_NEW_ARCH_ENABLED

#import "ApplePayButtonComponentView.h"
#import "ApplePayButtonView.h"

#import <React/RCTConversions.h>
#import <React/RCTFabricComponentsPlugins.h>
#import <react/renderer/components/RNApplePayBridgeSpec/ComponentDescriptors.h>
#import <react/renderer/components/RNApplePayBridgeSpec/EventEmitters.h>
#import <react/renderer/components/RNApplePayBridgeSpec/Props.h>
#import <react/renderer/components/RNApplePayBridgeSpec/RCTComponentViewHelpers.h>

using namespace facebook::react;

@interface ApplePayButtonComponentView () <RCTApplePayButtonViewProtocol>
@end

@implementation ApplePayButtonComponentView {
    ApplePayButtonView *_buttonView;
}

+ (ComponentDescriptorProvider)componentDescriptorProvider
{
    return concreteComponentDescriptorProvider<ApplePayButtonComponentDescriptor>();
}

- (instancetype)initWithFrame:(CGRect)frame
{
    if (self = [super initWithFrame:frame]) {
        static const auto defaultProps = std::make_shared<const ApplePayButtonProps>();
        _props = defaultProps;

        _buttonView = [[ApplePayButtonView alloc] initWithFrame:self.bounds];
        _buttonView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;

        // Wire up onPress event to emit via Fabric
        __weak typeof(self) weakSelf = self;
        _buttonView.onPress = ^(NSDictionary *event) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (strongSelf) {
                [strongSelf handlePress];
            }
        };

        self.contentView = _buttonView;
    }
    return self;
}

- (void)handlePress
{
    if (_eventEmitter) {
        std::static_pointer_cast<const ApplePayButtonEventEmitter>(_eventEmitter)->onPress({});
    }
}

- (void)updateProps:(Props::Shared const &)props oldProps:(Props::Shared const &)oldProps
{
    const auto &newViewProps = *std::static_pointer_cast<const ApplePayButtonProps>(props);
    const auto &oldViewProps = *std::static_pointer_cast<const ApplePayButtonProps>(_props);

    if (oldViewProps.buttonStyle != newViewProps.buttonStyle) {
        _buttonView.buttonStyle = RCTNSStringFromString(newViewProps.buttonStyle);
    }

    if (oldViewProps.buttonType != newViewProps.buttonType) {
        _buttonView.buttonType = RCTNSStringFromString(newViewProps.buttonType);
    }

    if (oldViewProps.cornerRadius != newViewProps.cornerRadius) {
        _buttonView.cornerRadius = newViewProps.cornerRadius;
    }

    [_buttonView updateButton];

    [super updateProps:props oldProps:oldProps];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    _buttonView.frame = self.bounds;
}

@end

// Register component for Fabric
Class<RCTComponentViewProtocol> ApplePayButtonCls(void)
{
    return ApplePayButtonComponentView.class;
}

#endif // RCT_NEW_ARCH_ENABLED
