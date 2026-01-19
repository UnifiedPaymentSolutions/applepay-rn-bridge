import {
  canMakePayments,
  setMockPaymentsEnabled,
  ApplePayButton,
} from "@everypay/applepay-rn-bridge";
import type {
  ApplePayBackendData,
  ApplePayTokenResult,
  PaymentResult,
} from "@everypay/applepay-rn-bridge";
import React, {useEffect, useState} from "react";
import {
  ActivityIndicator,
  Alert,
  ScrollView,
  StyleSheet,
  Switch,
  Text,
  TextInput,
  TouchableOpacity,
  View,
} from "react-native";

const BACKEND_URL = "http://localhost:3000";

const App = () => {
  const [canPay, setCanPay] = useState<boolean | null>(null);

  // Mode selection state
  const [selectedMode, setSelectedMode] = useState<"backend" | "sdk" | null>(
    null
  );

  // Backend mode state
  const [backendData, setBackendData] = useState<ApplePayBackendData | null>(
    null
  );
  const [backendLoading, setBackendLoading] = useState(false);

  // Editable config states
  const [apiUsername, setApiUsername] = useState("");
const [apiSecret, setApiSecret] = useState("");
  const [baseUrl, setBaseUrl] = useState("https://payment.sandbox.lhv.ee");
  const [accountName, setAccountName] = useState("EUR3D1");
  const [amount, setAmount] = useState("1.99");
  const [label, setLabel] = useState("Test Product");
  const [mockEnabled, setMockEnabled] = useState(false);

  useEffect(() => {
    checkApplePaySupport();
  }, []);

  const checkApplePaySupport = async () => {
    try {
      const isSupported = await canMakePayments();
      setCanPay(isSupported);
    } catch (error) {
      console.error("Error checking Apple Pay:", error);
      setCanPay(false);
    }
  };

  // Backend Mode: Fetch payment data from backend
  const fetchBackendData = async () => {
    setBackendLoading(true);
    setBackendData(null);
    try {
      const response = await fetch(`${BACKEND_URL}/api/applepay/create-payment`, {
        method: "POST",
        headers: {"Content-Type": "application/json"},
        body: JSON.stringify({
          amount: parseFloat(amount),
          label: label,
          orderReference: `ORDER-${Date.now()}`,
          customerEmail: "test@example.com",
        }),
      });
      if (!response.ok) {
        throw new Error(`HTTP ${response.status}`);
      }
      const data = await response.json();
      setBackendData(data);
    } catch (error) {
      console.error("Error fetching backend data:", error);
      Alert.alert("Error", "Failed to initialize payment from backend. Make sure the server is running.");
    } finally {
      setBackendLoading(false);
    }
  };

  // Backend Mode: Process the Apple Pay token
  const handleBackendPaymentToken = async (
    tokenData: ApplePayTokenResult
  ): Promise<unknown> => {
    const response = await fetch(`${BACKEND_URL}/api/applepay/process-token`, {
      method: "POST",
      headers: {"Content-Type": "application/json"},
      body: JSON.stringify(tokenData),
    });
    const result = await response.json();
    if (!response.ok || result.success === false) {
      throw new Error(result.error || "Payment processing failed");
    }
    return result;
  };

  // SDK Mode: Handle payment result
  const handleSDKPaymentResult = async (result: PaymentResult): Promise<unknown> => {
    console.log("SDK Payment result:", result);
    return result;
  };

  // Reset to mode selection
  const handleBack = () => {
    setSelectedMode(null);
    setBackendData(null);
  };

  // Check if SDK mode fields are valid (no alert, just returns boolean)
  const areSDKFieldsValid = (): boolean => {
    return !!(baseUrl && apiUsername && apiSecret && accountName && amount && label);
  };

  // Check if New Architecture is enabled
  const isNewArchitecture = (global as any).__turboModuleProxy != null;

  // Render mode selection buttons
  const renderModeSelection = () => (
    <View style={styles.modeSelectionContainer}>
      <Text style={styles.modeTitle}>Select Payment Mode</Text>

      <TouchableOpacity
        style={styles.modeButton}
        onPress={() => setSelectedMode("backend")}
      >
        <Text style={styles.modeButtonTitle}>Backend Mode</Text>
        <Text style={styles.modeButtonSubtitle}>
          Recommended - API credentials stay secure on your server
        </Text>
      </TouchableOpacity>

      <TouchableOpacity
        style={[styles.modeButton, styles.modeButtonSecondary]}
        onPress={() => setSelectedMode("sdk")}
      >
        <Text style={styles.modeButtonTitle}>SDK Mode</Text>
        <Text style={styles.modeButtonSubtitle}>
          API credentials stored in app - simpler setup
        </Text>
      </TouchableOpacity>

      <Text style={styles.archIndicator}>
        New Architecture: {isNewArchitecture ? "Enabled" : "Disabled"}
      </Text>
    </View>
  );

  // Render Backend Mode UI
  const renderBackendMode = () => (
    <View>
      <TouchableOpacity style={styles.backButton} onPress={handleBack}>
        <Text style={styles.backButtonText}>← Back</Text>
      </TouchableOpacity>

      <Text style={styles.modeHeader}>Backend Mode</Text>
      <Text style={styles.modeDescription}>
        Server: {BACKEND_URL}
      </Text>

      {/* Amount and Label inputs */}
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

      {/* Mock payments toggle */}
      <View style={styles.switchRow}>
        <Text style={styles.inputLabel}>
          Enable mock payment (iOS Simulator)
        </Text>
        <Switch
          value={mockEnabled}
          onValueChange={(value) => {
            setMockPaymentsEnabled(value);
            setMockEnabled(value);
          }}
        />
      </View>

      {/* Prepare Payment button */}
      {!backendData && (
        <TouchableOpacity
          style={[styles.prepareButton, backendLoading && styles.buttonDisabled]}
          onPress={fetchBackendData}
          disabled={backendLoading || !amount || !label}
        >
          {backendLoading ? (
            <ActivityIndicator color="#fff" />
          ) : (
            <Text style={styles.prepareButtonText}>Prepare Payment</Text>
          )}
        </TouchableOpacity>
      )}

      {/* Apple Pay Button - shown when backend data is ready */}
      {backendData && (
        <View style={styles.paymentButtonContainer}>
          <Text style={styles.readyText}>Payment ready!</Text>
          <ApplePayButton
            backendData={backendData}
            onPressCallback={handleBackendPaymentToken}
            onPaymentSuccess={(result) => {
              console.log("Backend payment success:", result);
              Alert.alert("Success", "Payment completed successfully!");
              setBackendData(null);
            }}
            onPaymentError={(error) => {
              console.error("Backend payment error:", error);
              Alert.alert("Error", error.message || "Payment failed");
            }}
            onPaymentCanceled={() => {
              console.log("Payment canceled");
            }}
            buttonStyle="black"
            buttonType="buy"
          />
        </View>
      )}
    </View>
  );

  // Render SDK Mode UI
  const renderSDKMode = () => (
    <View>
      <TouchableOpacity style={styles.backButton} onPress={handleBack}>
        <Text style={styles.backButtonText}>← Back</Text>
      </TouchableOpacity>

      <Text style={styles.modeHeader}>SDK Mode</Text>

      {/* All configuration fields */}
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

      {/* Mock payments toggle */}
      <View style={styles.switchRow}>
        <Text style={styles.inputLabel}>
          Enable mock payment (iOS Simulator)
        </Text>
        <Switch
          value={mockEnabled}
          onValueChange={(value) => {
            setMockPaymentsEnabled(value);
            setMockEnabled(value);
          }}
        />
      </View>

      {/* Apple Pay Button */}
      <View style={styles.paymentButtonContainer}>
        {areSDKFieldsValid() ? (
          <ApplePayButton
            config={{
              apiUsername,
              apiSecret,
              baseUrl,
              accountName,
              countryCode: "EE",
            }}
            amount={parseFloat(amount)}
            label={label}
            onPressCallback={handleSDKPaymentResult}
            onPaymentSuccess={(result) => {
              console.log("SDK payment success:", result);
              Alert.alert("Success", "Payment completed successfully!");
            }}
            onPaymentError={(error) => {
              console.error("SDK payment error:", error);
              Alert.alert("Error", error.message || "Payment failed");
            }}
            onPaymentCanceled={() => {
              console.log("Payment canceled");
            }}
            buttonStyle="black"
            buttonType="buy"
          />
        ) : (
          <Text style={styles.fillFieldsText}>
            Fill in all required fields to enable Apple Pay
          </Text>
        )}
      </View>
    </View>
  );

  return (
    <ScrollView style={styles.container} contentContainerStyle={styles.contentContainer}>
      <Text style={styles.title}>LHV Everypay Apple Pay Demo</Text>

      {canPay === null ? (
        <ActivityIndicator size="small" />
      ) : canPay ? (
        <Text style={styles.subtitle}>Apple Pay available</Text>
      ) : (
        <Text style={styles.warning}>Apple Pay not available</Text>
      )}

      {selectedMode === null && renderModeSelection()}
      {selectedMode === "backend" && renderBackendMode()}
      {selectedMode === "sdk" && renderSDKMode()}
    </ScrollView>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: "#f5f5f7",
  },
  contentContainer: {
    paddingTop: 60,
    paddingHorizontal: 20,
    paddingBottom: 40,
  },
  title: {
    fontSize: 22,
    fontWeight: "bold",
    textAlign: "center",
    marginBottom: 10,
  },
  subtitle: {
    textAlign: "center",
    marginBottom: 10,
    color: "green",
  },
  warning: {
    textAlign: "center",
    marginBottom: 10,
    color: "orange",
  },
  // Mode selection styles
  modeSelectionContainer: {
    marginTop: 20,
  },
  modeTitle: {
    fontSize: 16,
    fontWeight: "600",
    textAlign: "center",
    marginBottom: 20,
    color: "#333",
  },
  modeButton: {
    backgroundColor: "#007AFF",
    borderRadius: 12,
    padding: 20,
    marginBottom: 16,
  },
  modeButtonSecondary: {
    backgroundColor: "#5856D6",
  },
  modeButtonTitle: {
    fontSize: 18,
    fontWeight: "bold",
    color: "#fff",
    marginBottom: 4,
  },
  modeButtonSubtitle: {
    fontSize: 13,
    color: "rgba(255,255,255,0.8)",
  },
  // Mode header styles
  modeHeader: {
    fontSize: 18,
    fontWeight: "bold",
    marginBottom: 4,
    color: "#333",
  },
  modeDescription: {
    fontSize: 12,
    color: "#666",
    marginBottom: 16,
  },
  // Back button
  backButton: {
    marginBottom: 12,
  },
  backButtonText: {
    fontSize: 16,
    color: "#007AFF",
  },
  // Input styles
  inputGroup: {
    marginBottom: 8,
  },
  inputLabel: {
    fontSize: 11,
    color: "#666",
    marginBottom: 2,
    fontWeight: "500",
  },
  input: {
    height: 36,
    borderColor: "#ccc",
    borderWidth: 1,
    borderRadius: 6,
    paddingHorizontal: 10,
    backgroundColor: "#fff",
    fontSize: 13,
  },
  required: {
    color: "red",
  },
  inputError: {
    borderColor: "red",
  },
  // Switch row
  switchRow: {
    flexDirection: "row",
    justifyContent: "space-between",
    alignItems: "center",
    marginVertical: 12,
  },
  // Prepare button
  prepareButton: {
    backgroundColor: "#34C759",
    borderRadius: 8,
    padding: 14,
    alignItems: "center",
    marginTop: 16,
  },
  prepareButtonText: {
    color: "#fff",
    fontSize: 16,
    fontWeight: "600",
  },
  buttonDisabled: {
    opacity: 0.6,
  },
  // Payment button container
  paymentButtonContainer: {
    marginTop: 20,
  },
  readyText: {
    textAlign: "center",
    color: "#34C759",
    fontWeight: "600",
    marginBottom: 12,
  },
  fillFieldsText: {
    textAlign: "center",
    color: "#999",
    fontStyle: "italic",
  },
  archIndicator: {
    textAlign: "center",
    color: "#888",
    fontSize: 12,
    marginTop: 30,
  },
});

export default App;
