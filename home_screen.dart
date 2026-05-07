import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/loan_provider.dart';
import '../widgets/loan_amount_grid.dart';
import 'apply_loan_screen.dart';
import 'repayment_screen.dart';
import 'my_loans_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _navIndex = 0;

  @override
  Widget build(BuildContext context) {
    final screens = [
      const _HomeTab(),
      const MyLoansScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      body: IndexedStack(index: _navIndex, children: screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _navIndex,
        onDestinationSelected: (i) => setState(() => _navIndex = i),
        backgroundColor: Colors.white,
        indicatorColor: const Color(0xFFBBDEFB),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home',
              selectedIcon: Icon(Icons.home, color: Color(0xFF1565C0))),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined),
              label: 'My Loans',
              selectedIcon: Icon(Icons.receipt_long, color: Color(0xFF1565C0))),
          NavigationDestination(icon: Icon(Icons.person_outline),
              label: 'Profile',
              selectedIcon: Icon(Icons.person, color: Color(0xFF1565C0))),
        ],
      ),
    );
  }
}

class _HomeTab extends StatelessWidget {
  const _HomeTab();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LoanProvider>();
    final user = provider.user;
    final activeLoan = provider.activeLoan;

    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          // ── App Bar ──
          SliverAppBar(
            expandedHeight: 180,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF0D47A1), Color(0xFF1976D2)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _greeting(),
                                  style: const TextStyle(
                                      color: Colors.white70, fontSize: 14),
                                ),
                                Text(
                                  user?.fullName.split(' ').first ?? 'User',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            // Credit limit badge
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Column(
                                children: [
                                  const Text('Credit Limit',
                                      style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: 11)),
                                  Text(
                                    '₹${provider.maxUnlockedAmount.toInt()}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // On-time payments badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.star,
                                  color: Colors.amber, size: 16),
                              const SizedBox(width: 6),
                              Text(
                                '${provider.onTimePayments} On-Time Payments',
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Active loan banner
                  if (activeLoan != null) ...[
                    _ActiveLoanBanner(loan: activeLoan),
                    const SizedBox(height: 24),
                  ],

                  // Loan amount heading
                  const Text(
                    'Select Loan Amount',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    activeLoan != null
                        ? 'Repay active loan to apply new'
                        : 'Tap an amount to apply instantly',
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                  const SizedBox(height: 16),

                  // Grid
                  AbsorbPointer(
                    absorbing: activeLoan != null,
                    child: Opacity(
                      opacity: activeLoan != null ? 0.4 : 1.0,
                      child: LoanAmountGrid(
                        onTimePayments: provider.onTimePayments,
                        onAmountSelected: (amount) {
                          HapticFeedback.mediumImpact();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  ApplyLoanScreen(amount: amount),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Recharge section
                  _RechargeSection(),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good Morning,';
    if (h < 17) return 'Good Afternoon,';
    return 'Good Evening,';
  }
}

class _ActiveLoanBanner extends StatelessWidget {
  final LoanModel loan;
  const _ActiveLoanBanner({required this.loan});

  @override
  Widget build(BuildContext context) {
    final daysLeft = loan.dueDate.difference(DateTime.now()).inDays;
    final isOverdue = daysLeft < 0;
    return GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => RepaymentScreen(loan: loan))),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: isOverdue
                ? [const Color(0xFFC62828), const Color(0xFFE53935)]
                : [const Color(0xFF1B5E20), const Color(0xFF2E7D32)],
          ),
          boxShadow: [
            BoxShadow(
              color: (isOverdue ? Colors.red : Colors.green).withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isOverdue ? '⚠️ Loan Overdue!' : '📋 Active Loan',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    isOverdue
                        ? '${daysLeft.abs()} days late'
                        : '$daysLeft days left',
                    style: const TextStyle(
                        color: Colors.white, fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '₹${loan.totalDue.toStringAsFixed(0)} due',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Due: ${DateFormat('dd MMM yyyy').format(loan.dueDate)}',
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 12),
            Container(
              padding:
                  const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.touch_app, color: Colors.white, size: 16),
                  SizedBox(width: 6),
                  Text('Tap to Repay',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RechargeSection extends StatelessWidget {
  final List<Map<String, dynamic>> _plans = [
    {'pay': 19, 'get': 25, 'tenure': 10},
    {'pay': 39, 'get': 50, 'tenure': 10},
    {'pay': 99, 'get': 140, 'tenure': 10},
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '🔥 Recharge & Earn More',
          style: TextStyle(
              fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        const SizedBox(height: 6),
        const Text(
          '10-day flexible tenure on recharge loans',
          style: TextStyle(color: Colors.grey, fontSize: 13),
        ),
        const SizedBox(height: 14),
        Row(
          children: _plans.map((plan) {
            return Expanded(
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(
                            'Recharge ₹${plan['pay']} → Get ₹${plan['get']}'),
                        duration: const Duration(seconds: 2)),
                  );
                },
                child: Container(
                  margin: const EdgeInsets.only(right: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: const LinearGradient(
                      colors: [Color(0xFFE65100), Color(0xFFFF6D00)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.orange.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  child: Column(
                    children: [
                      Text('₹${plan['pay']}',
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 11)),
                      const Icon(Icons.arrow_downward,
                          color: Colors.white, size: 16),
                      Text('₹${plan['get']}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      const Text('10 days',
                          style: TextStyle(
                              color: Colors.white70, fontSize: 10)),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
