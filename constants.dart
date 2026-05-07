// ============================================
// EasyLoan - App Constants
// All app-wide constants defined here
// ============================================

import 'package:flutter/material.dart';

class AppColors {
  // Primary Colors
  static const Color primary = Color(0xFF1565C0);
  static const Color primaryDark = Color(0xFF0D47A1);
  static const Color primaryLight = Color(0xFF1976D2);
  static const Color accent = Color(0xFF42A5F5);

  // Background & Surface
  static const Color background = Color(0xFFFFFFFF);
  static const Color surface = Color(0xFFF8F9FA);
  static const Color cardBg = Color(0xFFFFFFFF);

  // Text Colors
  static const Color textPrimary = Color(0xFF1A1A2E);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textHint = Color(0xFF9CA3AF);

  // Status Colors
  static const Color success = Color(0xFF10B981);
  static const Color error = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
  static const Color info = Color(0xFF3B82F6);

  // Loan Status Colors
  static const Color active = Color(0xFF10B981);
  static const Color overdue = Color(0xFFEF4444);
  static const Color pending = Color(0xFFF59E0B);
  static const Color completed = Color(0xFF6B7280);

  // Gradient
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF1565C0), Color(0xFF1976D2)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [Color(0xFF1565C0), Color(0xFF0D47A1)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class AppTextStyles {
  static const String fontFamily = 'Poppins';

  static const TextStyle heading1 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 28,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    letterSpacing: -0.5,
  );

  static const TextStyle heading2 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 22,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static const TextStyle heading3 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );

  static const TextStyle caption = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.textHint,
  );

  static const TextStyle button = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: Colors.white,
    letterSpacing: 0.5,
  );

  static const TextStyle amount = TextStyle(
    fontFamily: fontFamily,
    fontSize: 32,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );

  static const TextStyle amountSmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );
}

class AppDimensions {
  // Border Radius
  static const double radiusSmall = 8.0;
  static const double radiusMedium = 12.0;
  static const double radiusLarge = 16.0;
  static const double radiusXL = 24.0;
  static const double radiusCircle = 100.0;

  // Padding
  static const double paddingXS = 4.0;
  static const double paddingS = 8.0;
  static const double paddingM = 16.0;
  static const double paddingL = 24.0;
  static const double paddingXL = 32.0;

  // Button Height
  static const double buttonHeight = 56.0;
  static const double buttonHeightSmall = 44.0;

  // Card Elevation
  static const double cardElevation = 2.0;
  static const double cardElevationHigh = 8.0;

  // Icon sizes
  static const double iconSmall = 16.0;
  static const double iconMedium = 24.0;
  static const double iconLarge = 32.0;
  static const double iconXL = 48.0;
}

class LoanConstants {
  // Regular Loan Amounts (₹)
  static const List<int> regularLoanAmounts = [
    100, 200, 300, 400, 500, 600, 700, 800, 900, 1000, 1500, 2000
  ];

  // Recharge Loan Plans
  static const List<Map<String, dynamic>> rechargePlans = [
    {'loanAmount': 19, 'returnAmount': 25, 'tenure': 10, 'label': '₹19 Plan'},
    {'loanAmount': 39, 'returnAmount': 50, 'tenure': 10, 'label': '₹39 Plan'},
    {'loanAmount': 99, 'returnAmount': 140, 'tenure': 10, 'label': '₹99 Plan'},
  ];

  // Fixed fee for regular loans
  static const int regularLoanFee = 100;

  // Regular loan tenure in days
  static const int regularLoanTenure = 15;

  // Penalty applies on day 16
  static const int penaltyDay = 16;

  // Minimum payment amount
  static const double minPaymentAmount = 10.0;

  // UPI verification amount
  static const double upiVerificationAmount = 1.0;

  // Loan Unlock thresholds
  static const int firstUnlockRepayments = 3; // ₹500-₹1000
  static const int secondUnlockRepayments = 6; // ₹1500-₹2000

  // Loan amount tiers
  static const List<int> tier1Amounts = [100, 200]; // Always unlocked
  static const List<int> tier2Amounts = [300, 400, 500, 600, 700, 800, 900, 1000];
  static const List<int> tier3Amounts = [1500, 2000];
}

class FirestoreCollections {
  static const String users = 'users';
  static const String loans = 'loans';
  static const String transactions = 'transactions';
  static const String blacklist = 'blacklist';
  static const String mandates = 'mandates';
  static const String notifications = 'notifications';
}

class LoanStatus {
  static const String pending = 'pending';
  static const String active = 'active';
  static const String overdue = 'overdue';
  static const String completed = 'completed';
  static const String rejected = 'rejected';
}

class TransactionType {
  static const String disbursement = 'disbursement';
  static const String repayment = 'repayment';
  static const String penalty = 'penalty';
  static const String upiVerification = 'upi_verification';
  static const String autopay = 'autopay';
}

class AppStrings {
  static const String appName = 'EasyLoan';
  static const String tagline = 'Fast Loans, Easy Life';

  // Error Messages
  static const String networkError = 'Network error. Please check your connection.';
  static const String genericError = 'Something went wrong. Please try again.';
  static const String sessionExpired = 'Session expired. Please login again.';

  // Permission Messages
  static const String permissionRequired = 'All permissions are required to use EasyLoan';
  static const String cameraPermission = 'Camera access needed for face verification';
  static const String storagePermission = 'Storage access needed to save loan agreements';
  static const String locationPermission = 'Location access needed for security verification';
  static const String contactsPermission = 'Contacts access needed for emergency contact';

  // KYC Steps
  static const List<String> kycSteps = [
    'Mobile Verification',
    'Face Verification',
    'Basic Details',
    'PAN Verification',
    'Aadhaar Verification',
    'UPI Setup',
  ];
}

class AppRoutes {
  static const String splash = '/';
  static const String onboarding = '/onboarding';
  static const String phoneAuth = '/phone-auth';
  static const String faceVerification = '/face-verification';
  static const String basicDetails = '/basic-details';
  static const String panVerification = '/pan-verification';
  static const String aadhaarVerification = '/aadhaar-verification';
  static const String upiVerification = '/upi-verification';
  static const String dashboard = '/dashboard';
  static const String loanApplication = '/loan-application';
  static const String repayment = '/repayment';
  static const String myLoans = '/my-loans';
  static const String profile = '/profile';
  static const String loanDetails = '/loan-details';
  static const String notifications = '/notifications';
}