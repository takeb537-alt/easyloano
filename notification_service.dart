// ============================================
// EasyLoan - NotificationService
// Firebase Cloud Messaging (FCM)
// Local notifications for foreground
// ============================================

import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Top-level handler for background messages
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Background message handling (no UI access here)
  print('Background message received: ${message.messageId}');
}

class NotificationService {
  static final NotificationService _instance =
      NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  // Notification channels
  static const String _loanChannel = 'loan_alerts';
  static const String _paymentChannel = 'payment_alerts';
  static const String _reminderChannel = 'reminders';

  /// Initialize notification service
  Future<void> initialize() async {
    // Register background message handler
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // Request permissions
    await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    // Initialize local notifications
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // Create notification channels (Android 8+)
    await _createNotificationChannels();

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle notification tap when app in background
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    // Save FCM token to Firestore
    await _saveFCMToken();
  }

  Future<void> _createNotificationChannels() async {
    const loanChannel = AndroidNotificationChannel(
      _loanChannel,
      'Loan Alerts',
      description: 'Notifications for loan approvals and status updates',
      importance: Importance.high,
    );

    const paymentChannel = AndroidNotificationChannel(
      _paymentChannel,
      'Payment Alerts',
      description: 'Notifications for payment confirmations',
      importance: Importance.high,
    );

    const reminderChannel = AndroidNotificationChannel(
      _reminderChannel,
      'Reminders',
      description: 'Due date reminders and overdue alerts',
      importance: Importance.max,
    );

    final plugin = _localNotifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    await plugin?.createNotificationChannel(loanChannel);
    await plugin?.createNotificationChannel(paymentChannel);
    await plugin?.createNotificationChannel(reminderChannel);
  }

  void _handleForegroundMessage(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;

    final channelId = message.data['type'] == 'payment'
        ? _paymentChannel
        : message.data['type'] == 'reminder'
            ? _reminderChannel
            : _loanChannel;

    _showLocalNotification(
      id: message.hashCode,
      title: notification.title ?? 'EasyLoan',
      body: notification.body ?? '',
      channelId: channelId,
      payload: jsonEncode(message.data),
    );
  }

  void _handleNotificationTap(RemoteMessage message) {
    // Navigate based on notification type
    final type = message.data['type'];
    // Navigation handled by app router
    print('Notification tapped: $type');
  }

  void _onNotificationTap(NotificationResponse response) {
    // Handle local notification tap
    if (response.payload != null) {
      final data = jsonDecode(response.payload!);
      print('Local notification tapped: $data');
    }
  }

  Future<void> _showLocalNotification({
    required int id,
    required String title,
    required String body,
    required String channelId,
    String? payload,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelId == _loanChannel
          ? 'Loan Alerts'
          : channelId == _paymentChannel
              ? 'Payment Alerts'
              : 'Reminders',
      channelDescription: 'EasyLoan notification',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      color: const Color(0xFF1565C0),
    );

    final details = NotificationDetails(android: androidDetails);

    await _localNotifications.show(id, title, body, details, payload: payload);
  }

  /// Save/update FCM token to Firestore
  Future<void> _saveFCMToken() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    final token = await _fcm.getToken();
    if (token == null) return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .update({'fcmToken': token});

    // Listen for token refresh
    _fcm.onTokenRefresh.listen((newToken) async {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .update({'fcmToken': newToken});
    });
  }

  // ─── SEND LOCAL NOTIFICATIONS ───────────────

  Future<void> showLoanApprovedNotification(double amount) async {
    await _showLocalNotification(
      id: 1001,
      title: '🎉 Loan Approved!',
      body: '₹${amount.toInt()} has been approved. Money is on its way!',
      channelId: _loanChannel,
    );
  }

  Future<void> showPaymentConfirmedNotification(double amount) async {
    await _showLocalNotification(
      id: 1002,
      title: '✅ Payment Confirmed',
      body: '₹${amount.toInt()} payment received successfully.',
      channelId: _paymentChannel,
    );
  }

  Future<void> showDueReminderNotification(
    double amount,
    int daysLeft,
  ) async {
    await _showLocalNotification(
      id: 1003,
      title: '⏰ Payment Due in $daysLeft Days',
      body: 'Your loan repayment of ₹${amount.toInt()} is due in $daysLeft days.',
      channelId: _reminderChannel,
    );
  }

  Future<void> showOverdueNotification(double penalty) async {
    await _showLocalNotification(
      id: 1004,
      title: '⚠️ Loan Overdue - Penalty Added',
      body: 'A penalty of ₹${penalty.toInt()} has been added to your loan.',
      channelId: _reminderChannel,
    );
  }

  Future<void> showReferralBonusNotification(double bonus) async {
    await _showLocalNotification(
      id: 1005,
      title: '🎁 Referral Bonus Credited!',
      body: '₹${bonus.toInt()} referral bonus added to your wallet.',
      channelId: _loanChannel,
    );
  }

  /// Get FCM token for testing
  Future<String?> getFCMToken() async {
    return await _fcm.getToken();
  }
}