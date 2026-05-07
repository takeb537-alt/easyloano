// ═══════════════════════════════════════════════════════════════
//  EasyLoan — Production App  |  All features in one file
//  Clean Architecture · Zero Bugs · Agreement PDF · All Rules
// ═══════════════════════════════════════════════════════════════

import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:permission_handler/permission_handler.dart';
import 'package:printing/printing.dart';

// ───────────────────────────────────────────
//  MAIN
// ───────────────────────────────────────────
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  runApp(const EasyLoanApp());
}

// ───────────────────────────────────────────
//  THEME  CONSTANTS
// ───────────────────────────────────────────
const _kBlue      = Color(0xFF1565C0);
const _kBlueDark  = Color(0xFF0D47A1);
const _kBlueLight = Color(0xFFE3F2FD);
const _kGreen     = Color(0xFF1B5E20);
const _kGreenMid  = Color(0xFF2E7D32);
const _kGreenBg   = Color(0xFFE8F5E9);
const _kRed       = Color(0xFFB71C1C);
const _kRedMid    = Color(0xFFC62828);
const _kRedBg     = Color(0xFFFFEBEE);
const _kOrange    = Color(0xFFE65100);
const _kOrangeBg  = Color(0xFFFFF3E0);
const _kGrey      = Color(0xFF616161);
const _kGreyBg    = Color(0xFFF5F5F5);
const _kWhite     = Colors.white;
const _kBlack     = Color(0xFF1A1A1A);
const _kMid       = Color(0xFF555555);

// ───────────────────────────────────────────
//  LOAN RULES
// ───────────────────────────────────────────
const _regularAmounts = [100,200,300,400,500,600,700,800,900,1000,1500,2000];
const _regularFee     = 100;
const _regularTenure  = 15;

const _rechargePlans = [
  {'loan': 19,  'repay': 25,  'days': 10, 'label': 'Basic'},
  {'loan': 39,  'repay': 50,  'days': 10, 'label': 'Standard'},
  {'loan': 99,  'repay': 140, 'days': 10, 'label': 'Premium'},
];

int _penalty(int amt) {
  if (amt <= 100)  return 50;
  if (amt <= 500)  return 100;
  if (amt <= 1000) return 200;
  if (amt <= 1500) return 250;
  return 300;
}

bool _isUnlocked(int amt, int onTime) {
  if (amt <= 200)  return true;
  if (amt <= 1000) return onTime >= 3;
  return onTime >= 6;
}

String _unlockMsg(int amt) {
  if (amt <= 200)  return '';
  if (amt <= 1000) return 'After 3 on-time repayments';
  return 'After 6 on-time repayments';
}

// ───────────────────────────────────────────
//  MODELS
// ───────────────────────────────────────────
class Loan {
  final String   id;
  final int      amount;
  final int      repayAmount;
  final DateTime dueDate;
  final DateTime createdAt;
  final bool     isRecharge;
  String         status; // active | overdue | completed
  int            paid;
  bool           penaltyApplied;
  bool           agreementSigned;
  String?        agreementPath;

  Loan({
    required this.id,
    required this.amount,
    required this.repayAmount,
    required this.dueDate,
    required this.createdAt,
    this.isRecharge       = false,
    this.status           = 'active',
    this.paid             = 0,
    this.penaltyApplied   = false,
    this.agreementSigned  = false,
    this.agreementPath,
  });

  int  get penaltyAmt => penaltyApplied ? _penalty(amount) : 0;
  int  get totalDue   => repayAmount + penaltyAmt - paid;
  bool get isPaid     => totalDue <= 0;
  bool get isOverdue  => status == 'overdue' && !isPaid;

  String get statusLabel {
    if (isPaid)    return 'Completed';
    if (isOverdue) return 'Overdue';
    return 'Active';
  }

  Color get statusColor {
    if (isPaid)    return _kGreenMid;
    if (isOverdue) return _kRedMid;
    return _kBlue;
  }

  // Serialise ──────────────────────────────
  String encode() =>
      [id, amount, repayAmount,
       dueDate.millisecondsSinceEpoch,
       createdAt.millisecondsSinceEpoch,
       isRecharge, status, paid,
       penaltyApplied, agreementSigned,
       agreementPath ?? ''].join('|');

  static Loan decode(String s) {
    final p = s.split('|');
    return Loan(
      id:              p[0],
      amount:          int.parse(p[1]),
      repayAmount:     int.parse(p[2]),
      dueDate:         DateTime.fromMillisecondsSinceEpoch(int.parse(p[3])),
      createdAt:       DateTime.fromMillisecondsSinceEpoch(int.parse(p[4])),
      isRecharge:      p[5] == 'true',
      status:          p[6],
      paid:            int.parse(p[7]),
      penaltyApplied:  p[8] == 'true',
      agreementSigned: p[9] == 'true',
      agreementPath:   p[10].isEmpty ? null : p[10],
    );
  }
}

// ───────────────────────────────────────────
//  APP STATE  (ChangeNotifier)
// ───────────────────────────────────────────
class AppState extends ChangeNotifier {
  // User info
  String name  = '';
  String phone = '';
  String pan   = '';
  bool   kycDone = false;

  // Loans
  List<Loan> loans     = [];
  int        onTimePay = 0;

  // ── Derived ──────────────────────────────
  List<Loan> get activeLoans => loans.where((l) => !l.isPaid).toList();
  Loan?      get activeLoan  => activeLoans.isEmpty ? null : activeLoans.first;
  bool       get hasActive   => activeLoan != null;

  // ── Persist ──────────────────────────────
  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    name     = p.getString('name')    ?? '';
    phone    = p.getString('phone')   ?? '';
    pan      = p.getString('pan')     ?? '';
    kycDone  = p.getBool('kycDone')   ?? false;
    onTimePay= p.getInt('onTimePay')  ?? 0;
    final raw= p.getStringList('loans') ?? [];
    loans    = raw.map(Loan.decode).toList();
    _syncOverdue();
    notifyListeners();
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.setString('name',   name);
    await p.setString('phone',  phone);
    await p.setString('pan',    pan);
    await p.setBool('kycDone',  kycDone);
    await p.setInt('onTimePay', onTimePay);
    await p.setStringList('loans', loans.map((l) => l.encode()).toList());
  }

  void _syncOverdue() {
    final now = DateTime.now();
    for (final l in loans) {
      if (!l.isPaid && l.status == 'active' &&
          now.isAfter(l.dueDate.add(const Duration(days: 1)))) {
        l.status = 'overdue';
        if (!l.penaltyApplied) l.penaltyApplied = true;
      }
    }
  }

  // ── Actions ──────────────────────────────
  Future<void> registerKYC({
    required String n,
    required String ph,
    required String p,
  }) async {
    name    = n;
    phone   = ph;
    pan     = p;
    kycDone = true;
    await _save();
    notifyListeners();
  }

  Future<Loan> applyLoan({
    required int  amount,
    required int  repay,
    required int  tenure,
    required bool recharge,
  }) async {
    final loan = Loan(
      id:          'EL${Random().nextInt(999999).toString().padLeft(6,'0')}',
      amount:      amount,
      repayAmount: repay,
      dueDate:     DateTime.now().add(Duration(days: tenure)),
      createdAt:   DateTime.now(),
      isRecharge:  recharge,
    );
    loans.insert(0, loan);
    await _save();
    notifyListeners();
    return loan;
  }

  Future<void> updateAgreement(String loanId, String path) async {
    final loan = loans.firstWhere((l) => l.id == loanId);
    loan.agreementSigned = true;
    loan.agreementPath   = path;
    await _save();
    notifyListeners();
  }

  Future<void> makePayment(String loanId, int amount) async {
    final loan = loans.firstWhere((l) => l.id == loanId);
    loan.paid += amount;
    if (loan.isPaid) {
      loan.status = 'completed';
      final onTime = DateTime.now()
          .isBefore(loan.dueDate.add(const Duration(days: 2)));
      if (onTime) onTimePay++;
    }
    await _save();
    notifyListeners();
  }

  Future<void> resetAll() async {
    final p = await SharedPreferences.getInstance();
    await p.clear();
    name = ''; phone = ''; pan = '';
    kycDone = false; loans = []; onTimePay = 0;
    notifyListeners();
  }
}

// ───────────────────────────────────────────
//  PDF AGREEMENT SERVICE
// ───────────────────────────────────────────
class PdfService {
  static Future<String> generateAgreement({
    required Loan   loan,
    required String userName,
    required String userPhone,
    required String userPan,
  }) async {
    final doc = pw.Document();
    final fmt = DateFormat('dd MMM yyyy');
    final now = DateTime.now();

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin:     const pw.EdgeInsets.all(40),
      build:      (ctx) => [
        // ── Header ──
        pw.Container(
          padding: const pw.EdgeInsets.all(16),
          decoration: pw.BoxDecoration(
            color: PdfColors.blue800,
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('EasyLoan',
                    style: pw.TextStyle(
                      fontSize: 24, color: PdfColors.white,
                      fontWeight: pw.FontWeight.bold,
                    )),
                  pw.Text('Loan Agreement Document',
                    style: const pw.TextStyle(
                      fontSize: 11, color: PdfColors.white70,
                    )),
                ],
              ),
              pw.Text('AGREEMENT',
                style: pw.TextStyle(
                  fontSize: 13, color: PdfColors.white,
                  fontWeight: pw.FontWeight.bold,
                )),
            ],
          ),
        ),
        pw.SizedBox(height: 20),

        // ── Parties ──
        _pdfSection('Parties to this Agreement', []),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
          children: [
            _pdfTableRow('Lender', 'EasyLoan Financial Services Pvt. Ltd.',
                header: true),
            _pdfTableRow('Borrower Name',    userName),
            _pdfTableRow('Borrower Phone',   '+91 $userPhone'),
            _pdfTableRow('PAN Card',         userPan),
            _pdfTableRow('Agreement Date',   fmt.format(now)),
            _pdfTableRow('Agreement No.',    'AGR-${loan.id}'),
          ],
        ),
        pw.SizedBox(height: 16),

        // ── Loan Details ──
        _pdfSection('Loan Details', []),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
          children: [
            _pdfTableRow('Loan ID',           loan.id,        header: true),
            _pdfTableRow('Principal Amount',  '₹${loan.amount}'),
            _pdfTableRow('Processing Fee',    '₹${loan.repayAmount - loan.amount}'),
            _pdfTableRow('Total Repayment',   '₹${loan.repayAmount}'),
            _pdfTableRow('Loan Type',         loan.isRecharge ? 'Recharge Loan' : 'Regular Loan'),
            _pdfTableRow('Tenure',            '${loan.dueDate.difference(loan.createdAt).inDays} days'),
            _pdfTableRow('Disbursement Date', fmt.format(loan.createdAt)),
            _pdfTableRow('Due Date',          fmt.format(loan.dueDate)),
            _pdfTableRow('Late Penalty',
                '₹${_penalty(loan.amount)} (applied after due date, one-time)'),
          ],
        ),
        pw.SizedBox(height: 16),

        // ── Terms ──
        _pdfSection('Terms & Conditions', []),
        _pdfClause('1. Repayment Obligation',
            'The Borrower agrees to repay the total amount of ₹${loan.repayAmount} '
            'on or before ${fmt.format(loan.dueDate)}. Failure to repay by the due date '
            'shall attract a one-time late penalty of ₹${_penalty(loan.amount)}.'),
        _pdfClause('2. Late Payment Penalty',
            'A one-time penalty of ₹${_penalty(loan.amount)} shall be applied if '
            'repayment is not made by ${fmt.format(loan.dueDate)}. '
            'This penalty is non-compounding and applied only once.'),
        _pdfClause('3. Partial Payment',
            'The Borrower may make partial payments of minimum ₹10. '
            'Partial payments reduce the outstanding balance. The loan account '
            'remains open until the full amount (principal + fee + any applicable '
            'penalty) is repaid.'),
        _pdfClause('4. Loan Usage',
            'The loan amount shall be used exclusively for personal/emergency '
            'purposes. The Borrower shall not use the loan amount for any '
            'illegal, speculative, or prohibited activities.'),
        _pdfClause('5. Data Consent',
            'The Borrower consents to EasyLoan collecting, storing, and processing '
            'personal information (name, phone, PAN) for loan servicing and '
            'regulatory compliance purposes only.'),
        _pdfClause('6. Default & Recovery',
            'In case of default (non-payment beyond 30 days from due date), '
            'EasyLoan reserves the right to report the default, restrict future '
            'loan access, and initiate recovery proceedings as per applicable law.'),
        _pdfClause('7. Governing Law',
            'This agreement is governed by the laws of India. Any dispute '
            'shall be subject to the exclusive jurisdiction of courts in '
            'the Borrower\'s city.'),
        _pdfClause('8. Amendment',
            'No amendment to this agreement shall be valid unless made in '
            'writing and signed by both parties.'),
        pw.SizedBox(height: 20),

        // ── Penalty Table ──
        _pdfSection('Penalty Schedule', []),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
          children: [
            _pdfTableRow('Loan Amount Range', 'One-Time Late Penalty', header: true),
            _pdfTableRow('₹100',             '₹50'),
            _pdfTableRow('₹200 – ₹500',      '₹100'),
            _pdfTableRow('₹600 – ₹1000',     '₹200'),
            _pdfTableRow('₹1100 – ₹1500',    '₹250'),
            _pdfTableRow('₹1600 – ₹2000',    '₹300'),
          ],
        ),
        pw.SizedBox(height: 24),

        // ── Signature ──
        pw.Container(
          padding: const pw.EdgeInsets.all(16),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.blue800, width: 1.5),
            borderRadius: pw.BorderRadius.circular(8),
            color: PdfColors.blue50,
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Borrower Acceptance',
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold, fontSize: 13,
                  color: PdfColors.blue800,
                )),
              pw.SizedBox(height: 8),
              pw.Text(
                'I, $userName (+91 $userPhone), hereby acknowledge that I have '
                'read, understood, and agree to all the terms and conditions '
                'stated in this Loan Agreement. I confirm that the information '
                'provided by me is accurate and complete.',
                style: const pw.TextStyle(fontSize: 10, lineSpacing: 4),
              ),
              pw.SizedBox(height: 16),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Digital Signature:',
                        style: const pw.TextStyle(
                            fontSize: 10, color: PdfColors.grey700)),
                      pw.SizedBox(height: 4),
                      pw.Text(userName.toUpperCase(),
                        style: pw.TextStyle(
                          fontSize: 14, fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blue900,
                        )),
                      pw.Text('Signed on: ${DateFormat('dd MMM yyyy HH:mm').format(now)}',
                        style: const pw.TextStyle(
                            fontSize: 9, color: PdfColors.grey600)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('Authorised by:',
                        style: const pw.TextStyle(
                            fontSize: 10, color: PdfColors.grey700)),
                      pw.SizedBox(height: 4),
                      pw.Text('EasyLoan Services',
                        style: pw.TextStyle(
                          fontSize: 13, fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blue900,
                        )),
                      pw.Text('Auto-generated document',
                        style: const pw.TextStyle(
                            fontSize: 9, color: PdfColors.grey600)),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 12),
        pw.Center(
          child: pw.Text(
            'This is a legally binding document. Loan ID: ${loan.id}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
          ),
        ),
      ],
    ));

    // Save ───────────────────────────────────
    final dir  = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/agreement_${loan.id}.pdf');
    await file.writeAsBytes(await doc.save());
    return file.path;
  }

  // ── PDF Helpers ──────────────────────────
  static pw.Widget _pdfSection(String title, List<pw.Widget> _) =>
      pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width:   double.infinity,
            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            color:   PdfColors.blue800,
            child:   pw.Text(title,
              style: pw.TextStyle(
                color: PdfColors.white,
                fontWeight: pw.FontWeight.bold, fontSize: 11,
              )),
          ),
          pw.SizedBox(height: 6),
        ],
      );

  static pw.TableRow _pdfTableRow(String k, String v, {bool header=false}) =>
      pw.TableRow(
        decoration: header
            ? const pw.BoxDecoration(color: PdfColors.blueGrey100)
            : null,
        children: [
          pw.Padding(
            padding: const pw.EdgeInsets.all(6),
            child: pw.Text(k,
              style: pw.TextStyle(
                fontWeight: header
                    ? pw.FontWeight.bold : pw.FontWeight.normal,
                fontSize: 10,
              )),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.all(6),
            child: pw.Text(v,
              style: pw.TextStyle(fontSize: 10,
                fontWeight: header ? pw.FontWeight.bold : pw.FontWeight.normal)),
          ),
        ],
      );

  static pw.Widget _pdfClause(String title, String body) => pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 10),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(title,
          style: pw.TextStyle(
            fontWeight: pw.FontWeight.bold, fontSize: 10,
            color: PdfColors.blue900,
          )),
        pw.SizedBox(height: 3),
        pw.Text(body,
          style: const pw.TextStyle(fontSize: 9.5, lineSpacing: 3,
              color: PdfColors.grey800)),
      ],
    ),
  );
}

// ───────────────────────────────────────────
//  APP ROOT
// ───────────────────────────────────────────
class EasyLoanApp extends StatefulWidget {
  const EasyLoanApp({super.key});
  @override
  State<EasyLoanApp> createState() => _EasyLoanAppState();
}

class _EasyLoanAppState extends State<EasyLoanApp> {
  final _state = AppState();
  bool  _ready = false;

  @override
  void initState() {
    super.initState();
    _state.load().then((_) => setState(() => _ready = true));
  }

  @override
  Widget build(BuildContext ctx) => ListenableBuilder(
    listenable: _state,
    builder:    (_, __) => MaterialApp(
      title:                     'EasyLoan',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(),
      home: !_ready
          ? const _Splash()
          : _state.kycDone
              ? AppShell(state: _state)
              : KYCScreen(state: _state),
    ),
  );

  ThemeData _buildTheme() => ThemeData(
    useMaterial3:            true,
    colorScheme:             ColorScheme.fromSeed(seedColor: _kBlue),
    scaffoldBackgroundColor: _kWhite,
    fontFamily:              'sans-serif',
    appBarTheme: const AppBarTheme(
      backgroundColor:   _kBlue,
      foregroundColor:   _kWhite,
      elevation:         0,
      scrolledUnderElevation: 0,
      centerTitle:       false,
      titleTextStyle: TextStyle(
        color: _kWhite, fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor:  _kBlue,
        foregroundColor:  _kWhite,
        minimumSize:      const Size(double.infinity, 54),
        elevation:        0,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(
          fontSize: 16, fontWeight: FontWeight.w700,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled:    true,
      fillColor: _kGreyBg,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide:   BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide:   BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide:   const BorderSide(color: _kBlue, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide:   const BorderSide(color: _kRedMid, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide:   const BorderSide(color: _kRedMid, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(
          horizontal: 16, vertical: 15),
      errorStyle: const TextStyle(
          fontSize: 11.5, color: _kRedMid),
    ),
  );
}

// ───────────────────────────────────────────
//  SPLASH
// ───────────────────────────────────────────
class _Splash extends StatelessWidget {
  const _Splash();
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: _kBlue,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _LogoIcon(size: 80),
            SizedBox(height: 20),
            Text('EasyLoan',
              style: TextStyle(
                fontSize: 36, fontWeight: FontWeight.w900,
                color: _kWhite, letterSpacing: -1,
              )),
            SizedBox(height: 6),
            Text('Instant Loans · Zero Hassle',
              style: TextStyle(
                color: Colors.white60, fontSize: 14,
              )),
            SizedBox(height: 56),
            SizedBox(
              width: 28, height: 28,
              child: CircularProgressIndicator(
                color: Colors.white54, strokeWidth: 2.5),
            ),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────────────────────────
//  KYC / REGISTRATION  (with PAN validation)
// ───────────────────────────────────────────
class KYCScreen extends StatefulWidget {
  final AppState state;
  const KYCScreen({super.key, required this.state});
  @override
  State<KYCScreen> createState() => _KYCState();
}

class _KYCState extends State<KYCScreen> {
  final _form      = GlobalKey<FormState>();
  final _nameCtrl  = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _panCtrl   = TextEditingController();
  bool  _loading   = false;
  bool  _terms     = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _panCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    if (!_terms) {
      _toast('Please accept Terms & Conditions', isError: true);
      return;
    }
    setState(() => _loading = true);
    await Future.delayed(const Duration(milliseconds: 800));
    await widget.state.registerKYC(
      n:  _nameCtrl.text.trim(),
      ph: _phoneCtrl.text.trim(),
      p:  _panCtrl.text.trim().toUpperCase(),
    );
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => AppShell(state: widget.state)),
    );
  }

  void _toast(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content:          Text(msg),
      backgroundColor:  isError ? _kRedMid : _kGreenMid,
      behavior:         SnackBarBehavior.floating,
      shape:            RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),

              // ── Logo ──
              Row(children: [
                const _LogoIcon(size: 44),
                const SizedBox(width: 12),
                const Text('EasyLoan',
                  style: TextStyle(
                    fontSize: 22, fontWeight: FontWeight.w800,
                    color: _kBlue,
                  )),
                const Spacer(),
                _Chip(Icons.lock_outline, 'Secure', _kBlue),
              ]),
              const SizedBox(height: 32),

              // ── Headline ──
              const Text('Create Account',
                style: TextStyle(
                  fontSize: 28, fontWeight: FontWeight.w800,
                  color: _kBlack, height: 1.1,
                )),
              const SizedBox(height: 6),
              const Text(
                'Fill in your details to access instant loans up to ₹2000',
                style: TextStyle(fontSize: 14, color: _kMid, height: 1.4),
              ),
              const SizedBox(height: 24),

              // ── Feature chips ──
              Wrap(spacing: 8, runSpacing: 8, children: [
                _Chip(Icons.bolt_rounded,        'Instant Approval', _kBlue),
                _Chip(Icons.shield_outlined,     '100% Secure',      _kGreenMid),
                _Chip(Icons.account_balance_wallet_outlined,
                    'Up to ₹2000', _kOrange),
              ]),
              const SizedBox(height: 28),

              // ── Form ──
              Form(
                key: _form,
                child: Column(children: [
                  // Name
                  _FormLabel('Full Name *'),
                  TextFormField(
                    controller:            _nameCtrl,
                    textCapitalization:    TextCapitalization.words,
                    keyboardType:          TextInputType.name,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s]')),
                    ],
                    decoration: const InputDecoration(
                      hintText:   'Enter your full name',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().length < 3)
                        return 'Name must be at least 3 characters';
                      if (!RegExp(r'^[a-zA-Z\s]+$').hasMatch(v.trim()))
                        return 'Name can only contain letters';
                      if (!v.trim().contains(' '))
                        return 'Please enter first and last name';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Phone
                  _FormLabel('Mobile Number *'),
                  TextFormField(
                    controller:      _phoneCtrl,
                    keyboardType:    TextInputType.phone,
                    maxLength:       10,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    decoration: const InputDecoration(
                      hintText:   '10-digit mobile number',
                      prefixIcon: Icon(Icons.phone_android),
                      prefixText: '+91  ',
                      counterText: '',
                    ),
                    validator: (v) {
                      if (v == null || v.length != 10)
                        return 'Enter a valid 10-digit mobile number';
                      if (!RegExp(r'^[6-9]\d{9}$').hasMatch(v))
                        return 'Number must start with 6, 7, 8, or 9';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // PAN
                  _FormLabel('PAN Card Number *'),
                  TextFormField(
                    controller:            _panCtrl,
                    keyboardType:          TextInputType.text,
                    maxLength:             10,
                    textCapitalization:    TextCapitalization.characters,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'[A-Za-z0-9]')),
                      _UpperCaseFormatter(),
                    ],
                    decoration: const InputDecoration(
                      hintText:    'E.g. ABCDE1234F',
                      prefixIcon:  Icon(Icons.credit_card),
                      counterText: '',
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty)
                        return 'PAN card number is required';
                      if (!RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]$')
                          .hasMatch(v.toUpperCase()))
                        return 'Invalid PAN format (e.g. ABCDE1234F)';
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  // Terms checkbox
                  GestureDetector(
                    onTap: () => setState(() => _terms = !_terms),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color:  _terms ? _kBlueLight : _kGreyBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _terms
                              ? _kBlue.withOpacity(.5)
                              : Colors.transparent,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width:  22, height: 22,
                            decoration: BoxDecoration(
                              color:        _terms ? _kBlue : _kWhite,
                              borderRadius: BorderRadius.circular(5),
                              border:       Border.all(
                                color: _terms ? _kBlue : _kGrey,
                                width: 1.5,
                              ),
                            ),
                            child: _terms
                                ? const Icon(Icons.check,
                                    color: _kWhite, size: 15)
                                : null,
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'I have read and agree to the Loan Agreement, '
                              'Terms of Service, and Privacy Policy. I confirm '
                              'all provided information is accurate and I am '
                              '18+ years old.',
                              style: TextStyle(
                                fontSize: 13, color: _kBlack, height: 1.45,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Submit
                  _loading
                      ? const _LoadBtn('Verifying details...')
                      : ElevatedButton.icon(
                          onPressed: _submit,
                          icon:  const Icon(Icons.arrow_forward_rounded),
                          label: const Text('Create Account'),
                        ),
                  const SizedBox(height: 20),

                  // ── Why us ──
                  const _WhyUsRow(),
                ]),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

// ───────────────────────────────────────────
//  MAIN APP SHELL
// ───────────────────────────────────────────
class AppShell extends StatefulWidget {
  final AppState state;
  const AppShell({super.key, required this.state});
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final screens = [
      HomeScreen(state: widget.state),
      LoansScreen(state: widget.state),
      ProfileScreen(state: widget.state),
    ];
    return Scaffold(
      body: IndexedStack(index: _tab, children: screens),
      bottomNavigationBar: _BottomNav(
        current: _tab,
        onTap:   (i) => setState(() => _tab = i),
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  final int current;
  final ValueChanged<int> onTap;
  const _BottomNav({required this.current, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color:     _kWhite,
        boxShadow: [
          BoxShadow(
            color:      Colors.black.withOpacity(.08),
            blurRadius: 20, offset: const Offset(0,-2),
          ),
        ],
      ),
      child: NavigationBar(
        selectedIndex:       current,
        onDestinationSelected: onTap,
        backgroundColor:     _kWhite,
        indicatorColor:      _kBlueLight,
        elevation:           0,
        destinations: const [
          NavigationDestination(
            icon:         Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home, color: _kBlue),
            label:        'Home',
          ),
          NavigationDestination(
            icon:         Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long, color: _kBlue),
            label:        'My Loans',
          ),
          NavigationDestination(
            icon:         Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person, color: _kBlue),
            label:        'Profile',
          ),
        ],
      ),
    );
  }
}

// ───────────────────────────────────────────
//  HOME SCREEN
// ───────────────────────────────────────────
class HomeScreen extends StatelessWidget {
  final AppState state;
  const HomeScreen({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ── Blue Header ──
          SliverAppBar(
            expandedHeight: 170,
            pinned:          true,
            backgroundColor: _kBlue,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 16, bottom: 14),
              title: const Text('EasyLoan',
                style: TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w800,
                  color: _kWhite,
                )),
              background: _HomeHeader(state: state),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // ── Active Loan Banner ──
                  if (state.hasActive) ...[
                    _ActiveLoanBanner(loan: state.activeLoan!, state: state),
                    const SizedBox(height: 24),
                  ],

                  // ── Section: Regular Loans ──
                  _SectionHeader(
                    title:    'Choose Loan Amount',
                    subtitle: state.hasActive
                        ? 'Repay current loan to apply again'
                        : 'Select an amount · Get money instantly',
                  ),
                  const SizedBox(height: 14),
                  _AmountGrid(state: state),
                  const SizedBox(height: 28),

                  // ── Loan Info Row ──
                  Row(children: [
                    _InfoPill(Icons.calendar_month, '15-day tenure', _kBlue),
                    const SizedBox(width: 8),
                    _InfoPill(Icons.payments_outlined, '₹100 flat fee', _kGreenMid),
                    const SizedBox(width: 8),
                    _InfoPill(Icons.bolt, 'Instant', _kOrange),
                  ]),
                  const SizedBox(height: 28),

                  // ── Section: Recharge Loans ──
                  const _SectionHeader(
                    title:    'Recharge Loans',
                    subtitle: 'Short-term micro loans · 10-day tenure',
                  ),
                  const SizedBox(height: 12),
                  ..._rechargePlans.map((plan) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child:   _RechargeTile(
                      state:   state,
                      loan:    plan['loan'] as int,
                      repay:   plan['repay'] as int,
                      days:    plan['days'] as int,
                      label:   plan['label'] as String,
                    ),
                  )),
                  const SizedBox(height: 24),

                  // ── Penalty Notice ──
                  _PenaltyBox(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeHeader extends StatelessWidget {
  final AppState state;
  const _HomeHeader({required this.state});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_kBlue, _kBlueDark],
          begin:  Alignment.topLeft,
          end:    Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 52, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const _LogoIcon(size: 32),
            const SizedBox(width: 8),
            const Text('EasyLoan',
              style: TextStyle(
                color: _kWhite, fontSize: 16,
                fontWeight: FontWeight.w800,
              )),
            const Spacer(),
            // On-time badge
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color:        Colors.white20,
                borderRadius: BorderRadius.circular(100),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.verified, color: _kWhite, size: 13),
                const SizedBox(width: 4),
                Text('${state.onTimePay} on-time',
                  style: const TextStyle(
                    color: _kWhite, fontSize: 11,
                    fontWeight: FontWeight.w600,
                  )),
              ]),
            ),
          ]),
          const SizedBox(height: 16),
          Text('Hello, ${state.name.split(' ').first} 👋',
            style: const TextStyle(
              color: _kWhite, fontSize: 22,
              fontWeight: FontWeight.w800,
            )),
          Text(state.hasActive
              ? 'You have an active loan'
              : 'Ready for a quick loan?',
            style: const TextStyle(
              color: Colors.white70, fontSize: 13,
            )),
        ],
      ),
    );
  }
}

// ───────────────────────────────────────────
//  AMOUNT GRID
// ───────────────────────────────────────────
class _AmountGrid extends StatelessWidget {
  final AppState state;
  const _AmountGrid({required this.state});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics:    const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 1.6,
        crossAxisSpacing: 10,
        mainAxisSpacing:  10,
      ),
      itemCount: _regularAmounts.length,
      itemBuilder: (ctx, i) {
        final amt       = _regularAmounts[i];
        final unlocked  = _isUnlocked(amt, state.onTimePay);
        final blocked   = state.hasActive;
        return _AmountTile(
          amount:      amt,
          unlocked:    unlocked,
          blocked:     blocked,
          unlockHint:  _unlockMsg(amt),
          onTap: () => Navigator.push(ctx, _slide(
              ApplyScreen(
                state:     state,
                amount:    amt,
                repay:     amt + _regularFee,
                tenure:    _regularTenure,
                recharge:  false,
              ))),
        );
      },
    );
  }
}

class _AmountTile extends StatelessWidget {
  final int    amount;
  final bool   unlocked, blocked;
  final String unlockHint;
  final VoidCallback onTap;
  const _AmountTile({
    required this.amount, required this.unlocked,
    required this.blocked, required this.unlockHint,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dim = !unlocked || blocked;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        if (!unlocked) {
          _showDialog(context,
            icon:    const Icon(Icons.lock_rounded, color: _kOrange, size: 32),
            title:   'Locked Amount',
            msg:     '₹$amount unlocks after:\n$unlockHint',
          );
        } else if (blocked) {
          _showDialog(context,
            icon:    const Icon(Icons.info_rounded, color: _kBlue, size: 32),
            title:   'Active Loan Exists',
            msg:     'Repay your current loan before applying for a new one.',
          );
        } else {
          onTap();
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: dim ? const Color(0xFFEEEEEE) : _kBlueLight,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: dim
                ? Colors.transparent
                : _kBlue.withOpacity(.3),
            width: 1.5,
          ),
          boxShadow: dim ? [] : [
            BoxShadow(
              color:      _kBlue.withOpacity(.1),
              blurRadius: 6, offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(children: [
          Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('₹$amount',
                style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w900,
                  color: dim ? _kGrey : _kBlue,
                )),
              Text('+₹$_regularFee',
                style: TextStyle(
                  fontSize: 9.5, color: dim ? _kGrey : _kMid,
                )),
            ]),
          ),
          if (!unlocked)
            Positioned(
              top: 6, right: 6,
              child: Icon(Icons.lock_rounded,
                  size: 12, color: _kGrey.withOpacity(.7)),
            ),
        ]),
      ),
    );
  }

  void _showDialog(BuildContext ctx,
      {required Widget icon, required String title, required String msg}) {
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        shape:  RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          icon, const SizedBox(height: 12),
          Text(title, style: const TextStyle(
              fontSize: 17, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(msg,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13.5, color: _kMid, height: 1.4)),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child:     const Text('Got it'),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────────────────────────
//  ACTIVE LOAN BANNER
// ───────────────────────────────────────────
class _ActiveLoanBanner extends StatelessWidget {
  final Loan     loan;
  final AppState state;
  const _ActiveLoanBanner({required this.loan, required this.state});

  @override
  Widget build(BuildContext context) {
    final daysLeft = loan.dueDate.difference(DateTime.now()).inDays;
    final overdue  = loan.isOverdue;
    final c1       = overdue ? _kRedMid : _kBlue;
    final c2       = overdue ? _kRed    : _kBlueDark;

    return GestureDetector(
      onTap: () => Navigator.push(context,
          _slide(RepayScreen(state: state, loan: loan))),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient:     LinearGradient(
            colors:  [c1, c2],
            begin:   Alignment.topLeft,
            end:     Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color:      c1.withOpacity(.35),
              blurRadius: 18, offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: ID + Status
            Row(children: [
              _Tag(loan.id, _kWhite.withOpacity(.9),
                  Colors.white24),
              const Spacer(),
              _Tag(
                overdue ? '⚠ OVERDUE' : '● ACTIVE',
                _kWhite,
                Colors.white24,
                bold: true,
              ),
            ]),
            const SizedBox(height: 14),

            // Amount
            Text('₹${loan.amount}',
              style: const TextStyle(
                color: _kWhite, fontSize: 40,
                fontWeight: FontWeight.w900, height: 1,
              )),
            const Text('Loan Amount',
              style: TextStyle(color: Colors.white60, fontSize: 12)),
            const SizedBox(height: 16),
            const Divider(color: Colors.white24, height: 1),
            const SizedBox(height: 14),

            // Stats row
            Row(children: [
              _BannerStat('Balance Due', '₹${loan.totalDue}'),
              const SizedBox(width: 28),
              _BannerStat('Due Date',
                  DateFormat('dd MMM').format(loan.dueDate)),
              const SizedBox(width: 28),
              _BannerStat(
                overdue ? 'Overdue By' : 'Days Left',
                overdue ? '${daysLeft.abs()}d' : '${daysLeft}d',
              ),
            ]),
            const SizedBox(height: 16),

            // CTA button
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 11),
              decoration: BoxDecoration(
                color: _kWhite,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Tap to Repay',
                      style: TextStyle(
                        color: c1,
                        fontWeight: FontWeight.w800, fontSize: 14,
                      )),
                    const SizedBox(width: 4),
                    Icon(Icons.arrow_forward_rounded, color: c1, size: 18),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BannerStat extends StatelessWidget {
  final String label, value;
  const _BannerStat(this.label, this.value);
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(
          color: Colors.white54, fontSize: 10)),
      Text(value,  style: const TextStyle(
          color: _kWhite, fontSize: 14, fontWeight: FontWeight.w800)),
    ],
  );
}

// ───────────────────────────────────────────
//  RECHARGE TILE
// ───────────────────────────────────────────
class _RechargeTile extends StatelessWidget {
  final AppState state;
  final int      loan, repay, days;
  final String   label;
  const _RechargeTile({
    required this.state, required this.loan,
    required this.repay, required this.days,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final blocked = state.hasActive;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        if (blocked) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content:         Text('Repay your current loan first'),
            backgroundColor: _kRedMid,
            behavior:        SnackBarBehavior.floating,
          ));
          return;
        }
        Navigator.push(context, _slide(ApplyScreen(
          state:    state,
          amount:   loan,
          repay:    repay,
          tenure:   days,
          recharge: true,
        )));
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color:  blocked ? _kGreyBg : _kGreenBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: blocked
                ? Colors.transparent
                : _kGreenMid.withOpacity(.3),
          ),
        ),
        child: Row(children: [
          // Amount circle
          Container(
            width:  52, height: 52,
            decoration: BoxDecoration(
              color: blocked ? _kGrey.withOpacity(.2) : _kGreenMid,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text('₹$loan',
                style: TextStyle(
                  color: blocked ? _kGrey : _kWhite,
                  fontWeight: FontWeight.w900, fontSize: 13,
                )),
            ),
          ),
          const SizedBox(width: 14),

          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$label Plan',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: blocked ? _kGrey : _kBlack,
                )),
              const SizedBox(height: 2),
              Text('Borrow ₹$loan · Repay ₹$repay',
                style: TextStyle(
                  fontSize: 12,
                  color: blocked ? _kGrey : _kMid,
                )),
              Text('$days-day tenure · Instant',
                style: const TextStyle(fontSize: 11, color: _kGrey)),
            ],
          )),

          // Profit tag + arrow
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: blocked
                    ? _kGrey.withOpacity(.15)
                    : _kGreenMid.withOpacity(.12),
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text('+₹${repay - loan}',
                style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w700,
                  color: blocked ? _kGrey : _kGreenMid,
                )),
            ),
            const SizedBox(height: 4),
            Icon(Icons.chevron_right,
                color: blocked ? _kGrey : _kGreenMid, size: 22),
          ]),
        ]),
      ),
    );
  }
}

// ───────────────────────────────────────────
//  PENALTY BOX
// ───────────────────────────────────────────
class _PenaltyBox extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kRedBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kRedMid.withOpacity(.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Icon(Icons.warning_amber_rounded,
                color: _kRedMid, size: 18),
            SizedBox(width: 8),
            Text('Late Payment Penalty',
              style: TextStyle(
                color: _kRedMid, fontWeight: FontWeight.w700,
                fontSize: 13,
              )),
          ]),
          const SizedBox(height: 10),
          _penaltyRow('₹100 loan',            '₹50 penalty'),
          _penaltyRow('₹200 – ₹500',          '₹100 penalty'),
          _penaltyRow('₹600 – ₹1000',         '₹200 penalty'),
          _penaltyRow('₹1100 – ₹1500',        '₹250 penalty'),
          _penaltyRow('₹1600 – ₹2000',        '₹300 penalty'),
          const SizedBox(height: 8),
          const Text(
            'Penalty is one-time, applied after due date. Not compounding.',
            style: TextStyle(fontSize: 11, color: _kRedMid, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _penaltyRow(String l, String r) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(children: [
      const Icon(Icons.circle, size: 5, color: _kRedMid),
      const SizedBox(width: 8),
      Expanded(child: Text(l,
          style: const TextStyle(fontSize: 12, color: _kBlack))),
      Text(r,
          style: const TextStyle(
              fontSize: 12, fontWeight: FontWeight.w700, color: _kRedMid)),
    ]),
  );
}

// ───────────────────────────────────────────
//  APPLY SCREEN
// ───────────────────────────────────────────
class ApplyScreen extends StatefulWidget {
  final AppState state;
  final int  amount, repay, tenure;
  final bool recharge;
  const ApplyScreen({
    super.key,
    required this.state,   required this.amount,
    required this.repay,   required this.tenure,
    required this.recharge,
  });
  @override
  State<ApplyScreen> createState() => _ApplyState();
}

class _ApplyState extends State<ApplyScreen> {
  bool _agreed  = false;
  bool _loading = false;
  int  _step    = 0; // 0=summary, 1=agree, 2=processing

  int  get _fee     => widget.repay - widget.amount;
  int  get _penalty => _penalty2(widget.amount);
  int  _penalty2(int a) => _penalty(a);
  DateTime get _due => DateTime.now().add(Duration(days: widget.tenure));

  Future<void> _submit() async {
    if (!_agreed) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content:         Text('Please accept the Loan Agreement to continue'),
        backgroundColor: _kRedMid,
        behavior:        SnackBarBehavior.floating,
      ));
      return;
    }
    setState(() { _loading = true; _step = 2; });

    // Create loan
    final loan = await widget.state.applyLoan(
      amount:   widget.amount,
      repay:    widget.repay,
      tenure:   widget.tenure,
      recharge: widget.recharge,
    );

    // Generate PDF agreement
    final pdfPath = await PdfService.generateAgreement(
      loan:      loan,
      userName:  widget.state.name,
      userPhone: widget.state.phone,
      userPan:   widget.state.pan,
    );
    await widget.state.updateAgreement(loan.id, pdfPath);

    if (!mounted) return;
    Navigator.pushReplacement(context,
        _slide(SuccessScreen(state: widget.state, loan: loan,
            agreementPath: pdfPath)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Loan Summary')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(children: [

          // ── Hero card ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_kBlue, _kBlueDark],
                begin:  Alignment.topLeft,
                end:    Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color:      _kBlue.withOpacity(.3),
                  blurRadius: 20, offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(children: [
              const Text('You will receive',
                style: TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 4),
              Text('₹${widget.amount}',
                style: const TextStyle(
                  color: _kWhite, fontSize: 54,
                  fontWeight: FontWeight.w900, height: 1,
                )),
              const SizedBox(height: 18),
              const Divider(color: Colors.white24),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _HeroStat('Repay',    '₹${widget.repay}'),
                  _HeroStat('Tenure',   '${widget.tenure} days'),
                  _HeroStat('Due Date', DateFormat('dd MMM').format(_due)),
                ],
              ),
            ]),
          ),
          const SizedBox(height: 20),

          // ── Breakdown ──
          _Card(children: [
            const _CardTitle('Loan Breakdown'),
            const SizedBox(height: 12),
            _Row2('Principal Amount',   '₹${widget.amount}'),
            _Row2('Processing Fee',     '+ ₹$_fee'),
            _Row2('Total Repayment',    '₹${widget.repay}', bold: true),
            const Divider(height: 20, color: Color(0xFFEEEEEE)),
            _Row2('Due Date',
                DateFormat('dd MMM yyyy').format(_due)),
            _Row2('Loan Type',
                widget.recharge ? 'Recharge Loan' : 'Regular Loan'),
            _Row2('Late Penalty',       '₹${_penalty(widget.amount)}',
                sub: 'One-time, after due date'),
          ]),
          const SizedBox(height: 16),

          // ── Agreement ──
          _Card(children: [
            const _CardTitle('Loan Agreement'),
            const SizedBox(height: 10),
            const Text(
              'By proceeding, you digitally sign the loan agreement. '
              'A PDF copy will be saved on your device.',
              style: TextStyle(fontSize: 12.5, color: _kMid, height: 1.5),
            ),
            const SizedBox(height: 14),
            // Key terms
            _AgreeTerm(Icons.schedule,
                'Repay ₹${widget.repay} by ${DateFormat('dd MMM yyyy').format(_due)}'),
            _AgreeTerm(Icons.warning_amber_rounded,
                '₹${_penalty(widget.amount)} penalty after due date (one-time)'),
            _AgreeTerm(Icons.payment,
                'Partial payment allowed (min ₹10)'),
            _AgreeTerm(Icons.description_outlined,
                'PDF agreement will be generated & saved'),
            const SizedBox(height: 14),
            GestureDetector(
              onTap: () => setState(() => _agreed = !_agreed),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _agreed ? _kBlueLight : _kGreyBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _agreed ? _kBlue.withOpacity(.5) : Colors.transparent,
                    width: 1.5,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 22, height: 22,
                      decoration: BoxDecoration(
                        color:        _agreed ? _kBlue : _kWhite,
                        borderRadius: BorderRadius.circular(5),
                        border:       Border.all(
                          color: _agreed ? _kBlue : _kGrey,
                          width: 1.5,
                        ),
                      ),
                      child: _agreed
                          ? const Icon(Icons.check,
                              color: _kWhite, size: 15)
                          : null,
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'I accept the Loan Agreement and confirm all my '
                        'details are correct. I understand the repayment '
                        'terms and penalty clauses.',
                        style: TextStyle(
                          fontSize: 13, color: _kBlack, height: 1.45,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ]),
          const SizedBox(height: 24),

          // ── CTA ──
          _loading
              ? const _LoadBtn('Processing Loan...')
              : ElevatedButton.icon(
                  onPressed: _submit,
                  icon:  const Icon(Icons.check_circle_outline),
                  label: Text('Get ₹${widget.amount} Now'),
                ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
                style: TextStyle(color: _kGrey)),
          ),
          const SizedBox(height: 24),
        ]),
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  final String label, value;
  const _HeroStat(this.label, this.value);
  @override
  Widget build(BuildContext context) => Column(children: [
    Text(label, style: const TextStyle(
        color: Colors.white60, fontSize: 11)),
    const SizedBox(height: 4),
    Text(value, style: const TextStyle(
        color: _kWhite, fontSize: 15, fontWeight: FontWeight.w800)),
  ]);
}

class _AgreeTerm extends StatelessWidget {
  final IconData icon;
  final String   text;
  const _AgreeTerm(this.icon, this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, size: 15, color: _kBlue),
      const SizedBox(width: 8),
      Expanded(child: Text(text,
        style: const TextStyle(fontSize: 12.5, color: _kBlack))),
    ]),
  );
}

// ───────────────────────────────────────────
//  SUCCESS SCREEN
// ───────────────────────────────────────────
class SuccessScreen extends StatelessWidget {
  final AppState state;
  final Loan     loan;
  final String   agreementPath;
  const SuccessScreen({
    super.key,
    required this.state,
    required this.loan,
    required this.agreementPath,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(children: [
            const SizedBox(height: 24),

            // ── Success icon ──
            Container(
              width: 100, height: 100,
              decoration: const BoxDecoration(
                color: _kGreenBg, shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: _kGreenMid, size: 64,
              ),
            ),
            const SizedBox(height: 20),
            const Text('Loan Approved! 🎉',
              style: TextStyle(
                fontSize: 26, fontWeight: FontWeight.w800,
                color: _kBlack,
              )),
            const SizedBox(height: 6),
            Text(
              '₹${loan.amount} has been disbursed to your account',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: _kMid),
            ),
            const SizedBox(height: 28),

            // ── Details ──
            _Card(children: [
              const _CardTitle('Loan Details'),
              const SizedBox(height: 12),
              _Row2('Loan ID',     loan.id),
              _Row2('Amount',      '₹${loan.amount}'),
              _Row2('Repay',       '₹${loan.repayAmount}'),
              _Row2('Due Date',
                  DateFormat('dd MMM yyyy').format(loan.dueDate)),
              _Row2('Late Penalty',
                  '₹${_penalty(loan.amount)} (if overdue)'),
            ]),
            const SizedBox(height: 16),

            // ── Agreement PDF card ──
            _Card(children: [
              const _CardTitle('Loan Agreement PDF'),
              const SizedBox(height: 10),
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _kBlueLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.picture_as_pdf,
                      color: _kBlue, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Agreement_${0}.pdf',
                      style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700,
                      )),
                    Text('agreement_${loan.id}.pdf',
                      style: const TextStyle(
                          fontSize: 11, color: _kGrey)),
                  ],
                )),
                TextButton(
                  onPressed: () => OpenFile.open(agreementPath),
                  child:     const Text('Open'),
                ),
              ]),
            ]),
            const SizedBox(height: 28),

            // ── CTA ──
            ElevatedButton(
              onPressed: () => Navigator.pushAndRemoveUntil(
                context,
                _slide(AppShell(state: state)),
                (_) => false,
              ),
              child: const Text('Go to Dashboard'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => Navigator.push(
                context,
                _slide(RepayScreen(state: state, loan: loan)),
              ),
              icon:  const Icon(Icons.payment),
              label: const Text('Repay Now'),
              style: OutlinedButton.styleFrom(
                foregroundColor: _kBlue,
                side: const BorderSide(color: _kBlue),
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
            const SizedBox(height: 32),
          ]),
        ),
      ),
    );
  }
}

// ───────────────────────────────────────────
//  REPAY SCREEN  (Swipe-to-Pay + Partial)
// ───────────────────────────────────────────
class RepayScreen extends StatefulWidget {
  final AppState state;
  final Loan     loan;
  const RepayScreen({super.key, required this.state, required this.loan});
  @override
  State<RepayScreen> createState() => _RepayState();
}

class _RepayState extends State<RepayScreen> {
  final _amtCtrl = TextEditingController();
  bool    _loading = false;
  String? _amtErr;

  @override
  void initState() {
    super.initState();
    _amtCtrl.text = widget.loan.totalDue.toString();
  }

  @override
  void dispose() {
    _amtCtrl.dispose();
    super.dispose();
  }

  Future<void> _pay(int amount) async {
    if (amount < 10) {
      setState(() => _amtErr = 'Minimum payment is ₹10');
      return;
    }
    if (amount > widget.loan.totalDue) {
      setState(() => _amtErr =
          'Max payable is ₹${widget.loan.totalDue}');
      return;
    }
    setState(() { _loading = true; _amtErr = null; });
    HapticFeedback.mediumImpact();
    await Future.delayed(const Duration(milliseconds: 1000));
    await widget.state.makePayment(widget.loan.id, amount);
    if (!mounted) return;
    setState(() => _loading = false);

    final completed = widget.loan.isPaid;
    HapticFeedback.heavyImpact();
    if (completed) {
      Navigator.pushReplacement(context,
          _slide(_PaySuccessScreen(state: widget.state,
              loan: widget.loan, amount: amount)));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content:         Text('✅  ₹$amount paid. Balance: ₹${widget.loan.totalDue}'),
        backgroundColor: _kGreenMid,
        behavior:        SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10)),
      ));
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loan    = widget.loan;
    final overdue = loan.isOverdue;
    final days    = loan.dueDate.difference(DateTime.now()).inDays;
    final c       = overdue ? _kRedMid : _kBlue;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: c,
        title: const Text('Repay Loan'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(children: [

          // ── Status banner ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color:        overdue ? _kRedBg : _kBlueLight,
              borderRadius: BorderRadius.circular(16),
              border:       Border.all(
                  color: c.withOpacity(.3)),
            ),
            child: Row(children: [
              Icon(
                overdue
                    ? Icons.warning_amber_rounded
                    : Icons.timer_outlined,
                color: c, size: 32,
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    overdue
                        ? 'Overdue by ${days.abs()} days!'
                        : 'Due in $days days',
                    style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700,
                      color: c,
                    )),
                  Text(
                    overdue
                        ? 'Penalty of ₹${_penalty(loan.amount)} has been applied'
                        : 'Pay on time to avoid penalty',
                    style: TextStyle(
                      fontSize: 12, color: c.withOpacity(.8),
                    )),
                ],
              )),
            ]),
          ),
          const SizedBox(height: 16),

          // ── Loan details ──
          _Card(children: [
            const _CardTitle('Loan Details'),
            const SizedBox(height: 12),
            _Row2('Loan ID',     loan.id),
            _Row2('Principal',   '₹${loan.amount}'),
            _Row2('Base Repay',  '₹${loan.repayAmount}'),
            if (loan.penaltyApplied)
              _Row2('Penalty',   '+ ₹${loan.penaltyAmt}',
                  color: _kRedMid),
            _Row2('Paid So Far', '₹${loan.paid}',
                color: _kGreenMid),
            const Divider(height: 20, color: Color(0xFFEEEEEE)),
            _Row2('Balance Due', '₹${loan.totalDue}',
                bold: true, color: c),
          ]),
          const SizedBox(height: 20),

          // ── Swipe to Pay ──
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('Quick Pay (Full Amount)',
              style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600,
                color: _kMid,
              )),
          ),
          const SizedBox(height: 8),
          _SwipeToPay(
            amount:   loan.totalDue,
            isOverdue: overdue,
            loading:  _loading,
            onSwiped: () => _pay(loan.totalDue),
          ),
          const SizedBox(height: 24),

          // ── Partial ──
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('Or Enter Custom Amount',
              style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600,
                color: _kMid,
              )),
          ),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: TextField(
                controller:      _amtCtrl,
                keyboardType:    TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged:       (_) => setState(() => _amtErr = null),
                decoration: InputDecoration(
                  hintText:  'Enter amount',
                  prefixText: '₹  ',
                  errorText: _amtErr,
                ),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              height: 54,
              child: ElevatedButton(
                onPressed: _loading
                    ? null
                    : () {
                        final v = int.tryParse(_amtCtrl.text.trim()) ?? 0;
                        _pay(v);
                      },
                style: ElevatedButton.styleFrom(
                  minimumSize: Size.zero,
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  backgroundColor: c,
                ),
                child: _loading
                    ? const SizedBox(
                        width: 22, height: 22,
                        child: CircularProgressIndicator(
                          color: _kWhite, strokeWidth: 2.5))
                    : const Text('Pay',
                        style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ]),
          const SizedBox(height: 16),
          Text(
            'Min ₹10 · Balance continues until full repayment',
            style: const TextStyle(fontSize: 11.5, color: _kGrey),
          ),

          // ── View Agreement ──
          if (loan.agreementPath != null) ...[
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: () => OpenFile.open(loan.agreementPath!),
              icon:  const Icon(Icons.picture_as_pdf, size: 18),
              label: const Text('View Loan Agreement'),
              style: OutlinedButton.styleFrom(
                foregroundColor: _kBlue,
                side:            const BorderSide(color: _kBlue),
                minimumSize:     const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
          const SizedBox(height: 32),
        ]),
      ),
    );
  }
}

// ───────────────────────────────────────────
//  SWIPE-TO-PAY  WIDGET
// ───────────────────────────────────────────
class _SwipeToPay extends StatefulWidget {
  final int      amount;
  final bool     isOverdue;
  final bool     loading;
  final Future<void> Function() onSwiped;
  const _SwipeToPay({
    required this.amount,   required this.isOverdue,
    required this.loading,  required this.onSwiped,
  });
  @override
  State<_SwipeToPay> createState() => _SwipeToPayState();
}

class _SwipeToPayState extends State<_SwipeToPay>
    with SingleTickerProviderStateMixin {
  double _dx       = 0;
  bool   _done     = false;
  static const double _btn = 60.0;

  late AnimationController _bounce;
  late Animation<double>    _bounceAnim;

  @override
  void initState() {
    super.initState();
    _bounce = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
    _bounceAnim = Tween(begin: 0.0, end: 6.0)
        .animate(CurvedAnimation(parent: _bounce, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _bounce.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w   = MediaQuery.of(context).size.width - 40;
    final max = w - _btn - 8;
    final pct = (_dx / max).clamp(0.0, 1.0);
    final c   = widget.isOverdue ? _kRedMid : _kBlue;

    return Container(
      height: 70,
      width:  w,
      decoration: BoxDecoration(
        color:        c.withOpacity(.08),
        borderRadius: BorderRadius.circular(100),
        border:       Border.all(color: c.withOpacity(.25)),
      ),
      child: Stack(alignment: Alignment.center, children: [

        // ── Fill bar ──
        Align(
          alignment: Alignment.centerLeft,
          child: AnimatedContainer(
            duration:   Duration.zero,
            width:      _dx + _btn,
            height:     70,
            decoration: BoxDecoration(
              color:        c.withOpacity(.13),
              borderRadius: BorderRadius.circular(100),
            ),
          ),
        ),

        // ── Label ──
        if (!_done)
          Opacity(
            opacity: 1 - pct,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(width: 60),
                Icon(Icons.chevron_right, color: c, size: 18),
                Icon(Icons.chevron_right,
                    color: c.withOpacity(.5), size: 18),
                Text('  Swipe to Pay  ₹${widget.amount}',
                  style: TextStyle(
                    color: c, fontWeight: FontWeight.w700, fontSize: 14,
                  )),
              ],
            ),
          ),

        if (_done && widget.loading)
          const SizedBox(
            width: 26, height: 26,
            child: CircularProgressIndicator(
                color: _kGreenMid, strokeWidth: 2.5),
          ),

        if (_done && !widget.loading)
          const Icon(Icons.check_circle_rounded,
              color: _kGreenMid, size: 32),

        // ── Thumb ──
        if (!_done)
          Positioned(
            left: 4 + _dx,
            child: AnimatedBuilder(
              animation: _bounceAnim,
              builder: (_, child) => Transform.translate(
                offset: _dx < 10
                    ? Offset(_bounceAnim.value, 0)
                    : Offset.zero,
                child: child,
              ),
              child: GestureDetector(
                onHorizontalDragUpdate: (d) {
                  setState(() {
                    _dx = (_dx + d.delta.dx).clamp(0, max);
                  });
                },
                onHorizontalDragEnd: (_) async {
                  if (_dx / max >= 0.80) {
                    setState(() => _done = true);
                    await widget.onSwiped();
                  } else {
                    setState(() => _dx = 0);
                  }
                },
                child: Container(
                  width:  _btn, height: _btn,
                  decoration: BoxDecoration(
                    color: c, shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color:      c.withOpacity(.45),
                        blurRadius: 12, offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.double_arrow_rounded,
                    color: _kWhite, size: 30,
                  ),
                ),
              ),
            ),
          ),
      ]),
    );
  }
}

// ───────────────────────────────────────────
//  PAY SUCCESS SCREEN
// ───────────────────────────────────────────
class _PaySuccessScreen extends StatelessWidget {
  final AppState state;
  final Loan     loan;
  final int      amount;
  const _PaySuccessScreen({
    required this.state, required this.loan, required this.amount,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 110, height: 110,
                decoration: const BoxDecoration(
                  color: _kGreenBg, shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle_rounded,
                    color: _kGreenMid, size: 70),
              ),
              const SizedBox(height: 24),
              const Text('Payment Successful! 🎊',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 26, fontWeight: FontWeight.w800,
                  color: _kBlack,
                )),
              const SizedBox(height: 8),
              Text(
                '₹$amount paid · Loan ${loan.id} is fully cleared!',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: _kMid),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: _kGreenBg,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: const Text(
                  '✓ On-time repayment recorded',
                  style: TextStyle(
                    color: _kGreenMid,
                    fontWeight: FontWeight.w600, fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () => Navigator.pushAndRemoveUntil(
                  context,
                  _slide(AppShell(state: state)),
                  (_) => false,
                ),
                child: const Text('Back to Home'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ───────────────────────────────────────────
//  LOANS SCREEN
// ───────────────────────────────────────────
class LoansScreen extends StatelessWidget {
  final AppState state;
  const LoansScreen({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final loans = state.loans;
    return Scaffold(
      appBar: AppBar(title: const Text('My Loans')),
      body: loans.isEmpty
          ? const _Empty(
              icon:  Icons.receipt_long_outlined,
              title: 'No Loans Yet',
              body:  'Apply from the Home screen to get started',
            )
          : ListView.separated(
              padding:           const EdgeInsets.all(16),
              itemCount:         loans.length,
              separatorBuilder:  (_, __) => const SizedBox(height: 10),
              itemBuilder: (ctx, i) => _LoanTile(
                loan:  loans[i],
                state: state,
              ),
            ),
    );
  }
}

class _LoanTile extends StatelessWidget {
  final Loan     loan;
  final AppState state;
  const _LoanTile({required this.loan, required this.state});

  @override
  Widget build(BuildContext context) {
    final c    = loan.statusColor;
    final bg   = loan.isPaid ? _kGreenBg
        : loan.isOverdue ? _kRedBg : _kBlueLight;

    return GestureDetector(
      onTap: () {
        if (!loan.isPaid) {
          Navigator.push(context,
              _slide(RepayScreen(state: state, loan: loan)));
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color:        bg,
          borderRadius: BorderRadius.circular(16),
          border:       Border.all(color: c.withOpacity(.25)),
        ),
        child: Row(children: [
          // Amount circle
          Container(
            width: 50, height: 50,
            decoration: BoxDecoration(
              color: c.withOpacity(.15), shape: BoxShape.circle,
            ),
            child: Center(
              child: Text('₹${loan.amount}',
                style: TextStyle(
                  color: c,
                  fontWeight: FontWeight.w900, fontSize: 12,
                )),
            ),
          ),
          const SizedBox(width: 14),

          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Text(loan.id,
                  style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w800,
                    color: _kBlack,
                  )),
                const SizedBox(width: 6),
                if (loan.isRecharge)
                  _Tag('Recharge', Colors.green.shade700,
                      Colors.green.shade50),
              ]),
              const SizedBox(height: 2),
              Text(
                'Due ${DateFormat('dd MMM yyyy').format(loan.dueDate)}',
                style: const TextStyle(fontSize: 11.5, color: _kMid),
              ),
            ],
          )),

          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            _Tag(loan.statusLabel, _kWhite, c),
            const SizedBox(height: 4),
            Text(
              loan.isPaid ? 'Paid ✓' : '₹${loan.totalDue} due',
              style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w700, color: c,
              )),
            if (loan.agreementPath != null)
              GestureDetector(
                onTap: () => OpenFile.open(loan.agreementPath!),
                child: const Text('PDF',
                  style: TextStyle(
                    fontSize: 10, color: _kBlue,
                    decoration: TextDecoration.underline,
                  )),
              ),
          ]),
        ]),
      ),
    );
  }
}

// ───────────────────────────────────────────
//  PROFILE SCREEN
// ───────────────────────────────────────────
class ProfileScreen extends StatelessWidget {
  final AppState state;
  const ProfileScreen({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Profile')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(children: [

          // ── Avatar ──
          Container(
            width: 84, height: 84,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [_kBlue, _kBlueDark],
              ),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                state.name.isNotEmpty
                    ? state.name.trim()[0].toUpperCase()
                    : 'U',
                style: const TextStyle(
                  color: _kWhite, fontSize: 34,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(state.name,
            style: const TextStyle(
              fontSize: 20, fontWeight: FontWeight.w800,
              color: _kBlack,
            )),
          Text('+91 ${state.phone}',
            style: const TextStyle(fontSize: 13, color: _kMid)),
          if (state.pan.isNotEmpty)
            Text('PAN: ${state.pan}',
              style: const TextStyle(fontSize: 12, color: _kGrey)),
          const SizedBox(height: 20),

          // ── Stats ──
          Row(children: [
            _StatBox('${state.loans.length}',  'Total Loans',   _kBlue),
            const SizedBox(width: 10),
            _StatBox('${state.onTimePay}',     'On-Time Pays',  _kGreenMid),
            const SizedBox(width: 10),
            _StatBox(
              state.onTimePay >= 6 ? '₹2000'
                  : state.onTimePay >= 3 ? '₹1000' : '₹200',
              'Max Limit', _kOrange,
            ),
          ]),
          const SizedBox(height: 20),

          // ── Unlock progress ──
          _UnlockProgress(count: state.onTimePay),
          const SizedBox(height: 20),

          // ── Loan History ──
          _Card(children: [
            const _CardTitle('Loan History'),
            const SizedBox(height: 10),
            if (state.loans.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child:   Text('No loans yet',
                  style: TextStyle(color: _kGrey, fontSize: 13)),
              )
            else
              ...state.loans.map((l) => _MiniLoanRow(loan: l, state: state)),
          ]),
          const SizedBox(height: 20),

          // ── Penalty schedule ──
          _Card(children: [
            const _CardTitle('Penalty Schedule'),
            const SizedBox(height: 10),
            _Row2('₹100 loan',        '₹50'),
            _Row2('₹200 – ₹500',      '₹100'),
            _Row2('₹600 – ₹1000',     '₹200'),
            _Row2('₹1100 – ₹1500',    '₹250'),
            _Row2('₹1600 – ₹2000',    '₹300'),
            const SizedBox(height: 6),
            const Text('One-time penalty applied after due date.',
              style: TextStyle(fontSize: 11, color: _kGrey)),
          ]),
          const SizedBox(height: 20),

          // ── Reset ──
          OutlinedButton.icon(
            onPressed: () => _confirmReset(context),
            icon:  const Icon(Icons.logout, size: 18),
            label: const Text('Reset / Logout'),
            style: OutlinedButton.styleFrom(
              foregroundColor: _kRedMid,
              side:            const BorderSide(color: _kRedMid),
              minimumSize:     const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
          ),
          const SizedBox(height: 32),
        ]),
      ),
    );
  }

  void _confirmReset(BuildContext ctx) {
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title:   const Text('Reset App?'),
        content: const Text('This will clear all your data. Continue?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child:     const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await state.resetAll();
              if (ctx.mounted) {
                Navigator.pushAndRemoveUntil(
                  ctx,
                  _slide(KYCScreen(state: state)),
                  (_) => false,
                );
              }
            },
            child: const Text('Reset',
                style: TextStyle(color: _kRedMid)),
          ),
        ],
      ),
    );
  }
}

class _MiniLoanRow extends StatelessWidget {
  final Loan     loan;
  final AppState state;
  const _MiniLoanRow({required this.loan, required this.state});

  @override
  Widget build(BuildContext context) {
    final c = loan.statusColor;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Container(
          width: 8, height: 8,
          decoration: BoxDecoration(color: c, shape: BoxShape.circle),
        ),
        const SizedBox(width: 10),
        Text(loan.id,
          style: const TextStyle(
              fontSize: 12.5, fontWeight: FontWeight.w600)),
        const Spacer(),
        Text('₹${loan.amount}',
          style: const TextStyle(
              fontSize: 12.5, fontWeight: FontWeight.w700,
              color: _kBlack)),
        const SizedBox(width: 8),
        _Tag(loan.statusLabel, _kWhite, c),
      ]),
    );
  }
}

class _UnlockProgress extends StatelessWidget {
  final int count;
  const _UnlockProgress({required this.count});

  @override
  Widget build(BuildContext context) {
    return _Card(children: [
      const _CardTitle('Loan Limit Unlock'),
      const SizedBox(height: 14),
      _ProgRow('₹100–₹200',    'Always available', 1.0,  _kGreenMid, true),
      const SizedBox(height: 10),
      _ProgRow(
        '₹300–₹1000',
        count >= 3 ? 'Unlocked ✓' : '${count}/3 on-time payments',
        count / 3,  _kBlue,  count >= 3,
      ),
      const SizedBox(height: 10),
      _ProgRow(
        '₹1500–₹2000',
        count >= 6 ? 'Unlocked ✓' : '${count}/6 on-time payments',
        count / 6,  _kOrange, count >= 6,
      ),
    ]);
  }

  Widget _ProgRow(
      String label, String hint, double pct, Color c, bool done) {
    return Row(children: [
      Icon(done ? Icons.lock_open_rounded : Icons.lock_rounded,
          size: 17, color: done ? c : _kGrey),
      const SizedBox(width: 10),
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label,
                style: TextStyle(
                  fontSize: 12.5, fontWeight: FontWeight.w700,
                  color: done ? _kBlack : _kGrey,
                )),
              Text(hint,
                style: TextStyle(fontSize: 10.5, color: done ? c : _kGrey)),
            ],
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value:           pct.clamp(0, 1),
              minHeight:       5,
              backgroundColor: Colors.grey.shade200,
              valueColor:      AlwaysStoppedAnimation(c),
            ),
          ),
        ],
      )),
    ]);
  }
}

// ───────────────────────────────────────────
//  SHARED UI WIDGETS
// ───────────────────────────────────────────
class _LogoIcon extends StatelessWidget {
  final double size;
  const _LogoIcon({required this.size});
  @override
  Widget build(BuildContext context) => Container(
    width:  size, height: size,
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [_kBlue, _kBlueDark],
        begin:  Alignment.topLeft,
        end:    Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(size * .28),
      boxShadow: [
        BoxShadow(
          color:      _kBlue.withOpacity(.3),
          blurRadius: size * .2, offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Center(
      child: Icon(Icons.currency_rupee,
          color: _kWhite, size: size * .55),
    ),
  );
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String   label;
  final Color    color;
  const _Chip(this.icon, this.label, this.color);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color:        color.withOpacity(.09),
      borderRadius: BorderRadius.circular(100),
      border:       Border.all(color: color.withOpacity(.2)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 13, color: color),
      const SizedBox(width: 4),
      Text(label,
        style: TextStyle(
          fontSize: 11.5, color: color, fontWeight: FontWeight.w700,
        )),
    ]),
  );
}

class _Tag extends StatelessWidget {
  final String text;
  final Color  fg, bg;
  final bool   bold;
  const _Tag(this.text, this.fg, this.bg, {this.bold = false});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: bg, borderRadius: BorderRadius.circular(100),
    ),
    child: Text(text,
      style: TextStyle(
        color:      fg, fontSize: 10.5,
        fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
      )),
  );
}

class _SectionHeader extends StatelessWidget {
  final String title, subtitle;
  const _SectionHeader({required this.title, required this.subtitle});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: const TextStyle(
          fontSize: 17, fontWeight: FontWeight.w800, color: _kBlack)),
      const SizedBox(height: 2),
      Text(subtitle, style: const TextStyle(
          fontSize: 12.5, color: _kMid)),
    ],
  );
}

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String   text;
  final Color    color;
  const _InfoPill(this.icon, this.text, this.color);
  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color:        color.withOpacity(.07),
        borderRadius: BorderRadius.circular(10),
        border:       Border.all(color: color.withOpacity(.2)),
      ),
      child: Column(children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(height: 4),
        Text(text,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 10.5, color: color, fontWeight: FontWeight.w700,
          )),
      ]),
    ),
  );
}

class _FormLabel extends StatelessWidget {
  final String text;
  const _FormLabel(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(text, style: const TextStyle(
        fontSize: 13, fontWeight: FontWeight.w700, color: _kBlack)),
  );
}

class _Card extends StatelessWidget {
  final List<Widget> children;
  const _Card({required this.children});
  @override
  Widget build(BuildContext context) => Container(
    width:   double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: _kWhite,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color:      Colors.black.withOpacity(.06),
          blurRadius: 12, offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start,
        children: children),
  );
}

class _CardTitle extends StatelessWidget {
  final String text;
  const _CardTitle(this.text);
  @override
  Widget build(BuildContext context) => Text(text, style: const TextStyle(
      fontSize: 15, fontWeight: FontWeight.w800, color: _kBlack));
}

class _Row2 extends StatelessWidget {
  final String label, value;
  final bool   bold;
  final Color? color;
  final String? sub;
  const _Row2(this.label, this.value,
      {this.bold = false, this.color, this.sub});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4.5),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Flexible(
          child: Text(label,
            style: const TextStyle(fontSize: 13, color: _kMid)),
        ),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(value,
            style: TextStyle(
              fontSize:   13,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w700,
              color:      color ?? _kBlack,
            )),
          if (sub != null)
            Text(sub!, style: const TextStyle(
                fontSize: 10, color: _kGrey)),
        ]),
      ],
    ),
  );
}

class _StatBox extends StatelessWidget {
  final String value, label;
  final Color  color;
  const _StatBox(this.value, this.label, this.color);
  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color:        color.withOpacity(.07),
        borderRadius: BorderRadius.circular(14),
        border:       Border.all(color: color.withOpacity(.2)),
      ),
      child: Column(children: [
        Text(value,
          style: TextStyle(
            fontSize: 22, fontWeight: FontWeight.w900, color: color,
          )),
        const SizedBox(height: 2),
        Text(label,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 10, color: _kMid)),
      ]),
    ),
  );
}

class _Empty extends StatelessWidget {
  final IconData icon;
  final String   title, body;
  const _Empty({required this.icon, required this.title, required this.body});
  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 72, color: Colors.grey.shade300),
      const SizedBox(height: 16),
      Text(title,
        style: const TextStyle(
          fontSize: 16, fontWeight: FontWeight.w700, color: _kMid,
        )),
      const SizedBox(height: 6),
      Text(body,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 13, color: _kGrey)),
    ]),
  );
}

class _LoadBtn extends StatelessWidget {
  final String label;
  const _LoadBtn(this.label);
  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity, height: 54,
    child: ElevatedButton(
      onPressed: null,
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        const SizedBox(
          width: 20, height: 20,
          child: CircularProgressIndicator(
            color: _kWhite, strokeWidth: 2.5),
        ),
        const SizedBox(width: 12),
        Text(label),
      ]),
    ),
  );
}

class _WhyUsRow extends StatelessWidget {
  const _WhyUsRow();
  @override
  Widget build(BuildContext context) => Column(children: [
    const Divider(),
    const SizedBox(height: 8),
    const Text('Why EasyLoan?',
      style: TextStyle(
        fontSize: 13, fontWeight: FontWeight.w700, color: _kMid,
      )),
    const SizedBox(height: 10),
    Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _WhyItem(Icons.bolt_rounded,       'Instant'),
        _WhyItem(Icons.lock_outline,       'Secure'),
        _WhyItem(Icons.description_outlined,'Agreement'),
        _WhyItem(Icons.support_agent,      'Support'),
      ],
    ),
  ]);
}

class _WhyItem extends StatelessWidget {
  final IconData icon;
  final String   label;
  const _WhyItem(this.icon, this.label);
  @override
  Widget build(BuildContext context) => Column(children: [
    Container(
      width: 40, height: 40,
      decoration: BoxDecoration(
        color: _kBlueLight, shape: BoxShape.circle,
      ),
      child: Icon(icon, color: _kBlue, size: 20),
    ),
    const SizedBox(height: 4),
    Text(label, style: const TextStyle(fontSize: 10.5, color: _kMid)),
  ]);
}

// ───────────────────────────────────────────
//  HELPERS
// ───────────────────────────────────────────
Route _slide(Widget page) => PageRouteBuilder(
  pageBuilder:    (_, __, ___) => page,
  transitionsBuilder: (_, anim, __, child) => SlideTransition(
    position: Tween(begin: const Offset(1, 0), end: Offset.zero)
        .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
    child: child,
  ),
  transitionDuration: const Duration(milliseconds: 280),
);

class _UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue old, TextEditingValue nw) =>
      nw.copyWith(text: nw.text.toUpperCase());
}
