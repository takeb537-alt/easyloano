// ============================================
// EasyLoan - PermissionService
// Handles all runtime permissions
// App STAYS on splash if any permission denied
// ============================================

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionResult {
  final bool allGranted;
  final List<String> deniedPermissions;

  const PermissionResult({
    required this.allGranted,
    required this.deniedPermissions,
  });
}

class PermissionService {
  // Singleton instance
  static final PermissionService _instance = PermissionService._internal();
  factory PermissionService() => _instance;
  PermissionService._internal();

  // Required permissions with their descriptions
  static const Map<Permission, String> _requiredPermissions = {
    Permission.camera: 'Camera – For face verification during KYC',
    Permission.storage: 'Storage – To save your loan agreements as PDF',
    Permission.location: 'Location – For security verification',
    Permission.contacts: 'Contacts – For emergency contact setup',
  };

  /// Request all mandatory permissions.
  /// Returns [PermissionResult] indicating if all were granted.
  Future<PermissionResult> requestAllPermissions() async {
    final List<String> denied = [];

    // Request all permissions simultaneously
    final Map<Permission, PermissionStatus> statuses =
        await _requiredPermissions.keys.toList().request();

    statuses.forEach((permission, status) {
      if (!status.isGranted) {
        denied.add(_requiredPermissions[permission] ?? permission.toString());
      }
    });

    return PermissionResult(
      allGranted: denied.isEmpty,
      deniedPermissions: denied,
    );
  }

  /// Check current status of all required permissions.
  Future<PermissionResult> checkAllPermissions() async {
    final List<String> denied = [];

    for (final entry in _requiredPermissions.entries) {
      final status = await entry.key.status;
      if (!status.isGranted) {
        denied.add(entry.value);
      }
    }

    return PermissionResult(
      allGranted: denied.isEmpty,
      deniedPermissions: denied,
    );
  }

  /// Check if a specific permission is permanently denied.
  Future<bool> isPermanentlyDenied(Permission permission) async {
    return await permission.isPermanentlyDenied;
  }

  /// Open app settings for user to grant permissions manually.
  Future<bool> openSettings() async {
    return await openAppSettings();
  }

  /// Show a dialog explaining why permission is needed and offer to open settings.
  static Future<void> showPermissionDialog(
    BuildContext context, {
    required List<String> deniedPermissions,
    required VoidCallback onOpenSettings,
    required VoidCallback onDismiss,
  }) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1565C0).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.security,
                  color: Color(0xFF1565C0),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Permissions Required',
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'EasyLoan needs these permissions to work properly. Please allow all permissions to continue.',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF6B7280),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              ...deniedPermissions.map((perm) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.cancel,
                          color: Color(0xFFEF4444),
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            perm,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF1A1A2E),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )),
            ],
          ),
          actions: [
            TextButton(
              onPressed: onDismiss,
              child: const Text(
                'Exit App',
                style: TextStyle(color: Color(0xFF6B7280)),
              ),
            ),
            ElevatedButton(
              onPressed: onOpenSettings,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1565C0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
              child: const Text(
                'Open Settings',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}