// ============================================
// EasyLoan - PhoneAuthScreen
// Firebase Phone Auth with OTP
// Real-time validation, 60s resend timer
// ============================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../utils/constants.dart';
import '../utils/validators.dart';
import '../widgets/common_widgets.dart';

class PhoneAuthScreen extends StatefulWidget {
  const PhoneAuthScreen({super.key});

  @override
  State<PhoneAuthScreen> createState() => _PhoneAuthScreenState();
}

class _PhoneAuthScreenState extends State<PhoneAuthScreen> {
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();

  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _phoneFocusNode = FocusNode();
  final _otpFocusNode = FocusNode();
  final _phoneFormKey = GlobalKey<FormState>();
  final _otpFormKey = GlobalKey<FormState>();

  bool _otpSent = false;
  bool _isLoading = false;
  String? _verificationId;
  String? _phoneError;
  String? _otpError;

  // Resend timer
  int _resendSeconds = 60;
  Timer? _resendTimer;
  bool _canResend = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    _phoneFocusNode.dispose();
    _otpFocusNode.dispose();
    _resendTimer?.cancel();
    super.dispose();
  }

  void _startResendTimer() {
    _resendSeconds = 60;
    _canResend = false;
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _resendSeconds--;
        if (_resendSeconds <= 0) {
          _canResend = true;
          timer.cancel();
        }
      });
    });
  }

  Future<void> _sendOTP() async {
    // Validate phone
    final error = Validators.validatePhone(_phoneController.text);
    if (error != null) {
      setState(() => _phoneError = error);
      return;
    }

    setState(() {
      _isLoading = true;
      _phoneError = null;
    });

    // Haptic feedback
    HapticFeedback.mediumImpact();

    await _authService.sendOTP(
      phoneNumber: Validators.cleanPhone(_phoneController.text),
      onCodeSent: (verificationId) {
        if (!mounted) return;
        setState(() {
          _verificationId = verificationId;
          _otpSent = true;
          _isLoading = false;
        });
        _startResendTimer();
        // Focus OTP field
        Future.delayed(
          const Duration(milliseconds: 300),
          () => _otpFocusNode.requestFocus(),
        );
      },
      onError: (error) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _phoneError = error;
        });
      },
      onAutoVerified: (credential) async {
        // Auto OTP verification on Android
        if (!mounted) return;
        setState(() => _isLoading = true);
        try {
          final userCredential =
              await _authService.verifyOTP(otp: '', verificationId: null);
          if (userCredential != null && mounted) {
            _onAuthSuccess(userCredential.user!.uid);
          }
        } catch (e) {
          if (mounted) setState(() => _isLoading = false);
        }
      },
    );
  }

  Future<void> _verifyOTP() async {
    // Validate OTP
    final error = Validators.validateOTP(_otpController.text);
    if (error != null) {
      setState(() => _otpError = error);
      return;
    }

    setState(() {
      _isLoading = true;
      _otpError = null;
    });

    HapticFeedback.mediumImpact();

    try {
      final userCredential = await _authService.verifyOTP(
        otp: _otpController.text.trim(),
        verificationId: _verificationId,
      );

      if (userCredential != null && mounted) {
        // Create user in Firestore if new
        await _firestoreService.createUser(
          userId: userCredential.user!.uid,
          phoneNumber: '+91${Validators.cleanPhone(_phoneController.text)}',
        );
        _onAuthSuccess(userCredential.user!.uid);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _otpError = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  Future<void> _onAuthSuccess(String userId) async {
    setState(() => _isLoading = true);

    try {
      // Check KYC step
      final userData = await _firestoreService.getUser();
      if (!mounted) return;

      final kycStep = userData?['kycStep'] ?? 1;
      final kycCompleted = userData?['kycCompleted'] ?? false;

      if (kycCompleted) {
        Navigator.pushReplacementNamed(context, AppRoutes.dashboard);
        return;
      }

      // Navigate to correct KYC step
      switch (kycStep) {
        case 1:
          Navigator.pushReplacementNamed(context, AppRoutes.faceVerification);
          break;
        case 2:
          Navigator.pushReplacementNamed(context, AppRoutes.basicDetails);
          break;
        case 3:
          Navigator.pushReplacementNamed(context, AppRoutes.panVerification);
          break;
        case 4:
          Navigator.pushReplacementNamed(
              context, AppRoutes.aadhaarVerification);
          break;
        case 5:
          Navigator.pushReplacementNamed(context, AppRoutes.upiVerification);
          break;
        default:
          Navigator.pushReplacementNamed(context, AppRoutes.faceVerification);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      Navigator.pushReplacementNamed(context, AppRoutes.faceVerification);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: _otpSent
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new),
                onPressed: () => setState(() {
                  _otpSent = false;
                  _otpController.clear();
                  _resendTimer?.cancel();
                }),
              )
            : null,
        title: Text(
          _otpSent ? 'Verify OTP' : 'Login / Register',
          style: AppTextStyles.heading3,
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppDimensions.paddingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // KYC Step indicator
            _KYCStepIndicator(currentStep: 1, totalSteps: 6),
            const SizedBox(height: 32),

            // Header
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _otpSent
                  ? _OTPHeader(
                      phone: Validators.cleanPhone(_phoneController.text),
                    )
                  : const _PhoneHeader(),
            ),

            const SizedBox(height: 32),

            // Phone input or OTP input
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _otpSent
                  ? _OTPSection(
                      controller: _otpController,
                      focusNode: _otpFocusNode,
                      error: _otpError,
                      canResend: _canResend,
                      resendSeconds: _resendSeconds,
                      onChanged: (value) {
                        if (_otpError != null) {
                          setState(() => _otpError = null);
                        }
                        if (value.length == 6) _verifyOTP();
                      },
                      onResend: _sendOTP,
                    )
                  : _PhoneSection(
                      controller: _phoneController,
                      focusNode: _phoneFocusNode,
                      error: _phoneError,
                      onChanged: (value) {
                        if (_phoneError != null) {
                          setState(() => _phoneError = null);
                        }
                      },
                    ),
            ),

            const SizedBox(height: 32),

            // Action Button
            AppButton(
              label: _otpSent ? 'Verify OTP' : 'Send OTP',
              isLoading: _isLoading,
              onPressed: _otpSent ? _verifyOTP : _sendOTP,
            ),

            const SizedBox(height: 24),

            // Terms text
            const Center(
              child: Text(
                'By continuing, you agree to our Terms & Privacy Policy',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textHint,
                  fontFamily: 'Poppins',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Sub-widgets ─────────────────────────────

class _KYCStepIndicator extends StatelessWidget {
  final int currentStep;
  final int totalSteps;

  const _KYCStepIndicator({
    required this.currentStep,
    required this.totalSteps,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: List.generate(totalSteps, (index) {
            final isCompleted = index < currentStep - 1;
            final isCurrent = index == currentStep - 1;
            return Expanded(
              child: Container(
                margin: const EdgeInsets.only(right: 4),
                height: 4,
                decoration: BoxDecoration(
                  color: isCompleted || isCurrent
                      ? AppColors.primary
                      : AppColors.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 8),
        Text(
          'Step $currentStep of $totalSteps: ${AppStrings.kycSteps[currentStep - 1]}',
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
            fontFamily: 'Poppins',
          ),
        ),
      ],
    );
  }
}

class _PhoneHeader extends StatelessWidget {
  const _PhoneHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.phone_android, color: AppColors.primary, size: 28),
        ),
        const SizedBox(height: 16),
        const Text('Enter your\nmobile number', style: AppTextStyles.heading1),
        const SizedBox(height: 8),
        const Text(
          'We\'ll send a 6-digit OTP to verify your number',
          style: AppTextStyles.bodyMedium,
        ),
      ],
    );
  }
}

class _OTPHeader extends StatelessWidget {
  final String phone;
  const _OTPHeader({required this.phone});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.success.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.sms, color: AppColors.success, size: 28),
        ),
        const SizedBox(height: 16),
        const Text('OTP Sent!', style: AppTextStyles.heading1),
        const SizedBox(height: 8),
        Text(
          'Enter the 6-digit OTP sent to +91 $phone',
          style: AppTextStyles.bodyMedium,
        ),
      ],
    );
  }
}

class _PhoneSection extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String? error;
  final ValueChanged<String> onChanged;

  const _PhoneSection({
    required this.controller,
    required this.focusNode,
    this.error,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextFormField(
          controller: controller,
          focusNode: focusNode,
          keyboardType: TextInputType.phone,
          maxLength: 10,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: onChanged,
          decoration: InputDecoration(
            prefixIcon: Container(
              margin: const EdgeInsets.symmetric(horizontal: 12),
              child: const Text(
                '+91',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                  fontFamily: 'Poppins',
                ),
              ),
            ),
            prefixIconConstraints: const BoxConstraints(minWidth: 0),
            hintText: '10-digit mobile number',
            counterText: '',
            errorText: error,
          ),
        ),
      ],
    );
  }
}

class _OTPSection extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String? error;
  final bool canResend;
  final int resendSeconds;
  final ValueChanged<String> onChanged;
  final VoidCallback onResend;

  const _OTPSection({
    required this.controller,
    required this.focusNode,
    this.error,
    required this.canResend,
    required this.resendSeconds,
    required this.onChanged,
    required this.onResend,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: controller,
          focusNode: focusNode,
          keyboardType: TextInputType.number,
          maxLength: 6,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: onChanged,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            letterSpacing: 8,
            fontFamily: 'Poppins',
          ),
          decoration: InputDecoration(
            hintText: '------',
            hintStyle: const TextStyle(letterSpacing: 8),
            counterText: '',
            errorText: error,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              "Didn't receive OTP? ",
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                fontFamily: 'Poppins',
              ),
            ),
            if (canResend)
              GestureDetector(
                onTap: onResend,
                child: const Text(
                  'Resend',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Poppins',
                  ),
                ),
              )
            else
              Text(
                'Resend in ${resendSeconds}s',
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textHint,
                  fontFamily: 'Poppins',
                ),
              ),
          ],
        ),
      ],
    );
  }
}