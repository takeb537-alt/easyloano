// ============================================
// EasyLoan - RazorpayService
// Razorpay payments + UPI Autopay mandates
// Bajaj Finance style permanent mandate
// ============================================

import 'package:flutter/material.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'firestore_service.dart';
import '../utils/constants.dart';

class PaymentResult {
  final bool success;
  final String? paymentId;
  final String? orderId;
  final String? error;

  const PaymentResult({
    required this.success,
    this.paymentId,
    this.orderId,
    this.error,
  });
}

class RazorpayService {
  static final RazorpayService _instance = RazorpayService._internal();
  factory RazorpayService() => _instance;
  RazorpayService._internal();

  late Razorpay _razorpay;
  final FirestoreService _firestoreService = FirestoreService();

  // Callbacks
  Function(PaymentResult)? _onPaymentSuccess;
  Function(String)? _onPaymentError;

  // Razorpay Key from --dart-define
  static const String _keyId =
      String.fromEnvironment('RAZORPAY_KEY_ID', defaultValue: 'rzp_test_xxxx');

  /// Initialize Razorpay listeners
  void initialize() {
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  /// Dispose Razorpay instance
  void dispose() {
    _razorpay.clear();
  }

  // ─── PAYMENT HANDLERS ───────────────────────

  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    final result = PaymentResult(
      success: true,
      paymentId: response.paymentId,
      orderId: response.orderId,
    );
    _onPaymentSuccess?.call(result);
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    String errorMessage;
    switch (response.code) {
      case Razorpay.PAYMENT_CANCELLED:
        errorMessage = 'Payment was cancelled. Please try again.';
        break;
      case Razorpay.NETWORK_ERROR:
        errorMessage = 'Network error. Please check your connection.';
        break;
      default:
        errorMessage = response.message ?? 'Payment failed. Please try again.';
    }
    _onPaymentError?.call(errorMessage);
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    // Handle external wallet if needed
    debugPrint('External wallet: ${response.walletName}');
  }

  // ─── ₹1 UPI VERIFICATION ────────────────────

  /// Initiate ₹1 UPI verification payment
  void initiateUPIVerification({
    required String upiId,
    required String userName,
    required String userPhone,
    required Function(PaymentResult) onSuccess,
    required Function(String) onError,
  }) {
    _onPaymentSuccess = onSuccess;
    _onPaymentError = onError;

    final options = {
      'key': _keyId,
      'amount': 100, // ₹1 in paise
      'name': AppStrings.appName,
      'description': 'UPI ID Verification',
      'prefill': {
        'contact': userPhone,
        'name': userName,
        'vpa': upiId, // Pre-fill UPI ID
      },
      'method': {
        'upi': true,
        'card': false,
        'netbanking': false,
        'wallet': false,
      },
      'theme': {
        'color': '#1565C0',
      },
      'notes': {
        'purpose': 'upi_verification',
      },
    };

    _razorpay.open(options);
  }

  // ─── LOAN REPAYMENT ─────────────────────────

  /// Initiate loan repayment payment
  void initiateLoanPayment({
    required double amount,
    required String loanId,
    required String userName,
    required String userPhone,
    required String userEmail,
    required Function(PaymentResult) onSuccess,
    required Function(String) onError,
  }) {
    _onPaymentSuccess = onSuccess;
    _onPaymentError = onError;

    final amountInPaise = (amount * 100).toInt();

    final options = {
      'key': _keyId,
      'amount': amountInPaise,
      'name': AppStrings.appName,
      'description': 'Loan Repayment - $loanId',
      'prefill': {
        'contact': userPhone,
        'name': userName,
        'email': userEmail.isNotEmpty ? userEmail : 'user@easyloan.in',
      },
      'method': {
        'upi': true,
        'card': true,
        'netbanking': true,
        'wallet': true,
      },
      'theme': {
        'color': '#1565C0',
      },
      'notes': {
        'loanId': loanId,
        'purpose': 'loan_repayment',
      },
    };

    _razorpay.open(options);
  }

  // ─── UPI AUTOPAY MANDATE ─────────────────────
  // Creates a recurring UPI mandate after ₹1 verification
  // Mandate stays active until loan is fully repaid
  // User CANNOT cancel from app while loan is pending

  /// Create UPI Autopay mandate via Razorpay
  void createAutoPayMandate({
    required String upiId,
    required double maxAmount,
    required String loanId,
    required String userName,
    required String userPhone,
    required DateTime endDate,
    required Function(PaymentResult) onSuccess,
    required Function(String) onError,
  }) {
    _onPaymentSuccess = onSuccess;
    _onPaymentError = onError;

    // Mandate options for Razorpay UPI Autopay
    final options = {
      'key': _keyId,
      'type': 'link',
      'subscription': {
        'type': 'emandate',
        'auth_type': 'netbanking', // or 'debitcard' for UPI
        'bank_account': {
          'beneficiary_name': userName,
        },
      },
      'name': AppStrings.appName,
      'description': 'AutoPay Mandate for Loan $loanId',
      'prefill': {
        'contact': userPhone,
        'name': userName,
        'vpa': upiId,
      },
      'recurring': 1,
      'theme': {
        'color': '#1565C0',
      },
      'notes': {
        'loanId': loanId,
        'purpose': 'autopay_mandate',
        'maxAmount': maxAmount.toString(),
      },
    };

    _razorpay.open(options);
  }

  // ─── MANDATE CANCELLATION CHECK ─────────────

  /// Shows dialog preventing mandate cancellation while loan is active
  static Future<void> showMandateCancelBlockedDialog(
    BuildContext context,
  ) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.lock,
                color: Color(0xFFEF4444),
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Cannot Cancel Mandate',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A2E),
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Your AutoPay mandate is linked to an active loan. Full payment is required before you can cancel the mandate.',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF6B7280),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info, color: Color(0xFFF59E0B), size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Auto-debit will continue until your loan is fully repaid.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF92400E),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1565C0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Understood',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}