// ============================================
// EasyLoan - FirestoreService
// All Firestore database operations
// ============================================

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/constants.dart';
import '../utils/penalty_calculator.dart';
import 'encryption_service.dart';

class FirestoreService {
  static final FirestoreService _instance = FirestoreService._internal();
  factory FirestoreService() => _instance;
  FirestoreService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final EncryptionService _encryptionService = EncryptionService();

  String get _userId => FirebaseAuth.instance.currentUser!.uid;

  // ─── USER OPERATIONS ────────────────────────

  /// Create or update user document
  Future<void> createUser({
    required String userId,
    required String phoneNumber,
  }) async {
    final userRef = _db.collection(FirestoreCollections.users).doc(userId);
    final doc = await userRef.get();

    if (!doc.exists) {
      await userRef.set({
        'userId': userId,
        'phone': phoneNumber,
        'kycStep': 1, // Start at face verification after phone auth
        'kycCompleted': false,
        'walletBalance': 0.0,
        'onTimeRepayments': 0,
        'totalLoans': 0,
        'referralCode': _generateReferralCode(userId),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  /// Update user KYC step
  Future<void> updateKYCStep(int step) async {
    await _db.collection(FirestoreCollections.users).doc(_userId).update({
      'kycStep': step,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Save basic details (Step 3)
  Future<void> saveBasicDetails({
    required String name,
    required DateTime dob,
    required String gender,
  }) async {
    await _db.collection(FirestoreCollections.users).doc(_userId).update({
      'name': name,
      'dob': Timestamp.fromDate(dob),
      'gender': gender,
      'kycStep': 3,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Save PAN card - checks uniqueness first
  Future<bool> savePAN(String pan) async {
    final cleanPan = pan.toUpperCase().trim();

    // Check PAN uniqueness
    final existing = await _db
        .collection(FirestoreCollections.users)
        .where('pan', isEqualTo: cleanPan)
        .where('userId', isNotEqualTo: _userId)
        .get();

    if (existing.docs.isNotEmpty) {
      throw Exception('This PAN is already registered with another account.');
    }

    await _db.collection(FirestoreCollections.users).doc(_userId).update({
      'pan': cleanPan,
      'kycStep': 4,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return true;
  }

  /// Save Aadhaar - AES-256 encrypted, uniqueness checked via hash
  Future<bool> saveAadhaar(String aadhaar) async {
    final cleanAadhaar = aadhaar.replaceAll(' ', '');

    // Create a hash for uniqueness check (not storing plain aadhaar)
    final aadhaarHash = _encryptionService.hashString(cleanAadhaar);

    // Check uniqueness via hash
    final existing = await _db
        .collection(FirestoreCollections.users)
        .where('aadhaarHash', isEqualTo: aadhaarHash)
        .where('userId', isNotEqualTo: _userId)
        .get();

    if (existing.docs.isNotEmpty) {
      throw Exception('This Aadhaar is already registered with another account.');
    }

    // Encrypt aadhaar with AES-256
    final encryptedAadhaar = _encryptionService.encrypt(cleanAadhaar);

    await _db.collection(FirestoreCollections.users).doc(_userId).update({
      'aadhaar': encryptedAadhaar,
      'aadhaarHash': aadhaarHash,
      'kycStep': 5,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return true;
  }

  /// Save UPI ID and mark KYC complete
  Future<void> saveUPI(String upiId) async {
    await _db.collection(FirestoreCollections.users).doc(_userId).update({
      'upiId': upiId.trim().toLowerCase(),
      'kycStep': 6,
      'kycCompleted': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Save face verification data
  Future<void> saveFaceData({
    required List<String> photoUrls,
    required String faceHash,
  }) async {
    await _db.collection(FirestoreCollections.users).doc(_userId).update({
      'faceImageUrls': photoUrls,
      'faceHash': faceHash,
      'faceVerified': true,
      'kycStep': 2,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Get user document
  Future<Map<String, dynamic>?> getUser() async {
    final doc = await _db.collection(FirestoreCollections.users).doc(_userId).get();
    return doc.exists ? doc.data() : null;
  }

  /// Stream user document (real-time updates)
  Stream<DocumentSnapshot> userStream() {
    return _db.collection(FirestoreCollections.users).doc(_userId).snapshots();
  }

  // ─── LOAN OPERATIONS ────────────────────────

  /// Apply for a new loan
  Future<String> applyLoan({
    required double amount,
    required bool isRechargeLoan,
    required double returnAmount,
    required int tenure,
  }) async {
    // Check for active loans
    final activeLoans = await _db
        .collection(FirestoreCollections.loans)
        .where('userId', isEqualTo: _userId)
        .where('status', whereIn: ['active', 'overdue'])
        .get();

    if (activeLoans.docs.isNotEmpty) {
      throw Exception('You already have an active loan. Please repay it first.');
    }

    final dueDate = DateTime.now().add(Duration(days: tenure));
    final penalty = PenaltyCalculator.calculatePenalty(amount);

    final loanData = {
      'userId': _userId,
      'amount': amount,
      'returnAmount': returnAmount,
      'dueDate': Timestamp.fromDate(dueDate),
      'status': LoanStatus.pending,
      'penalty': 0.0,
      'maxPenalty': penalty,
      'paidAmount': 0.0,
      'isRechargeLoan': isRechargeLoan,
      'tenure': tenure,
      'penaltyApplied': false,
      'createdAt': FieldValue.serverTimestamp(),
      'disbursedAt': null,
    };

    final docRef = await _db.collection(FirestoreCollections.loans).add(loanData);

    // Update user stats
    await _db.collection(FirestoreCollections.users).doc(_userId).update({
      'totalLoans': FieldValue.increment(1),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return docRef.id;
  }

  /// Activate loan after disbursement
  Future<void> activateLoan(String loanId) async {
    await _db.collection(FirestoreCollections.loans).doc(loanId).update({
      'status': LoanStatus.active,
      'disbursedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Get active loan
  Future<Map<String, dynamic>?> getActiveLoan() async {
    final snapshot = await _db
        .collection(FirestoreCollections.loans)
        .where('userId', isEqualTo: _userId)
        .where('status', whereIn: [LoanStatus.active, LoanStatus.overdue])
        .orderBy('createdAt', descending: true)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;
    return {'id': snapshot.docs.first.id, ...snapshot.docs.first.data()};
  }

  /// Get all loans for user
  Future<List<Map<String, dynamic>>> getAllLoans() async {
    final snapshot = await _db
        .collection(FirestoreCollections.loans)
        .where('userId', isEqualTo: _userId)
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => {'id': doc.id, ...doc.data()})
        .toList();
  }

  /// Stream active loan (real-time)
  Stream<QuerySnapshot> activeLoanStream() {
    return _db
        .collection(FirestoreCollections.loans)
        .where('userId', isEqualTo: _userId)
        .where('status', whereIn: [LoanStatus.active, LoanStatus.overdue])
        .snapshots();
  }

  /// Record a repayment transaction
  Future<void> recordPayment({
    required String loanId,
    required double amount,
    required String razorpayId,
    required String type,
  }) async {
    final batch = _db.batch();

    // Add transaction record
    final txnRef = _db.collection(FirestoreCollections.transactions).doc();
    batch.set(txnRef, {
      'loanId': loanId,
      'userId': _userId,
      'amount': amount,
      'type': type,
      'razorpayId': razorpayId,
      'status': 'success',
      'timestamp': FieldValue.serverTimestamp(),
    });

    // Update loan paid amount
    final loanRef = _db.collection(FirestoreCollections.loans).doc(loanId);
    batch.update(loanRef, {
      'paidAmount': FieldValue.increment(amount),
    });

    await batch.commit();

    // Check if loan is fully paid
    final loan = await loanRef.get();
    final data = loan.data()!;
    final totalDue = (data['returnAmount'] as num).toDouble() +
        (data['penalty'] as num).toDouble();
    final totalPaid = (data['paidAmount'] as num).toDouble();

    if (totalPaid >= totalDue) {
      await loanRef.update({'status': LoanStatus.completed});

      // Increment on-time repayments if paid before due date
      final dueDate = (data['dueDate'] as Timestamp).toDate();
      if (DateTime.now().isBefore(dueDate.add(const Duration(days: 1)))) {
        await _db.collection(FirestoreCollections.users).doc(_userId).update({
          'onTimeRepayments': FieldValue.increment(1),
        });
      }
    }
  }

  /// Get on-time repayment count for loan unlock
  Future<int> getOnTimeRepayments() async {
    final user = await getUser();
    return user?['onTimeRepayments'] ?? 0;
  }

  /// Get all transactions for a loan
  Future<List<Map<String, dynamic>>> getLoanTransactions(String loanId) async {
    final snapshot = await _db
        .collection(FirestoreCollections.transactions)
        .where('loanId', isEqualTo: loanId)
        .orderBy('timestamp', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => {'id': doc.id, ...doc.data()})
        .toList();
  }

  // ─── BLACKLIST CHECK ─────────────────────────

  Future<bool> isDeviceBlacklisted(String deviceId) async {
    final doc = await _db
        .collection(FirestoreCollections.blacklist)
        .doc(deviceId)
        .get();
    return doc.exists;
  }

  Future<void> blacklistDevice({
    required String deviceId,
    required String reason,
    required String phoneNumber,
  }) async {
    await _db.collection(FirestoreCollections.blacklist).doc(deviceId).set({
      'userId': _userId,
      'reason': reason,
      'date': FieldValue.serverTimestamp(),
      'phoneNumber': phoneNumber,
    });
  }

  // ─── MANDATE OPERATIONS ─────────────────────

  Future<void> saveMandate({
    required String loanId,
    required String mandateId,
    required String upiId,
  }) async {
    await _db.collection('mandates').add({
      'loanId': loanId,
      'userId': _userId,
      'mandateId': mandateId,
      'upiId': upiId,
      'status': 'active',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // ─── HELPERS ───────────────────────────────

  String _generateReferralCode(String userId) {
    final suffix = userId.substring(userId.length - 6).toUpperCase();
    return 'EASY$suffix';
  }
}