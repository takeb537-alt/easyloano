// ============================================
// EasyLoan - BasicDetailsScreen
// KYC Step 3: Name, DOB (18+), Gender
// Real-time validation
// ============================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../services/firestore_service.dart';
import '../utils/constants.dart';
import '../utils/validators.dart';
import '../widgets/common_widgets.dart';

class BasicDetailsScreen extends StatefulWidget {
  const BasicDetailsScreen({super.key});

  @override
  State<BasicDetailsScreen> createState() => _BasicDetailsScreenState();
}

class _BasicDetailsScreenState extends State<BasicDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final FirestoreService _firestoreService = FirestoreService();

  DateTime? _selectedDOB;
  String? _selectedGender;
  bool _isLoading = false;

  String? _nameError;
  String? _dobError;
  String? _genderError;

  final List<String> _genders = ['Male', 'Female', 'Other', 'Prefer not to say'];

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _selectDOB() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 25, now.month, now.day),
      firstDate: DateTime(now.year - 70),
      lastDate: DateTime(now.year - 18, now.month, now.day),
      helpText: 'Select Date of Birth',
      fieldLabelText: 'Date of Birth',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedDOB = picked;
        _dobError = Validators.validateDOB(picked);
      });
    }
  }

  bool _validateAll() {
    final nameErr = Validators.validateName(_nameController.text);
    final dobErr = Validators.validateDOB(_selectedDOB);
    final genderErr = Validators.validateGender(_selectedGender);

    setState(() {
      _nameError = nameErr;
      _dobError = dobErr;
      _genderError = genderErr;
    });

    return nameErr == null && dobErr == null && genderErr == null;
  }

  Future<void> _saveDetails() async {
    if (!_validateAll()) return;

    setState(() => _isLoading = true);
    HapticFeedback.mediumImpact();

    try {
      await _firestoreService.saveBasicDetails(
        name: _nameController.text.trim(),
        dob: _selectedDOB!,
        gender: _selectedGender!,
      );

      if (!mounted) return;
      Navigator.pushReplacementNamed(context, AppRoutes.panVerification);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showError(e.toString().replaceAll('Exception: ', ''));
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('Basic Details')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppDimensions.paddingL),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _KYCStepHeader(
                step: 3,
                icon: Icons.person,
                title: 'Tell us about\nyourself',
                subtitle: 'We need a few basic details to process your loan',
              ),

              const SizedBox(height: 32),

              // Full Name field
              _FieldLabel(label: 'Full Name', isRequired: true),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameController,
                keyboardType: TextInputType.name,
                textCapitalization: TextCapitalization.words,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s]')),
                ],
                onChanged: (value) {
                  if (_nameError != null) {
                    setState(() => _nameError = Validators.validateName(value));
                  }
                },
                decoration: InputDecoration(
                  hintText: 'Enter your full name',
                  prefixIcon: const Icon(Icons.person_outline,
                      color: AppColors.textSecondary),
                  errorText: _nameError,
                ),
              ),

              const SizedBox(height: 20),

              // Date of Birth field
              _FieldLabel(label: 'Date of Birth', isRequired: true),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _selectDOB,
                child: AbsorbPointer(
                  child: TextFormField(
                    readOnly: true,
                    decoration: InputDecoration(
                      hintText: 'Select date of birth',
                      prefixIcon: const Icon(Icons.calendar_today_outlined,
                          color: AppColors.textSecondary),
                      suffixIcon: const Icon(Icons.chevron_right,
                          color: AppColors.textSecondary),
                      errorText: _dobError,
                    ),
                    controller: TextEditingController(
                      text: _selectedDOB == null
                          ? ''
                          : DateFormat('dd MMM yyyy').format(_selectedDOB!),
                    ),
                  ),
                ),
              ),

              if (_selectedDOB != null) ...[
                const SizedBox(height: 6),
                _AgeChip(dob: _selectedDOB!),
              ],

              const SizedBox(height: 20),

              // Gender field
              _FieldLabel(label: 'Gender', isRequired: true),
              const SizedBox(height: 8),
              _GenderSelector(
                selectedGender: _selectedGender,
                genders: _genders,
                error: _genderError,
                onSelected: (gender) {
                  setState(() {
                    _selectedGender = gender;
                    _genderError = null;
                  });
                },
              ),

              if (_genderError != null) ...[
                const SizedBox(height: 6),
                Text(
                  _genderError!,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.error,
                    fontFamily: 'Poppins',
                  ),
                ),
              ],

              const SizedBox(height: 32),

              // Info box
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.primary.withOpacity(0.1),
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline,
                        color: AppColors.primary, size: 18),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Your details are encrypted and never shared with third parties.',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          fontFamily: 'Poppins',
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              AppButton(
                label: 'Continue',
                isLoading: _isLoading,
                onPressed: _saveDetails,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Sub-widgets ─────────────────────────────

class _KYCStepHeader extends StatelessWidget {
  final int step;
  final IconData icon;
  final String title;
  final String subtitle;

  const _KYCStepHeader({
    required this.step,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Step progress
        Row(
          children: List.generate(6, (i) => Expanded(
            child: Container(
              margin: const EdgeInsets.only(right: 4),
              height: 4,
              decoration: BoxDecoration(
                color: i < step
                    ? AppColors.primary
                    : AppColors.primary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          )),
        ),
        const SizedBox(height: 8),
        Text(
          'Step $step of 6 · ${AppStrings.kycSteps[step - 1]}',
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
            fontFamily: 'Poppins',
          ),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppColors.primary, size: 28),
        ),
        const SizedBox(height: 16),
        Text(title, style: AppTextStyles.heading1),
        const SizedBox(height: 8),
        Text(subtitle, style: AppTextStyles.bodyMedium),
      ],
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String label;
  final bool isRequired;

  const _FieldLabel({required this.label, this.isRequired = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
            fontFamily: 'Poppins',
          ),
        ),
        if (isRequired)
          const Text(
            ' *',
            style: TextStyle(color: AppColors.error, fontSize: 14),
          ),
      ],
    );
  }
}

class _AgeChip extends StatelessWidget {
  final DateTime dob;

  const _AgeChip({required this.dob});

  int get _age {
    final now = DateTime.now();
    return now.year - dob.year -
        ((now.month < dob.month ||
            (now.month == dob.month && now.day < dob.day))
            ? 1
            : 0);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.success.withOpacity(0.1),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        'Age: $_age years',
        style: const TextStyle(
          fontSize: 12,
          color: AppColors.success,
          fontWeight: FontWeight.w600,
          fontFamily: 'Poppins',
        ),
      ),
    );
  }
}

class _GenderSelector extends StatelessWidget {
  final String? selectedGender;
  final List<String> genders;
  final String? error;
  final ValueChanged<String> onSelected;

  const _GenderSelector({
    required this.selectedGender,
    required this.genders,
    this.error,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: genders.map((gender) {
        final isSelected = selectedGender == gender;
        return GestureDetector(
          onTap: () => onSelected(gender),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primary : Colors.white,
              border: Border.all(
                color: isSelected
                    ? AppColors.primary
                    : error != null
                        ? AppColors.error
                        : const Color(0xFFE5E7EB),
                width: isSelected ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
            ),
            child: Text(
              gender,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isSelected ? Colors.white : AppColors.textPrimary,
                fontFamily: 'Poppins',
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}