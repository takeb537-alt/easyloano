class Validators {
  /// Full name: only letters and spaces, min 3 chars
  static String? validateName(String? value) {
    if (value == null || value.trim().isEmpty) return 'Name is required';
    if (!RegExp(r'^[a-zA-Z\s]+$').hasMatch(value.trim())) {
      return 'Name must contain letters only';
    }
    if (value.trim().length < 3) return 'Name must be at least 3 characters';
    return null;
  }

  /// Mobile: 10 digits, starts with 6/7/8/9
  static String? validateMobile(String? value) {
    if (value == null || value.trim().isEmpty) return 'Mobile number is required';
    if (!RegExp(r'^[6-9][0-9]{9}$').hasMatch(value.trim())) {
      return 'Enter valid 10-digit Indian mobile number';
    }
    return null;
  }

  /// PAN: ABCDE1234F format
  static String? validatePAN(String? value) {
    if (value == null || value.trim().isEmpty) return 'PAN card is required';
    if (!RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]{1}$').hasMatch(value.trim().toUpperCase())) {
      return 'Invalid PAN format (e.g. ABCDE1234F)';
    }
    return null;
  }

  /// UPI: must contain @
  static String? validateUPI(String? value) {
    if (value == null || value.trim().isEmpty) return 'UPI ID is required';
    if (!value.contains('@')) return 'UPI ID must contain @';
    if (!RegExp(r'^[\w.\-]+@[\w]+$').hasMatch(value.trim())) {
      return 'Enter valid UPI ID (e.g. name@upi)';
    }
    return null;
  }

  /// DOB: must be 18+
  static String? validateDOB(String? value) {
    if (value == null || value.trim().isEmpty) return 'Date of birth is required';
    try {
      final parts = value.split('/');
      if (parts.length != 3) return 'Use DD/MM/YYYY format';
      final dob = DateTime(
        int.parse(parts[2]),
        int.parse(parts[1]),
        int.parse(parts[0]),
      );
      final age = DateTime.now().difference(dob).inDays ~/ 365;
      if (age < 18) return 'You must be at least 18 years old';
    } catch (_) {
      return 'Invalid date format';
    }
    return null;
  }
}
