import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─── Models ───────────────────────────────────────────────────────────────────

class UserModel {
  final String fullName;
  final String mobile;
  final String pan;
  final String dob;
  final String upiId;
  final List<String> faceImages; // stored paths

  UserModel({
    required this.fullName,
    required this.mobile,
    required this.pan,
    required this.dob,
    required this.upiId,
    required this.faceImages,
  });

  Map<String, dynamic> toJson() => {
        'fullName': fullName,
        'mobile': mobile,
        'pan': pan,
        'dob': dob,
        'upiId': upiId,
        'faceImages': faceImages,
      };

  factory UserModel.fromJson(Map<String, dynamic> j) => UserModel(
        fullName: j['fullName'],
        mobile: j['mobile'],
        pan: j['pan'],
        dob: j['dob'],
        upiId: j['upiId'],
        faceImages: List<String>.from(j['faceImages'] ?? []),
      );
}

enum LoanStatus { active, completed, overdue }

class LoanModel {
  final String id;
  final double amount;
  final double fee;
  final double penalty;
  final DateTime appliedDate;
  final DateTime dueDate;
  LoanStatus status;
  double amountPaid;
  String? pdfPath;

  LoanModel({
    required this.id,
    required this.amount,
    required this.fee,
    required this.penalty,
    required this.appliedDate,
    required this.dueDate,
    required this.status,
    this.amountPaid = 0,
    this.pdfPath,
  });

  double get totalDue => amount + fee + penalty - amountPaid;
  double get principalDue => amount + fee + penalty;

  Map<String, dynamic> toJson() => {
        'id': id,
        'amount': amount,
        'fee': fee,
        'penalty': penalty,
        'appliedDate': appliedDate.toIso8601String(),
        'dueDate': dueDate.toIso8601String(),
        'status': status.name,
        'amountPaid': amountPaid,
        'pdfPath': pdfPath,
      };

  factory LoanModel.fromJson(Map<String, dynamic> j) => LoanModel(
        id: j['id'],
        amount: (j['amount'] as num).toDouble(),
        fee: (j['fee'] as num).toDouble(),
        penalty: (j['penalty'] as num).toDouble(),
        appliedDate: DateTime.parse(j['appliedDate']),
        dueDate: DateTime.parse(j['dueDate']),
        status: LoanStatus.values.byName(j['status']),
        amountPaid: (j['amountPaid'] as num).toDouble(),
        pdfPath: j['pdfPath'],
      );
}

// ─── Provider ─────────────────────────────────────────────────────────────────

class LoanProvider extends ChangeNotifier {
  // Keys
  static const _kUser = 'user';
  static const _kLoans = 'loans';
  static const _kOnboarded = 'onboarded';
  static const _kOnTimeCount = 'onTimeCount';

  UserModel? _user;
  List<LoanModel> _loans = [];
  bool _onboarded = false;
  int _onTimePayments = 0;

  UserModel? get user => _user;
  List<LoanModel> get loans => List.unmodifiable(_loans);
  bool get onboarded => _onboarded;
  int get onTimePayments => _onTimePayments;
  bool get isRegistered => _user != null;

  LoanModel? get activeLoan {
    try {
      return _loans.firstWhere(
          (l) => l.status == LoanStatus.active || l.status == LoanStatus.overdue);
    } catch (_) {
      return null;
    }
  }

  // ── Initialise ──
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _onboarded = prefs.getBool(_kOnboarded) ?? false;
    _onTimePayments = prefs.getInt(_kOnTimeCount) ?? 0;

    final userJson = prefs.getString(_kUser);
    if (userJson != null) {
      _user = UserModel.fromJson(jsonDecode(userJson));
    }

    final loansJson = prefs.getString(_kLoans);
    if (loansJson != null) {
      final list = jsonDecode(loansJson) as List;
      _loans = list.map((e) => LoanModel.fromJson(e)).toList();
    }

    // Update overdue status
    _checkOverdue();
    notifyListeners();
  }

  void _checkOverdue() {
    final now = DateTime.now();
    for (final loan in _loans) {
      if (loan.status == LoanStatus.active && now.isAfter(loan.dueDate)) {
        loan.status = LoanStatus.overdue;
      }
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    if (_user != null) {
      await prefs.setString(_kUser, jsonEncode(_user!.toJson()));
    }
    await prefs.setString(
        _kLoans, jsonEncode(_loans.map((l) => l.toJson()).toList()));
    await prefs.setInt(_kOnTimeCount, _onTimePayments);
  }

  // ── Register ──
  Future<void> register(UserModel user) async {
    _user = user;
    await _save();
    notifyListeners();
  }

  // ── Mark onboarded ──
  Future<void> completeOnboarding() async {
    _onboarded = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kOnboarded, true);
    notifyListeners();
  }

  // ── Apply Loan ──
  Future<LoanModel> applyLoan(double amount) async {
    const fee = 100.0;
    final now = DateTime.now();
    final due = now.add(const Duration(days: 15));
    final id =
        'EL${now.millisecondsSinceEpoch.toString().substring(7)}';

    final loan = LoanModel(
      id: id,
      amount: amount,
      fee: fee,
      penalty: 0,
      appliedDate: now,
      dueDate: due,
      status: LoanStatus.active,
    );
    _loans.add(loan);
    await _save();
    notifyListeners();
    return loan;
  }

  // ── Update PDF path ──
  Future<void> updateLoanPdf(String loanId, String path) async {
    final loan = _loans.firstWhere((l) => l.id == loanId);
    loan.pdfPath = path;
    await _save();
    notifyListeners();
  }

  // ── Apply penalty ──
  Future<void> applyPenalty(String loanId) async {
    final loan = _loans.firstWhere((l) => l.id == loanId);
    if (loan.penalty == 0) {
      loan.penalty = PenaltyCalculator.calculate(loan.amount);
      await _save();
      notifyListeners();
    }
  }

  // ── Make payment (full or partial) ──
  Future<bool> makePayment(String loanId, double payAmount) async {
    final loan = _loans.firstWhere((l) => l.id == loanId);

    // Apply penalty if overdue and not yet applied
    if (loan.status == LoanStatus.overdue && loan.penalty == 0) {
      loan.penalty = PenaltyCalculator.calculate(loan.amount);
    }

    loan.amountPaid += payAmount;

    if (loan.amountPaid >= loan.principalDue) {
      loan.status = LoanStatus.completed;
      // Count as on-time only if paid before due date
      if (DateTime.now().isBefore(loan.dueDate) ||
          DateTime.now().isAtSameMomentAs(loan.dueDate)) {
        _onTimePayments++;
      }
    }
    await _save();
    notifyListeners();
    return loan.status == LoanStatus.completed;
  }

  // ── Max unlocked loan amount ──
  double get maxUnlockedAmount {
    if (_onTimePayments >= 6) return 2000;
    if (_onTimePayments >= 3) return 1000;
    return 200;
  }

  // ── Logout / reset ──
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    _user = null;
    _loans = [];
    _onboarded = false;
    _onTimePayments = 0;
    notifyListeners();
  }
}

// ─── Penalty Calculator ───────────────────────────────────────────────────────

class PenaltyCalculator {
  static double calculate(double loanAmount) {
    if (loanAmount <= 100) return 50;
    if (loanAmount <= 500) return 100;
    if (loanAmount <= 1000) return 200;
    if (loanAmount <= 1500) return 250;
    return 300;
  }

  static List<Map<String, String>> get schedule => [
        {'range': '₹100', 'penalty': '₹50'},
        {'range': '₹200 – ₹500', 'penalty': '₹100'},
        {'range': '₹600 – ₹1000', 'penalty': '₹200'},
        {'range': '₹1100 – ₹1500', 'penalty': '₹250'},
        {'range': '₹1600 – ₹2000', 'penalty': '₹300'},
      ];
}
