import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/loan_provider.dart';
import 'repayment_screen.dart';

class MyLoansScreen extends StatelessWidget {
  const MyLoansScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final loans = context.watch<LoanProvider>().loans.reversed.toList();

    return Scaffold(
      appBar: AppBar(title: const Text('My Loans'), centerTitle: true),
      body: loans.isEmpty
          ? _EmptyState()
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: loans.length,
              itemBuilder: (context, i) => _LoanCard(loan: loans[i]),
            ),
    );
  }
}

class _LoanCard extends StatelessWidget {
  final LoanModel loan;
  const _LoanCard({required this.loan});

  Color get _statusColor {
    switch (loan.status) {
      case LoanStatus.active:
        return const Color(0xFF1565C0);
      case LoanStatus.completed:
        return const Color(0xFF2E7D32);
      case LoanStatus.overdue:
        return const Color(0xFFC62828);
    }
  }

  String get _statusLabel {
    switch (loan.status) {
      case LoanStatus.active:
        return 'ACTIVE';
      case LoanStatus.completed:
        return 'COMPLETED';
      case LoanStatus.overdue:
        return 'OVERDUE';
    }
  }

  IconData get _statusIcon {
    switch (loan.status) {
      case LoanStatus.active:
        return Icons.pending_actions;
      case LoanStatus.completed:
        return Icons.check_circle;
      case LoanStatus.overdue:
        return Icons.warning;
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('dd MMM yyyy');
    return GestureDetector(
      onTap: loan.status != LoanStatus.completed
          ? () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => RepaymentScreen(loan: loan)),
              )
          : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.white,
          border: Border.all(color: _statusColor.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 3),
            )
          ],
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: _statusColor.withOpacity(0.08),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Loan ID: ${loan.id}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _statusColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_statusIcon, color: Colors.white, size: 14),
                        const SizedBox(width: 4),
                        Text(_statusLabel,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Body
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _InfoTile(
                            label: 'Amount',
                            value: '₹${loan.amount.toInt()}'),
                      ),
                      Expanded(
                        child: _InfoTile(
                            label: 'Total Due',
                            value:
                                '₹${loan.principalDue.toStringAsFixed(0)}'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _InfoTile(
                            label: 'Due Date',
                            value: dateFmt.format(loan.dueDate)),
                      ),
                      Expanded(
                        child: _InfoTile(
                            label: 'Paid',
                            value:
                                '₹${loan.amountPaid.toStringAsFixed(0)}',
                            valueColor: const Color(0xFF2E7D32)),
                      ),
                    ],
                  ),
                  if (loan.status != LoanStatus.completed) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  RepaymentScreen(loan: loan)),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _statusColor,
                          padding:
                              const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('Pay Now',
                            style: TextStyle(color: Colors.white)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final String label, value;
  final Color? valueColor;
  const _InfoTile(
      {required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style:
                TextStyle(color: Colors.grey[500], fontSize: 11)),
        const SizedBox(height: 2),
        Text(value,
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: valueColor ?? Colors.black87)),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long_outlined, size: 80, color: Colors.grey),
          SizedBox(height: 16),
          Text('No loans yet',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey)),
          SizedBox(height: 8),
          Text('Apply for your first loan from Home tab',
              style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}
