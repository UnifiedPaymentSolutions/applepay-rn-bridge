const { getDefaultConfig, mergeConfig } = require('@react-native/metro-config');
const path = require('path');

const config = {
  resolver: {
    // Specify the path to the 'everypay-applepay-rn-bridge' module
  },
  // Ensure Metro watches for changes in the parent project folder
  watchFolders: [
    path.resolve(__dirname, '../../'), // Adjust based on your project structure
  ],
};

module.exports = mergeConfig(getDefaultConfig(__dirname), config);
