import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/loan_provider.dart';
import '../utils/validators.dart';
import 'face_verification_screen.dart';

class KycScreen extends StatefulWidget {
  const KycScreen({super.key});

  @override
  State<KycScreen> createState() => _KycScreenState();
}

class _KycScreenState extends State<KycScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCon = TextEditingController();
  final _mobileCon = TextEditingController();
  final _panCon = TextEditingController();
  final _dobCon = TextEditingController();
  final _upiCon = TextEditingController();

  bool _termsAccepted = false;
  bool _isLoading = false;
  List<String> _faceImages = [];

  @override
  void dispose() {
    _nameCon.dispose();
    _mobileCon.dispose();
    _panCon.dispose();
    _dobCon.dispose();
    _upiCon.dispose();
    super.dispose();
  }

  Future<void> _pickDOB() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 22, now.month, now.day),
      firstDate: DateTime(1950),
      lastDate: DateTime(now.year - 18, now.month, now.day),
      helpText: 'Select Date of Birth',
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: Color(0xFF1565C0)),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      _dobCon.text = DateFormat('dd/MM/yyyy').format(picked);
    }
  }

  Future<void> _startFaceVerification() async {
    final images = await Navigator.push<List<String>>(
      context,
      MaterialPageRoute(builder: (_) => const FaceVerificationScreen()),
    );
    if (images != null && images.isNotEmpty) {
      setState(() => _faceImages = images);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Face verified successfully!'),
          backgroundColor: Color(0xFF2E7D32),
        ),
      );
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_faceImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please complete face verification'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (!_termsAccepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please accept Terms & Conditions'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final user = UserModel(
      fullName: _nameCon.text.trim(),
      mobile: _mobileCon.text.trim(),
      pan: _panCon.text.trim().toUpperCase(),
      dob: _dobCon.text.trim(),
      upiId: _upiCon.text.trim(),
      faceImages: _faceImages,
    );

    await context.read<LoanProvider>().register(user);

    if (mounted) {
      HapticFeedback.heavyImpact();
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => const HomeScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('KYC Registration'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Create Your Account',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1565C0)),
              ),
              const SizedBox(height: 6),
              const Text(
                'Fill in your details to get started',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 28),

              // Full Name
              _buildField(
                controller: _nameCon,
                label: 'Full Name',
                hint: 'e.g. Rahul Sharma',
                icon: Icons.person_outline,
                validator: Validators.validateName,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s]'))
                ],
              ),
              const SizedBox(height: 16),

              // Mobile
              _buildField(
                controller: _mobileCon,
                label: 'Mobile Number',
                hint: 'e.g. 9876543210',
                icon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
                validator: Validators.validateMobile,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                prefix: const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: Text('+91',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 16),

              // PAN
              _buildField(
                controller: _panCon,
                label: 'PAN Card Number',
                hint: 'e.g. ABCDE1234F',
                icon: Icons.credit_card_outlined,
                validator: Validators.validatePAN,
                inputFormatters: [
                  UpperCaseTextFormatter(),
                  LengthLimitingTextInputFormatter(10),
                ],
              ),
              const SizedBox(height: 16),

              // DOB
              TextFormField(
                controller: _dobCon,
                readOnly: true,
                onTap: _pickDOB,
                validator: Validators.validateDOB,
                decoration: InputDecoration(
                  labelText: 'Date of Birth',
                  hintText: 'DD/MM/YYYY',
                  prefixIcon: const Icon(Icons.cake_outlined,
                      color: Color(0xFF1565C0)),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                        color: Color(0xFF1565C0), width: 2),
                  ),
                  errorStyle: const TextStyle(color: Colors.red),
                  suffixIcon: const Icon(Icons.calendar_today,
                      color: Color(0xFF1565C0)),
                ),
              ),
              const SizedBox(height: 16),

              // UPI ID
              _buildField(
                controller: _upiCon,
                label: 'UPI ID',
                hint: 'e.g. name@upi',
                icon: Icons.account_balance_wallet_outlined,
                validator: Validators.validateUPI,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 24),

              // Face Verification
              _FaceVerificationCard(
                isVerified: _faceImages.isNotEmpty,
                onTap: _startFaceVerification,
              ),
              const SizedBox(height: 24),

              // Terms
              Row(
                children: [
                  Checkbox(
                    value: _termsAccepted,
                    onChanged: (v) =>
                        setState(() => _termsAccepted = v ?? false),
                    activeColor: const Color(0xFF1565C0),
                  ),
                  Expanded(
                    child: RichText(
                      text: const TextSpan(
                        style:
                            TextStyle(color: Colors.black87, fontSize: 13),
                        children: [
                          TextSpan(text: 'I agree to EasyLoan '),
                          TextSpan(
                            text: 'Terms & Conditions',
                            style: TextStyle(
                              color: Color(0xFF1565C0),
                              fontWeight: FontWeight.bold,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                          TextSpan(text: ' and '),
                          TextSpan(
                            text: 'Privacy Policy',
                            style: TextStyle(
                              color: Color(0xFF1565C0),
                              fontWeight: FontWeight.bold,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Submit Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Text('Create Account',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    Widget? prefix,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: const Color(0xFF1565C0)),
        prefix: prefix,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF1565C0), width: 2),
        ),
        errorStyle: const TextStyle(color: Colors.red),
      ),
    );
  }
}

class _FaceVerificationCard extends StatelessWidget {
  final bool isVerified;
  final VoidCallback onTap;
  const _FaceVerificationCard(
      {required this.isVerified, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: isVerified
              ? const Color(0xFFE8F5E9)
              : const Color(0xFFE3F2FD),
          border: Border.all(
            color: isVerified
                ? const Color(0xFF2E7D32)
                : const Color(0xFF1565C0),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isVerified ? Icons.verified_user : Icons.face,
              color: isVerified
                  ? const Color(0xFF2E7D32)
                  : const Color(0xFF1565C0),
              size: 36,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isVerified
                        ? 'Face Verified ✅'
                        : 'Face Verification Required',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isVerified
                          ? const Color(0xFF2E7D32)
                          : const Color(0xFF1565C0),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isVerified
                        ? 'Identity confirmed with 3 photos'
                        : 'Tap to verify with camera (blink test)',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              isVerified ? Icons.check_circle : Icons.arrow_forward_ios,
              color: isVerified
                  ? const Color(0xFF2E7D32)
                  : const Color(0xFF1565C0),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

// Force uppercase input
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}

// Import HomeScreen at bottom to avoid circular import issues
import 'home_screen.dart';
