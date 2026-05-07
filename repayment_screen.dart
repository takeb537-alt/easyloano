import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import '../providers/loan_provider.dart';
import '../widgets/swipe_to_pay.dart';
import 'home_screen.dart';

class RepaymentScreen extends StatefulWidget {
  final LoanModel loan;
  const RepaymentScreen({super.key, required this.loan});

  @override
  State<RepaymentScreen> createState() => _RepaymentScreenState();
}

class _RepaymentScreenState extends State<RepaymentScreen> {
  final _partialController = TextEditingController();
  bool _showPartial = false;
  bool _isPaying = false;
  String? _partialError;

  LoanModel get _loan => widget.loan;
  bool get _isOverdue => _loan.status == LoanStatus.overdue;

  double get _penalty =>
      _isOverdue ? PenaltyCalculator.calculate(_loan.amount) : 0;
  double get _totalDue => _loan.amount + _loan.fee + _penalty - _loan.amountPaid;

  @override
  void dispose() {
    _partialController.dispose();
    super.dispose();
  }

  Future<void> _handleFullPayment() async {
    setState(() => _isPaying = true);
    HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 800));

    final completed =
        await context.read<LoanProvider>().makePayment(_loan.id, _totalDue);

    if (mounted) {
      _showSuccessDialog(completed: completed, amount: _totalDue);
    }
    setState(() => _isPaying = false);
  }

  Future<void> _handlePartialPayment() async {
    final text = _partialController.text.trim();
    final amount = double.tryParse(text);
    if (amount == null || amount < 10) {
      setState(() => _partialError = 'Minimum partial payment is ₹10');
      return;
    }
    if (amount > _totalDue) {
      setState(() =>
          _partialError = 'Cannot pay more than total due (₹${_totalDue.toStringAsFixed(0)})');
      return;
    }
    setState(() {
      _partialError = null;
      _isPaying = true;
    });
    HapticFeedback.mediumImpact();

    final completed =
        await context.read<LoanProvider>().makePayment(_loan.id, amount);

    if (mounted) {
      _showSuccessDialog(completed: completed, amount: amount);
    }
    setState(() => _isPaying = false);
  }

  void _showSuccessDialog(
      {required bool completed, required double amount}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Icon(
              completed ? Icons.check_circle : Icons.payment,
              color: completed ? Colors.green : const Color(0xFF1565C0),
              size: 72,
            ),
            const SizedBox(height: 16),
            Text(
              completed ? 'Payment Complete!' : 'Payment Received',
              style: const TextStyle(
                  fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              completed
                  ? '₹${amount.toStringAsFixed(0)} paid. Loan closed. 🎉'
                  : '₹${amount.toStringAsFixed(0)} received. Balance remaining.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              if (completed) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const HomeScreen()),
                  (r) => false,
                );
              } else {
                Navigator.pop(context);
              }
            },
            child: const Text('OK',
                style: TextStyle(
                    color: Color(0xFF1565C0),
                    fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _openPdf() async {
    if (_loan.pdfPath != null) {
      await OpenFile.open(_loan.pdfPath!);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PDF not available')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final loan = context.watch<LoanProvider>().loans.firstWhere(
          (l) => l.id == _loan.id,
          orElse: () => _loan,
        );
    final daysLeft = loan.dueDate.difference(DateTime.now()).inDays;
    final dateFmt = DateFormat('dd MMM yyyy');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Loan Repayment'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'View Agreement',
            onPressed: _openPdf,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status banner
            if (_isOverdue)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEBEE),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning, color: Colors.red),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'OVERDUE! Penalty of ₹${_penalty.toInt()} has been added.',
                        style: const TextStyle(
                            color: Colors.red, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),

            // Due amount hero
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _isOverdue
                      ? [const Color(0xFFC62828), const Color(0xFFE53935)]
                      : [const Color(0xFF0D47A1), const Color(0xFF1976D2)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  const Text('Total Amount Due',
                      style: TextStyle(color: Colors.white70, fontSize: 14)),
                  const SizedBox(height: 8),
                  Text(
                    '₹${_totalDue.toStringAsFixed(0)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 44,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _InfoChip(
                          label: 'Due Date',
                          value: dateFmt.format(loan.dueDate)),
                      _InfoChip(
                          label: _isOverdue ? 'Days Late' : 'Days Left',
                          value: _isOverdue
                              ? '${daysLeft.abs()} days'
                              : '$daysLeft days'),
                      _InfoChip(
                          label: 'Loan ID',
                          value: loan.id),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Breakdown
            _SummaryRow('Principal', '₹${loan.amount.toInt()}'),
            _SummaryRow('Processing Fee', '₹${loan.fee.toInt()}'),
            if (_isOverdue)
              _SummaryRow('Penalty (One-Time)',
                  '₹${_penalty.toInt()}',
                  isRed: true),
            if (loan.amountPaid > 0)
              _SummaryRow('Amount Paid',
                  '-₹${loan.amountPaid.toStringAsFixed(0)}',
                  isGreen: true),
            const Divider(height: 24),
            _SummaryRow('Total Due',
                '₹${_totalDue.toStringAsFixed(0)}',
                isBold: true),
            const SizedBox(height: 28),

            // Swipe to pay
            const Text('Full Payment',
                style:
                    TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            if (_isPaying)
              const Center(child: CircularProgressIndicator())
            else
              SwipeToPayWidget(
                amount: _totalDue,
                onPaymentComplete: _handleFullPayment,
              ),
            const SizedBox(height: 24),

            // Partial payment toggle
            GestureDetector(
              onTap: () =>
                  setState(() => _showPartial = !_showPartial),
              child: Row(
                children: [
                  const Text('Partial Payment',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  Icon(
                    _showPartial
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: const Color(0xFF1565C0),
                  ),
                ],
              ),
            ),

            if (_showPartial) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _partialController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Enter amount (min ₹10)',
                  prefixText: '₹ ',
                  errorText: _partialError,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                        color: Color(0xFF1565C0), width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isPaying ? null : _handlePartialPayment,
                  icon: const Icon(Icons.payment),
                  label: const Text('Pay Partial Amount'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    backgroundColor: const Color(0xFF1565C0),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),

            // View PDF
            OutlinedButton.icon(
              onPressed: _openPdf,
              icon: const Icon(Icons.picture_as_pdf),
              label: const Text('View Loan Agreement PDF'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                side: const BorderSide(color: Color(0xFF1565C0)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label, value;
  const _InfoChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label,
            style: const TextStyle(color: Colors.white70, fontSize: 11)),
        const SizedBox(height: 2),
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12)),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label, value;
  final bool isBold, isRed, isGreen;
  const _SummaryRow(this.label, this.value,
      {this.isBold = false, this.isRed = false, this.isGreen = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  color: Colors.grey[700],
                  fontSize: 14,
                  fontWeight:
                      isBold ? FontWeight.bold : FontWeight.normal)),
          Text(value,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight:
                      isBold ? FontWeight.bold : FontWeight.w500,
                  color: isRed
                      ? Colors.red
                      : isGreen
                          ? Colors.green
                          : isBold
                              ? const Color(0xFF1565C0)
                              : Colors.black87)),
        ],
      ),
    );
  }
}
