export interface InitPaymentInput {
  auth: {
    apiUsername: string;
    apiSecret: string;
  };
  endpoints: {
    initUrl: string;
  };
  data: {
    accountName: string;
    amount: number;
    orderReference: string;
    customerUrl?: string;
    locale?: string;
    customerIp?: string;
  };
}

export interface InitPaymentOutput {
  success: boolean;
  data: EverypayInitResponse;
  errorMessage?: string;
}

export interface EverypayPaymentMethod {
  source: string; // e.g., 'card'
  displayName: string;
  countryCode?: string;
  paymentLink: string;
  logoUrl: string;
  applepayAvailable: boolean;
  googlepayAvailable: boolean;
  walletDisplayName: string;
  available: boolean;
}

export interface EverypayInitResponse {
  accountName: string;
  orderReference: string;
  email?: string;
  customerIp?: string;
  customerUrl: string;
  paymentCreatedAt: string; // ISO date string
  initialAmount: number;
  standingAmount: number;
  paymentReference: string;
  paymentLink: string;
  paymentMethods: EverypayPaymentMethod[];
  apiUsername: string;
  warnings: Record<string, any>;
  stan?: string;
  fraudScore?: number;
  paymentState: string;
  paymentMethod?: string;
  mobileAccessToken: string;
  currency: string;
  applepayMerchantIdentifier: string;
  descriptorCountry: string;
  googlepayMerchantIdentifier: string;
}

export interface InitAndStartPaymentInput {
  auth: {
    apiUsername: string;
    apiSecret: string;
  };
  endpoints: {
    initMobileOneoffUrl: string;
    paymentSessionUrl: string;
    authorizePaymentUrl: string;
    paymentDetailUrl: string;
  };
  data: {
    accountName: string;
    amount: number;
    label: string;
    orderReference?: string;
    customerUrl?: string;
    locale?: string;
    customerIp?: string;
  };
}

export interface StartPaymentInput {
  endpoints: {
    paymentSessionUrl: string;
    authorizePaymentUrl: string;
    paymentDetailUrl: string;
  };
  data: {
    paymentReference: string;
    paymentLink: string;
    countryCode: string;
    currencyCode: string;
    amount: number;
    label: string;
    merchantId: string;
    accessToken: string;
  };
}

export interface PaymentOutput {
  success: boolean;
  status: string;
  errorMessage?: string;
  data?: {
    paymentReference?: string;
    transactionId?: string;
    rawResponse?: any;
  };
}

// ✅ Types for success and failure events
export interface ApplePaySuccessEvent {
  paymentReference: string;
  rawResponse?: any;
}

export interface ApplePayFailureEvent {
  errorMessage: string;
}

