const { getDefaultConfig, mergeConfig } = require('@react-native/metro-config');
const path = require('path');

// Paths
const appNodeModules = path.resolve(__dirname, 'node_modules');
const linkedLibraryPath = path.resolve(__dirname, '../applepay-rn-bridge');

const config = {
  resolver: {
    // Force react and react-native to resolve from the app's node_modules
    extraNodeModules: {
      'react': path.resolve(appNodeModules, 'react'),
      'react-native': path.resolve(appNodeModules, 'react-native'),
    },
    // Block React from being loaded from the linked library's node_modules
    blockList: [
      new RegExp(`${linkedLibraryPath.replace(/[/\\]/g, '[/\\\\]')}/node_modules/react/.*`),
      new RegExp(`${linkedLibraryPath.replace(/[/\\]/g, '[/\\\\]')}/node_modules/react-native/.*`),
    ],
  },
  // Watch the linked library for changes
  watchFolders: [
    linkedLibraryPath,
  ],
};

module.exports = mergeConfig(getDefaultConfig(__dirname), config);
