// ============================================
// EasyLoan - SplashScreen
// Requests ALL permissions on startup
// App stays here if any permission denied
// ============================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/permission_service.dart';
import '../services/auth_service.dart';
import '../utils/constants.dart';
import '../widgets/common_widgets.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  final PermissionService _permissionService = PermissionService();
  final AuthService _authService = AuthService();

  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;

  String _statusText = 'Starting...';
  bool _showPermissionDialog = false;
  List<String> _deniedPermissions = [];

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _initializeApp();
  }

  void _setupAnimations() {
    _animController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
      ),
    );

    _scaleAnim = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.0, 0.6, curve: Curves.elasticOut),
      ),
    );

    _animController.forward();
  }

  Future<void> _initializeApp() async {
    // Wait for animation to start
    await Future.delayed(const Duration(milliseconds: 800));

    if (!mounted) return;
    setState(() => _statusText = 'Checking permissions...');

    // Request all permissions
    final result = await _permissionService.requestAllPermissions();

    if (!result.allGranted) {
      if (!mounted) return;
      setState(() {
        _deniedPermissions = result.deniedPermissions;
        _showPermissionDialog = true;
        _statusText = 'Permissions required';
      });

      // Show permission dialog - app stays here
      await _showPermDialog();
      return;
    }

    // All permissions granted → proceed
    if (!mounted) return;
    setState(() => _statusText = 'Initializing...');
    await Future.delayed(const Duration(milliseconds: 500));

    _navigateNext();
  }

  Future<void> _showPermDialog() async {
    await PermissionService.showPermissionDialog(
      context,
      deniedPermissions: _deniedPermissions,
      onOpenSettings: () async {
        Navigator.pop(context); // Close dialog
        await _permissionService.openSettings();
        // Re-check after returning from settings
        await Future.delayed(const Duration(milliseconds: 500));
        _initializeApp(); // Re-check
      },
      onDismiss: () {
        // Exit app if user refuses
        SystemNavigator.pop();
      },
    );
  }

  void _navigateNext() {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      // Not logged in → Onboarding
      Navigator.pushReplacementNamed(context, AppRoutes.onboarding);
    } else {
      // Check KYC completion
      _checkKYCAndNavigate(user.uid);
    }
  }

  Future<void> _checkKYCAndNavigate(String userId) async {
    try {
      final isKYCDone = await _authService.isKYCCompleted();

      if (!mounted) return;

      if (isKYCDone) {
        Navigator.pushReplacementNamed(context, AppRoutes.dashboard);
      } else {
        // Get KYC step and navigate accordingly
        // For simplicity, send to phone auth which will check step
        Navigator.pushReplacementNamed(context, AppRoutes.phoneAuth);
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, AppRoutes.onboarding);
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Main splash content
            Expanded(
              child: AnimatedBuilder(
                animation: _animController,
                builder: (context, child) {
                  return FadeTransition(
                    opacity: _fadeAnim,
                    child: ScaleTransition(
                      scale: _scaleAnim,
                      child: child,
                    ),
                  );
                },
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // App Logo
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          gradient: AppColors.cardGradient,
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.3),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Text(
                            '₹',
                            style: TextStyle(
                              fontSize: 52,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // App Name
                      const Text(
                        'EasyLoan',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 36,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                          letterSpacing: -1,
                        ),
                      ),

                      const SizedBox(height: 8),

                      // Tagline
                      Text(
                        'Fast Loans, Easy Life',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                          color: AppColors.textSecondary,
                        ),
                      ),

                      const SizedBox(height: 8),

                      // Language chips
                      Wrap(
                        spacing: 6,
                        children: [
                          'हिंदी', 'English', 'বাংলা', 'தமிழ்', 'తెలుగు'
                        ]
                            .map((lang) => Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(100),
                                  ),
                                  child: Text(
                                    lang,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ))
                            .toList(),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Bottom status + loading
            Padding(
              padding: const EdgeInsets.all(AppDimensions.paddingL),
              child: Column(
                children: [
                  if (!_showPermissionDialog)
                    const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: AppColors.primary,
                      ),
                    ),
                  const SizedBox(height: 12),
                  Text(
                    _statusText,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Secured by Firebase & RBI Guidelines',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textHint,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}