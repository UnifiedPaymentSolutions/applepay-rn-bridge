// Mock react-native-dotenv - ADD THIS FIRST
jest.mock('react-native-dotenv', () => ({
  API_BASE_URL: 'https://mocked-api.com',
  // Add any other env variables your code might use
}));

// Your existing React Native mock
jest.mock('react-native', () => {
  // Create a basic mock for React Native components
  const mockRN = {
    NativeModules: {
      ApplePayModule: {
        // FIX THIS: Change method name to match what your code is using
        startApplePay: jest.fn(), // Changed from startPayment to startApplePay
        canMakePayments: jest.fn().mockResolvedValue(true),
      },
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
