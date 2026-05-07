import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/loan_provider.dart';
import 'splash_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LoanProvider>();
    final user = provider.user;
    final loans = provider.loans;
    final totalLoans = loans.length;
    final completedLoans =
        loans.where((l) => l.status == LoanStatus.completed).length;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile'), centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar + name
            Center(
              child: Column(
                children: [
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1565C0), Color(0xFF42A5F5)],
                      ),
                    ),
                    child: Center(
                      child: Text(
                        user?.fullName.isNotEmpty == true
                            ? user!.fullName[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 40,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    user?.fullName ?? '',
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '+91 ${user?.mobile ?? ''}',
                    style: const TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // User details card
            _SectionCard(
              title: 'Personal Details',
              icon: Icons.person_outline,
              children: [
                _DetailRow('Full Name', user?.fullName ?? '-'),
                _DetailRow('Mobile', '+91 ${user?.mobile ?? '-'}'),
                _DetailRow('PAN Card', user?.pan ?? '-'),
                _DetailRow('Date of Birth', user?.dob ?? '-'),
                _DetailRow('UPI ID', user?.upiId ?? '-'),
              ],
            ),
            const SizedBox(height: 16),

            // Loan stats
            _SectionCard(
              title: 'Loan Statistics',
              icon: Icons.bar_chart,
              children: [
                _StatRow('Total Loans Applied', '$totalLoans'),
                _StatRow('Completed Loans', '$completedLoans'),
                _StatRow(
                    'On-Time Payments', '${provider.onTimePayments}'),
                _StatRow('Max Credit Unlocked',
                    '₹${provider.maxUnlockedAmount.toInt()}'),
              ],
            ),
            const SizedBox(height: 16),

            // Unlock progress
            _SectionCard(
              title: 'Credit Unlock Progress',
              icon: Icons.lock_open,
              children: [
                _UnlockProgress(
                  label: '₹100 – ₹200',
                  status: 'Unlocked ✅',
                  isUnlocked: true,
                ),
                _UnlockProgress(
                  label: '₹300 – ₹1000',
                  status: provider.onTimePayments >= 3
                      ? 'Unlocked ✅'
                      : '${3 - provider.onTimePayments} more on-time payments',
                  isUnlocked: provider.onTimePayments >= 3,
                ),
                _UnlockProgress(
                  label: '₹1500 – ₹2000',
                  status: provider.onTimePayments >= 6
                      ? 'Unlocked ✅'
                      : '${6 - provider.onTimePayments} more on-time payments',
                  isUnlocked: provider.onTimePayments >= 6,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Penalty schedule
            _SectionCard(
              title: 'Penalty Schedule',
              icon: Icons.warning_amber_rounded,
              children: [
                _PenaltyHeader(),
                ...PenaltyCalculator.schedule.map((row) => _PenaltyRow(
                    range: row['range']!, penalty: row['penalty']!)),
              ],
            ),
            const SizedBox(height: 28),

            // Logout
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _confirmLogout(context, provider),
                icon: const Icon(Icons.logout, color: Colors.red),
                label: const Text('Logout / Reset Account',
                    style: TextStyle(color: Colors.red)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: const BorderSide(color: Colors.red),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  void _confirmLogout(BuildContext context, LoanProvider provider) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Reset Account?'),
        content: const Text(
            'This will delete all your data. Are you sure?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await provider.logout();
              if (context.mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const SplashScreen()),
                  (r) => false,
                );
              }
            },
            child: const Text('Reset',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;
  const _SectionCard(
      {required this.title,
      required this.icon,
      required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0E0E0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding:
                const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Row(
              children: [
                Icon(icon, color: const Color(0xFF1565C0), size: 20),
                const SizedBox(width: 8),
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Color(0xFF1565C0))),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label, value;
  const _DetailRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(
              width: 120,
              child: Text(label,
                  style: TextStyle(
                      color: Colors.grey[600], fontSize: 13))),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontWeight: FontWeight.w500, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label, value;
  const _StatRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style:
                  TextStyle(color: Colors.grey[700], fontSize: 13)),
          Text(value,
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1565C0))),
        ],
      ),
    );
  }
}

class _UnlockProgress extends StatelessWidget {
  final String label, status;
  final bool isUnlocked;
  const _UnlockProgress(
      {required this.label,
      required this.status,
      required this.isUnlocked});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(
            isUnlocked ? Icons.lock_open : Icons.lock_outline,
            color:
                isUnlocked ? const Color(0xFF2E7D32) : Colors.grey,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontWeight: FontWeight.w500, fontSize: 13)),
                Text(status,
                    style: TextStyle(
                        fontSize: 11,
                        color: isUnlocked
                            ? const Color(0xFF2E7D32)
                            : Colors.orange[700])),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PenaltyHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF1565C0),
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Row(
        children: [
          Expanded(
              child: Text('Loan Range',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12))),
          Text('Penalty',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12)),
        ],
      ),
    );
  }
}

class _PenaltyRow extends StatelessWidget {
  final String range, penalty;
  const _PenaltyRow({required this.range, required this.penalty});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
              child: Text(range,
                  style: const TextStyle(fontSize: 13))),
          Text(penalty,
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                  fontSize: 13)),
        ],
      ),
    );
  }
}
