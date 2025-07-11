// jest.setup.ts
jest.mock('react-native', () => {
  // Create a basic mock for React Native components
  const mockRN = {
    NativeModules: {
      ApplePayModule: {
        startPayment: jest.fn(),
        canMakePayments: jest.fn().mockResolvedValue(true),
      }
    },
    NativeEventEmitter: jest.fn(() => ({
      addListener: jest.fn(() => ({ remove: jest.fn() })),
      removeListener: jest.fn(),
      removeAllListeners: jest.fn(),
    })),
    // Add any other RN components you're using
    View: 'View',
    Text: 'Text',
    TouchableOpacity: 'TouchableOpacity',
    ActivityIndicator: 'ActivityIndicator',
    // Add other core components as needed
  };
  
  return mockRN;
});