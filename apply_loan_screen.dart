import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/loan_provider.dart';
import '../utils/pdf_service.dart';
import 'repayment_screen.dart';

class ApplyLoanScreen extends StatefulWidget {
  final double amount;
  const ApplyLoanScreen({super.key, required this.amount});

  @override
  State<ApplyLoanScreen> createState() => _ApplyLoanScreenState();
}

class _ApplyLoanScreenState extends State<ApplyLoanScreen> {
  bool _agreed = false;
  bool _isApplying = false;
  static const double _fee = 100;

  double get _total => widget.amount + _fee;
  DateTime get _dueDate =>
      DateTime.now().add(const Duration(days: 15));

  Future<void> _applyLoan() async {
    if (!_agreed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please agree to the terms & conditions'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    setState(() => _isApplying = true);
    HapticFeedback.mediumImpact();

    try {
      final provider = context.read<LoanProvider>();
      final loan = await provider.applyLoan(widget.amount);

      // Generate PDF
      final pdfPath = await PdfService.generateLoanAgreement(
        user: provider.user!,
        loan: loan,
      );
      await provider.updateLoanPdf(loan.id, pdfPath);

      HapticFeedback.heavyImpact();

      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
              builder: (_) => RepaymentScreen(loan: loan)),
          (route) => route.isFirst,
        );
      }
    } catch (e) {
      setState(() => _isApplying = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('dd MMM yyyy');
    return Scaffold(
      appBar: AppBar(title: const Text('Apply for Loan'), centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Amount hero card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0D47A1), Color(0xFF1976D2)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  const Text('Loan Amount',
                      style:
                          TextStyle(color: Colors.white70, fontSize: 14)),
                  const SizedBox(height: 8),
                  Text(
                    '₹${widget.amount.toInt()}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Due: ${dateFmt.format(_dueDate)}',
                      style: const TextStyle(
                          color: Colors.white, fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Breakdown
            const Text('Payment Breakdown',
                style:
                    TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _BreakdownCard(
              rows: [
                _Row('Principal Amount', '₹${widget.amount.toInt()}',
                    isTotal: false),
                _Row('Processing Fee', '₹${_fee.toInt()}',
                    isTotal: false),
                _Row(
                  'Total Repayable',
                  '₹${_total.toInt()}',
                  isTotal: true,
                ),
                _Row('Due Date', dateFmt.format(_dueDate),
                    isTotal: false),
                _Row('Tenure', '15 Days', isTotal: false),
              ],
            ),
            const SizedBox(height: 24),

            // Penalty warning
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3E0),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: Colors.orange, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Late payment penalty: ₹${PenaltyCalculator.calculate(widget.amount).toInt()} will be added if not paid by due date.',
                      style: const TextStyle(
                          color: Color(0xFFE65100), fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Terms
            const Text('Terms & Conditions',
                style:
                    TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            _TermsBox(),
            const SizedBox(height: 16),

            // Agree checkbox
            Row(
              children: [
                Checkbox(
                  value: _agreed,
                  onChanged: (v) =>
                      setState(() => _agreed = v ?? false),
                  activeColor: const Color(0xFF1565C0),
                ),
                const Expanded(
                  child: Text(
                    'I have read and agree to all terms, conditions, and penalty schedule.',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Apply button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isApplying ? null : _applyLoan,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: _isApplying
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2),
                          ),
                          SizedBox(width: 12),
                          Text('Generating Agreement...'),
                        ],
                      )
                    : const Text('Apply Now 🚀',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _BreakdownCard extends StatelessWidget {
  final List<_Row> rows;
  const _BreakdownCard({required this.rows});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE0E0E0)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: rows.asMap().entries.map((e) {
          final isLast = e.key == rows.length - 1;
          final row = e.value;
          return Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color:
                  row.isTotal ? const Color(0xFFE3F2FD) : Colors.white,
              borderRadius: BorderRadius.only(
                bottomLeft: isLast ? const Radius.circular(14) : Radius.zero,
                bottomRight:
                    isLast ? const Radius.circular(14) : Radius.zero,
                topLeft: e.key == 0 ? const Radius.circular(14) : Radius.zero,
                topRight:
                    e.key == 0 ? const Radius.circular(14) : Radius.zero,
              ),
              border: e.key < rows.length - 1
                  ? const Border(
                      bottom: BorderSide(color: Color(0xFFEEEEEE)))
                  : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(row.label,
                    style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: 14,
                        fontWeight: row.isTotal
                            ? FontWeight.bold
                            : FontWeight.normal)),
                Text(row.value,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: row.isTotal
                          ? FontWeight.bold
                          : FontWeight.w500,
                      color: row.isTotal
                          ? const Color(0xFF1565C0)
                          : Colors.black87,
                    )),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _Row {
  final String label, value;
  final bool isTotal;
  _Row(this.label, this.value, {required this.isTotal});
}

class _TermsBox extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 150,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: const SingleChildScrollView(
        child: Text(
          '1. Loan amount will be credited to your registered UPI ID within 24 hours.\n\n'
          '2. Repayment must be made within 15 days of loan disbursement.\n\n'
          '3. A one-time processing fee of ₹100 is applicable.\n\n'
          '4. Failure to repay by the due date will attract a one-time penalty as per the penalty schedule.\n\n'
          '5. On-time repayment increases your credit limit progressively.\n\n'
          '6. Partial payments are accepted. Balance must be cleared including any applicable penalty.\n\n'
          '7. This loan agreement is binding under the Indian Contract Act, 1872.\n\n'
          '8. EasyLoan reserves the right to initiate legal proceedings for non-repayment.',
          style: TextStyle(fontSize: 12, color: Colors.black87, height: 1.5),
        ),
      ),
    );
  }
}
