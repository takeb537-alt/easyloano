import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class LoanAmountGrid extends StatelessWidget {
  final int onTimePayments;
  final Function(double) onAmountSelected;

  const LoanAmountGrid({
    super.key,
    required this.onTimePayments,
    required this.onAmountSelected,
  });

  static const List<double> amounts = [
    100, 200, 300, 400, 500, 600, 700, 800, 900, 1000, 1500, 2000
  ];

  bool _isUnlocked(double amount) {
    if (amount <= 200) return true;
    if (amount <= 1000 && onTimePayments >= 3) return true;
    if (amount <= 2000 && onTimePayments >= 6) return true;
    return false;
  }

  String _unlockHint(double amount) {
    if (amount <= 1000) return '${3 - onTimePayments} more on-time payments';
    return '${6 - onTimePayments} more on-time payments';
  }

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 1.3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: amounts.length,
      itemBuilder: (context, index) {
        final amount = amounts[index];
        final unlocked = _isUnlocked(amount);
        return _AmountCard(
          amount: amount,
          isUnlocked: unlocked,
          unlockHint: unlocked ? null : _unlockHint(amount),
          onTap: unlocked
              ? () {
                  HapticFeedback.lightImpact();
                  onAmountSelected(amount);
                }
              : null,
        );
      },
    );
  }
}

class _AmountCard extends StatelessWidget {
  final double amount;
  final bool isUnlocked;
  final String? unlockHint;
  final VoidCallback? onTap;

  const _AmountCard({
    required this.amount,
    required this.isUnlocked,
    this.unlockHint,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: isUnlocked
              ? const LinearGradient(
                  colors: [Color(0xFF1565C0), Color(0xFF1976D2)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isUnlocked ? null : const Color(0xFFF5F5F5),
          border: isUnlocked
              ? null
              : Border.all(color: const Color(0xFFE0E0E0)),
          boxShadow: isUnlocked
              ? [
                  BoxShadow(
                    color: const Color(0xFF1565C0).withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  )
                ]
              : null,
        ),
        child: isUnlocked
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '₹${amount.toInt()}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Tap to apply',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 10,
                    ),
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.lock_outline,
                      color: Color(0xFF9E9E9E), size: 18),
                  const SizedBox(height: 4),
                  Text(
                    '₹${amount.toInt()}',
                    style: const TextStyle(
                      color: Color(0xFF9E9E9E),
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      unlockHint ?? 'Coming Soon',
                      style: const TextStyle(
                        color: Color(0xFFBDBDBD),
                        fontSize: 8,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
