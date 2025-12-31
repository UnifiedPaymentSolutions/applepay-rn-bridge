import React from 'react';
import {
  TouchableOpacity,
  Text,
  View,
  StyleSheet,
  Platform,
} from 'react-native';

// Define prop types with TypeScript interface
interface ApplePayButtonProps {
  onPress: () => void;
  disabled?: boolean;
  loading?: boolean;
}

const ApplePayButton: React.FC<ApplePayButtonProps> = ({
  onPress,
  disabled = false,
  loading = false,
}) => (
  <TouchableOpacity
    style={[styles.button, disabled && styles.disabled]}
    onPress={onPress}
    disabled={disabled}
    activeOpacity={0.8}
  >
    <View style={styles.content}>
      <Text style={styles.text}>{loading ? 'Processing...' : 'Buy with '}</Text>
      <Text style={styles.appleLogoText}>{loading ? '' : ''}</Text>
      <Text style={styles.text}>{loading ? '' : 'Pay'}</Text>
    </View>
  </TouchableOpacity>
);

const styles = StyleSheet.create({
  button: {
    backgroundColor: '#000000',
    borderRadius: 8,
    height: 44,
    paddingHorizontal: 16,
    justifyContent: 'center',
    alignItems: 'center',
  },
  content: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
  },
  logo: {
    marginRight: 4,
  },
  text: {
    color: '#FFFFFF',
    fontSize: 16,
    fontWeight: '600',
    fontFamily: Platform.OS === 'ios' ? '-apple-system' : 'System',
  },
  appleLogoText: {
    color: '#FFFFFF',
    fontSize: 20,
    fontWeight: '600',
    fontFamily: Platform.OS === 'ios' ? '-apple-system' : 'System',
    paddingBottom: 3,
    paddingRight: 1,
  },
  disabled: {
    opacity: 0.6,
  },
});

export default ApplePayButton;
