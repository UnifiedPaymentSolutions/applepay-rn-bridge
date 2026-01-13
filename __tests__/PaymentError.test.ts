import { PaymentError } from '../src/payment/types';

describe('PaymentError', () => {
  it('should create error with message and code', () => {
    const error = new PaymentError('Payment failed', 'payment_failed');

    expect(error.message).toBe('Payment failed');
    expect(error.code).toBe('payment_failed');
    expect(error.name).toBe('ApplePayError');
  });

  it('should be an instance of Error', () => {
    const error = new PaymentError('Test error', 'test_code');

    expect(error).toBeInstanceOf(Error);
    expect(error).toBeInstanceOf(PaymentError);
  });

  it('should have correct prototype chain', () => {
    const error = new PaymentError('Test', 'code');

    // This ensures instanceof checks work correctly
    expect(Object.getPrototypeOf(error)).toBe(PaymentError.prototype);
  });

  it('should support common error codes', () => {
    const cancelledError = new PaymentError('User cancelled', 'cancelled');
    expect(cancelledError.code).toBe('cancelled');

    const initFailedError = new PaymentError('Init failed', 'init_failed');
    expect(initFailedError.code).toBe('init_failed');

    const authFailedError = new PaymentError(
      'Authorization failed',
      'authorization_failed'
    );
    expect(authFailedError.code).toBe('authorization_failed');

    const backendRejectedError = new PaymentError(
      'Backend rejected',
      'backend_rejected'
    );
    expect(backendRejectedError.code).toBe('backend_rejected');
  });

  it('should be throwable and catchable', () => {
    expect(() => {
      throw new PaymentError('Test throw', 'test');
    }).toThrow(PaymentError);

    try {
      throw new PaymentError('Caught error', 'caught_code');
    } catch (e) {
      if (e instanceof PaymentError) {
        expect(e.code).toBe('caught_code');
        expect(e.message).toBe('Caught error');
      } else {
        fail('Expected PaymentError instance');
      }
    }
  });

  it('should have stack trace', () => {
    const error = new PaymentError('Stack test', 'stack_code');
    expect(error.stack).toBeDefined();
    expect(error.stack).toContain('PaymentError');
  });
});
