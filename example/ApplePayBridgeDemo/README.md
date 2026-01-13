# LHV Everypay React Native Apple Pay Bridge Demo

A React Native project integrating Apple Pay using the native bridge, bootstrapped with [@react-native-community/cli](https://github.com/react-native-community/cli).

## Prerequisites

- Complete the [React Native Environment Setup](https://reactnative.dev/docs/set-up-your-environment) for iOS
- An Apple Developer account and Merchant ID

## Installation

### Install dependencies
```sh
npm install
```

### For iOS, install CocoaPods (first time only)
```sh
bundle install
```

### Install iOS native dependencies
```sh
bundle exec pod install --project-directory=ios
```

## Running the App

### Start Metro server
```sh
npm start
```

### Launch on iOS
```sh
npm run ios
```

## Apple Pay Configuration

### Setup Requirements

1. **Apple Developer Account**: Register at [developer.apple.com](https://developer.apple.com)  
2. **Merchant ID**: Create a Merchant ID in the Apple Developer Portal  
3. **Entitlements File**: Update `ios/ApplePayBridgeDemo/ApplePayBridgeDemo.entitlements` with your Merchant ID  
4. **Xcode Configuration**: Enable the Apple Pay capability in your app target's Signing & Capabilities tab  
5. **Bundle Identifier**:  
   - In Xcode, update the app's Bundle Identifier to match one registered in your Apple Developer account  
   - Go to [Certificates, Identifiers & Profiles](https://developer.apple.com/account/resources/identifiers/list)  
   - Create a new App ID (Identifier) if needed, and ensure that Apple Pay is enabled for it  
   - Use this registered Bundle Identifier in your project target

6. **Merchant Identity Certificate**:  
   - Required for Apple Pay backend validation  
   - **You must use the Certificate Signing Request (CSR) provided by Everypay**  
   - In the Apple Developer Portal, navigate to **Certificates** → **Apple Pay Merchant Identity Certificate**  
   - Upload the CSR from Everypay to generate the certificate  
   - Download and install the resulting certificate in your macOS Keychain  
   - This certificate is used by your backend to generate valid Apple Pay payment sessions

---

### Everypay Integration

- Set up your Merchant ID in the Everypay portal:
  - Navigate to your Everypay account (e-shop settings menu)
  - Find the "Apple Pay (in apps)" section
  - **Obtain the Certificate Signing Request (CSR) from Everypay**
  - Use this CSR to generate the **Merchant Identity Certificate** in the Apple Developer Portal
  - Configure the generated Merchant ID value within your Apple Developer account

---

### Testing

- For development, you may use a test Merchant ID format such as: `merchant.com.YOURNAME.applepaytest`
- Apple Pay **must be tested on a real device** (not available in iOS Simulator)
  - Use an iPhone with Apple Pay set up and a valid region/card
  - Sign in with an Apple ID that is a **test user** associated with your Apple Developer Program
    - Go to [Users and Access](https://developer.apple.com/account/#/people)
    - Add a new user with the role **App Store Connect** or **Developer/Test**
    - Sign into this test Apple ID on your iPhone (Settings > iCloud)
    - To create sandbox testers:
      - Go to App Store Connect → **Users and Access** → **Sandbox Testers**
      - Add a test Apple ID to use with sandboxed Apple Pay flows

---

## Development Workflow

- Edit files and save to see changes with Fast Refresh
- Force reload: Press R in iOS Simulator

## Troubleshooting

If you encounter issues, refer to the [React Native Troubleshooting guide](https://reactnative.dev/docs/troubleshooting).

## Learn More

- [React Native Documentation](https://reactnative.dev/docs/getting-started)
- [Integration with Existing Apps](https://reactnative.dev/docs/integration-with-existing-apps)
- [Apple Pay Developer Documentation](https://developer.apple.com/documentation/passkit/apple_pay/)
