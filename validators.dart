// ============================================
// EasyLoan - Validators
// Complete validation with regex & algorithms
// ============================================

class Validators {
  // ─── Phone Number ───────────────────────────
  static String? validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return 'Mobile number is required';
    }
    // Remove spaces and +91 prefix if present
    String cleaned = value.replaceAll(RegExp(r'[\s\-]'), '');
    if (cleaned.startsWith('+91')) cleaned = cleaned.substring(3);
    if (cleaned.startsWith('91') && cleaned.length == 12) {
      cleaned = cleaned.substring(2);
    }

    if (cleaned.length != 10) {
      return 'Enter a valid 10-digit mobile number';
    }
    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(cleaned)) {
      return 'Mobile number must start with 6, 7, 8, or 9';
    }
    return null;
  }

  // ─── OTP ────────────────────────────────────
  static String? validateOTP(String? value) {
    if (value == null || value.isEmpty) return 'OTP is required';
    if (!RegExp(r'^\d{6}$').hasMatch(value)) {
      return 'Enter a valid 6-digit OTP';
    }
    return null;
  }

  // ─── Full Name ──────────────────────────────
  static String? validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Full name is required';
    }
    if (value.trim().length < 3) {
      return 'Name must be at least 3 characters';
    }
    if (!RegExp(r'^[a-zA-Z\s]+$').hasMatch(value.trim())) {
      return 'Name can only contain letters and spaces';
    }
    if (value.trim().split(' ').length < 2) {
      return 'Please enter your full name (first & last)';
    }
    return null;
  }

  // ─── Date of Birth (18+ check) ──────────────
  static String? validateDOB(DateTime? dob) {
    if (dob == null) return 'Date of birth is required';
    final now = DateTime.now();
    final age = now.year - dob.year -
        ((now.month < dob.month ||
            (now.month == dob.month && now.day < dob.day))
            ? 1
            : 0);
    if (age < 18) return 'You must be at least 18 years old';
    if (age > 70) return 'Invalid date of birth';
    return null;
  }

  // ─── PAN Card ───────────────────────────────
  static String? validatePAN(String? value) {
    if (value == null || value.isEmpty) return 'PAN card number is required';
    final pan = value.trim().toUpperCase();
    if (!RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]{1}$').hasMatch(pan)) {
      return 'Invalid PAN format (e.g. ABCDE1234F)';
    }
    return null;
  }

  // ─── Aadhaar with Verhoeff Checksum ─────────
  static String? validateAadhaar(String? value) {
    if (value == null || value.isEmpty) return 'Aadhaar number is required';
    final aadhaar = value.replaceAll(RegExp(r'\s'), '');
    if (!RegExp(r'^\d{12}$').hasMatch(aadhaar)) {
      return 'Aadhaar must be exactly 12 digits';
    }
    if (!_verhoeffCheck(aadhaar)) {
      return 'Invalid Aadhaar number';
    }
    return null;
  }

  // Verhoeff Algorithm for Aadhaar validation
  static bool _verhoeffCheck(String number) {
    // Verhoeff multiplication table
    const List<List<int>> d = [
      [0, 1, 2, 3, 4, 5, 6, 7, 8, 9],
      [1, 2, 3, 4, 0, 6, 7, 8, 9, 5],
      [2, 3, 4, 0, 1, 7, 8, 9, 5, 6],
      [3, 4, 0, 1, 2, 8, 9, 5, 6, 7],
      [4, 0, 1, 2, 3, 9, 5, 6, 7, 8],
      [5, 9, 8, 7, 6, 0, 4, 3, 2, 1],
      [6, 5, 9, 8, 7, 1, 0, 4, 3, 2],
      [7, 6, 5, 9, 8, 2, 1, 0, 4, 3],
      [8, 7, 6, 5, 9, 3, 2, 1, 0, 4],
      [9, 8, 7, 6, 5, 4, 3, 2, 1, 0],
    ];

    // Verhoeff permutation table
    const List<List<int>> p = [
      [0, 1, 2, 3, 4, 5, 6, 7, 8, 9],
      [1, 5, 7, 6, 2, 8, 3, 0, 9, 4],
      [5, 8, 0, 3, 7, 9, 6, 1, 4, 2],
      [8, 9, 1, 6, 0, 4, 3, 5, 2, 7],
      [9, 4, 5, 3, 1, 2, 6, 8, 7, 0],
      [4, 2, 8, 6, 5, 7, 3, 9, 0, 1],
      [2, 7, 9, 3, 8, 0, 6, 4, 1, 5],
      [7, 0, 4, 6, 9, 1, 3, 2, 5, 8],
    ];

    int c = 0;
    final digits = number.split('').reversed.map(int.parse).toList();

    for (int i = 0; i < digits.length; i++) {
      c = d[c][p[i % 8][digits[i]]];
    }
    return c == 0;
  }

  // ─── UPI ID ─────────────────────────────────
  static String? validateUPI(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'UPI ID is required';
    }
    final upi = value.trim().toLowerCase();
    if (!upi.contains('@')) {
      return 'UPI ID must contain @';
    }
    if (!RegExp(r'^[a-zA-Z0-9._\-]+@[a-zA-Z]{3,}$').hasMatch(upi)) {
      return 'Invalid UPI ID format (e.g. name@upi)';
    }
    return null;
  }

  // ─── Email (Optional) ───────────────────────
  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) return null; // Optional
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
      return 'Enter a valid email address';
    }
    return null;
  }

  // ─── Payment Amount ─────────────────────────
  static String? validatePaymentAmount(String? value, double maxAmount) {
    if (value == null || value.isEmpty) return 'Amount is required';
    final amount = double.tryParse(value);
    if (amount == null) return 'Enter a valid amount';
    if (amount < 10) return 'Minimum payment is ₹10';
    if (amount > maxAmount) return 'Amount cannot exceed ₹${maxAmount.toStringAsFixed(0)}';
    return null;
  }

  // ─── Gender ─────────────────────────────────
  static String? validateGender(String? value) {
    if (value == null || value.isEmpty) return 'Please select your gender';
    return null;
  }

  // Clean phone number to 10 digits
  static String cleanPhone(String phone) {
    String cleaned = phone.replaceAll(RegExp(r'[\s\-]'), '');
    if (cleaned.startsWith('+91')) return cleaned.substring(3);
    if (cleaned.startsWith('91') && cleaned.length == 12) {
      return cleaned.substring(2);
    }
    return cleaned;
  }

  // Format Aadhaar for display (XXXX XXXX XXXX)
  static String formatAadhaar(String aadhaar) {
    final clean = aadhaar.replaceAll(' ', '');
    if (clean.length != 12) return aadhaar;
    return '${clean.substring(0, 4)} ${clean.substring(4, 8)} ${clean.substring(8)}';
  }

  // Mask Aadhaar for display (XXXX XXXX 1234)
  static String maskAadhaar(String aadhaar) {
    final clean = aadhaar.replaceAll(' ', '');
    if (clean.length != 12) return aadhaar;
    return 'XXXX XXXX ${clean.substring(8)}';
  }
}