import {
  canMakePayments,
  initEverypayPayment,
  setMockPaymentsEnabled,
  startApplePayPayment,
  startApplePayWithLateEverypayInit,
} from '@everypay/applepay-rn-bridge';
import React, { useEffect, useState } from 'react';
import {
  ActivityIndicator,
  Alert,
  StyleSheet,
  Switch,
  Text,
  TextInput,
  View,
} from 'react-native';
import ApplePayButton from './ApplePayButton';

const App = () => {
  const [earlyInitLoading, setEarlyInitLoading] = useState(false);
  const [lateInitLoading, setLateInitLoading] = useState(false);
  const [canPay, setCanPay] = useState<boolean | null>(null);

  // Editable config states
  const [apiUsername, setApiUsername] = useState('');
  const [apiSecret, setApiSecret] = useState('');
  const [baseUrl, setBaseUrl] = useState('https://payment.sandbox.lhv.ee');
  const [accountName, setAccountName] = useState('EUR3D1');
  const [amount, setAmount] = useState('1.99');
  const [label, setLabel] = useState('Test Product');
  const [mockEnabled, setMockEnabled] = useState(false);

  useEffect(() => {
    checkApplePaySupport();
  }, []);

  const checkApplePaySupport = async () => {
    try {
      const isSupported = await canMakePayments();
      setCanPay(isSupported);
    } catch (error) {
      console.error('Error checking Apple Pay:', error);
      setCanPay(false);
    }
  };

  const handlePay = async () => {
    if (!canPay) {
      Alert.alert(
        'Not Available',
        'Apple Pay is not available on this device.'
      );
      return;
    }

    setEarlyInitLoading(true);

    try {
      const initResult = await initEverypayPayment({
        auth: {
          apiUsername,
          apiSecret,
        },
        baseUrl,
        data: {
          accountName,
          currencyCode: 'EUR',
          countryCode: 'EE',
          amount: parseFloat(amount),
          label,
          customerUrl: 'https://customerprofile.example.com/john-doe',
          locale: 'en',
          customerIp: '192.168.1.1',
        },
      });
      console.log(
        '[ApplePay RN] initPayment result:' + JSON.stringify(initResult)
      );

      console.log('[ApplePay RN] Going to invoke startPayment');
      const resp = await startApplePayPayment({
        auth: {
          apiUsername,
          apiSecret,
        },
        baseUrl,
        data: {
          accountName: initResult.accountName,
          paymentReference: initResult.paymentReference,
          amount: initResult.amount,
          label,
          currencyCode: initResult.currencyCode,
          countryCode: 'EE',
          mobileAccessToken: initResult.mobileAccessToken,
        },
      });
      console.log('Apple Pay response:', resp);
      Alert.alert('Success', 'Payment completed successfully!');
    } catch (error: any) {
      if ('code' in error && error.code && error.code === 'cancelled') {
      } else {
        console.error('Error starting Apple Pay:', JSON.stringify(error));
        Alert.alert('Error', 'Failed to start Apple Pay');
      }
    } finally {
      setEarlyInitLoading(false);
    }
  };

  // Add this new handler function
  const handleLateInitPay = async () => {
    setLateInitLoading(true);
    try {
      // Create config without payment reference/token
      const config = {
        auth: {
          apiUsername,
          apiSecret,
        },
        baseUrl,
        data: {
          accountName,
          amount: parseFloat(amount),
          label,
          currencyCode: 'EUR', // You might want to make this configurable
          countryCode: 'EE', // You might want to make this configurable
        },
      };
      const result = await startApplePayWithLateEverypayInit(config);
      console.log('Late init payment successful:', result);
      Alert.alert('Success', 'Payment completed successfully!');
    } catch (error: any) {
      if ('code' in error && error.code && error.code === 'cancelled') {
      } else {
        console.error('Error starting Apple Pay:', JSON.stringify(error));
        Alert.alert('Error', 'Failed to start Apple Pay');
      }
    } finally {
      setLateInitLoading(false);
    }
  };

  // Add this function to validate fields before payment
  const validateAndPay = (paymentFunction: () => void): void => {
    if (
      !baseUrl ||
      !apiUsername ||
      !apiSecret ||
      !accountName ||
      !amount ||
      !label
    ) {
      Alert.alert(
        'Required Fields',
        'Please fill in all required fields marked with *',
        [{ text: 'OK' }]
      );
      return;
    }

    paymentFunction();
  };

  return (
    <View style={styles.container}>
      <Text style={styles.title}>LHV Everypay Apple Pay Demo</Text>

      {canPay === null ? (
        <ActivityIndicator size="small" />
      ) : canPay ? (
        <Text style={styles.subtitle}>
          Apple Pay is available on the device ✅
        </Text>
      ) : (
        <Text style={styles.warning}>
          Apple Pay not available on the device ⚠️
        </Text>
      )}

      {/* Editable fields */}
      <View style={styles.inputGroup}>
        <Text style={styles.inputLabel}>
          Everypay API Base URL <Text style={styles.required}>*</Text>
        </Text>
        <TextInput
          style={[styles.input, !baseUrl && styles.inputError]}
          value={baseUrl}
          onChangeText={setBaseUrl}
          placeholder="Base URL"
        />
      </View>
      <View style={styles.inputGroup}>
        <Text style={styles.inputLabel}>
          API Username <Text style={styles.required}>*</Text>
        </Text>
        <TextInput
          style={[styles.input, !apiUsername && styles.inputError]}
          value={apiUsername}
          onChangeText={setApiUsername}
          placeholder="API Username"
        />
      </View>
      <View style={styles.inputGroup}>
        <Text style={styles.inputLabel}>
          API Secret <Text style={styles.required}>*</Text>
        </Text>
        <TextInput
          style={[styles.input, !apiSecret && styles.inputError]}
          value={apiSecret}
          onChangeText={setApiSecret}
          placeholder="API Secret"
          secureTextEntry
        />
      </View>
      <View style={styles.inputGroup}>
        <Text style={styles.inputLabel}>
          Everypay Account ID <Text style={styles.required}>*</Text>
        </Text>
        <TextInput
          style={[styles.input, !accountName && styles.inputError]}
          value={accountName}
          onChangeText={setAccountName}
          placeholder="Account Name"
        />
      </View>
      <View style={styles.inputGroup}>
        <Text style={styles.inputLabel}>
          Payable Amount <Text style={styles.required}>*</Text>
        </Text>
        <TextInput
          style={[styles.input, !amount && styles.inputError]}
          value={amount}
          onChangeText={setAmount}
          placeholder="Amount"
          keyboardType="numeric"
        />
      </View>
      <View style={styles.inputGroup}>
        <Text style={styles.inputLabel}>
          Product Label <Text style={styles.required}>*</Text>
        </Text>
        <TextInput
          style={[styles.input, !label && styles.inputError]}
          value={label}
          onChangeText={setLabel}
          placeholder="Label"
        />
      </View>

      <View>
        <Text style={styles.inputLabel}>
          Enable mock payment (for iOS Simulator)
        </Text>
        <Switch
          value={mockEnabled}
          onValueChange={(value) => {
            setMockPaymentsEnabled(value);
            setMockEnabled(value);
          }}
        />
      </View>

      {/* Two payment buttons with clear labels */}
      <View style={styles.paymentOptionsContainer}>
        <Text style={styles.sectionTitle}>Choose Payment Flow:</Text>

        <View style={styles.paymentButtonsRow}>
          <View style={styles.paymentButtonColumn}>
            <Text style={styles.buttonLabel}>Pre-Init</Text>
            <Text style={styles.buttonDescription}>
              Init EP first & open pay sheet
            </Text>
            <ApplePayButton
              onPress={() => validateAndPay(handlePay)}
              disabled={!canPay || earlyInitLoading}
              loading={earlyInitLoading}
            />
          </View>

          <View style={styles.buttonSeparator} />

          <View style={styles.paymentButtonColumn}>
            <Text style={styles.buttonLabel}>Late Init</Text>
            <Text style={styles.buttonDescription}>
              Open pay sheet & init EP during authorization
            </Text>
            <ApplePayButton
              onPress={() => validateAndPay(handleLateInitPay)}
              disabled={!canPay || lateInitLoading}
              loading={lateInitLoading}
            />
          </View>
        </View>
      </View>
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    paddingTop: 60,
    paddingHorizontal: 20,
    backgroundColor: '#f5f5f7',
  },
  title: {
    fontSize: 22,
    fontWeight: 'bold',
    textAlign: 'center',
    marginBottom: 10,
  },
  subtitle: {
    textAlign: 'center',
    marginBottom: 10,
    color: 'green',
  },
  warning: {
    textAlign: 'center',
    marginBottom: 10,
    color: 'orange',
  },
  applePayButtonContainer: {
    marginTop: 16,
  },
  disabled: {
    opacity: 0.6,
  },
  info: {
    marginTop: 20,
    fontSize: 12,
    textAlign: 'center',
    color: '#666',
  },
  inputGroup: {
    marginBottom: 8, // less vertical spacing between inputs
  },
  inputLabel: {
    fontSize: 11, // smaller label text
    color: '#666', // subtle grey
    marginBottom: 2, // tight spacing between label and input
    fontWeight: '500',
  },
  input: {
    height: 36, // a bit shorter than default
    borderColor: '#ccc',
    borderWidth: 1,
    borderRadius: 6,
    paddingHorizontal: 10,
    backgroundColor: '#fff',
    fontSize: 13,
  },
  paymentOptionsContainer: {
    marginTop: 20,
    width: '100%',
  },
  sectionTitle: {
    fontSize: 16,
    fontWeight: 'bold',
    marginBottom: 10,
  },
  paymentButtonsRow: {
    flexDirection: 'row',
    justifyContent: 'center',
    alignItems: 'flex-start',
    width: '100%',
  },
  paymentButtonColumn: {
    flex: 1,
    alignItems: 'center',
    maxWidth: 160,
  },
  buttonSeparator: {
    width: 20, // Space between buttons
  },
  buttonLabel: {
    fontSize: 14,
    fontWeight: 'bold',
    textAlign: 'center',
  },
  buttonDescription: {
    fontSize: 12,
    color: '#666',
    textAlign: 'center',
    marginBottom: 8,
    height: 32, // Fixed height to align buttons even with different text lengths
  },
  required: {
    color: 'red',
  },
  inputError: {
    borderColor: 'red',
  },
});

export default App;
