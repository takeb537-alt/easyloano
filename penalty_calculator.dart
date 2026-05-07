// ============================================
// EasyLoan - PenaltyCalculator
// Calculates penalty based on loan amount
// One-time penalty on day 16, not compound
// ============================================

class PenaltyCalculator {
  /// Returns the one-time penalty amount for a given loan amount.
  /// Penalty is applied only once on day 16 (not daily compound).
  ///
  /// Tiers:
  /// ₹100           → ₹50 penalty
  /// ₹200 – ₹500    → ₹100 penalty
  /// ₹600 – ₹1000   → ₹200 penalty
  /// ₹1100 – ₹1500  → ₹250 penalty
  /// ₹1600 – ₹2000  → ₹300 penalty
  static double calculatePenalty(double loanAmount) {
    if (loanAmount <= 100) return 50.0;
    if (loanAmount <= 500) return 100.0;
    if (loanAmount <= 1000) return 200.0;
    if (loanAmount <= 1500) return 250.0;
    return 300.0; // ₹1600 – ₹2000
  }

  /// Returns the total amount due including penalty.
  static double totalDueWithPenalty({
    required double loanAmount,
    required double returnAmount,
    required double paidAmount,
  }) {
    final penalty = calculatePenalty(loanAmount);
    final remaining = returnAmount - paidAmount;
    return remaining + penalty;
  }

  /// Returns the remaining balance after partial payment.
  static double remainingBalance({
    required double returnAmount,
    required double paidAmount,
    required double penalty,
  }) {
    return (returnAmount + penalty - paidAmount).clamp(0, double.infinity);
  }

  /// Checks whether penalty should be applied.
  /// Penalty applies if: loan is not fully paid AND today >= due date + 1 day
  static bool shouldApplyPenalty({
    required DateTime dueDate,
    required double paidAmount,
    required double returnAmount,
    required bool penaltyAlreadyApplied,
  }) {
    if (penaltyAlreadyApplied) return false;
    if (paidAmount >= returnAmount) return false;
    final penaltyDate = dueDate.add(const Duration(days: 1));
    return DateTime.now().isAfter(penaltyDate);
  }

  /// Returns human-readable penalty info string.
  static String penaltyInfo(double loanAmount) {
    final penalty = calculatePenalty(loanAmount);
    return 'Late penalty: ₹${penalty.toInt()} (applied after due date)';
  }

  /// Returns a description of penalty tier.
  static String penaltyTierDescription(double loanAmount) {
    if (loanAmount <= 100) return '₹50 late fee applies after due date';
    if (loanAmount <= 500) return '₹100 late fee applies after due date';
    if (loanAmount <= 1000) return '₹200 late fee applies after due date';
    if (loanAmount <= 1500) return '₹250 late fee applies after due date';
    return '₹300 late fee applies after due date';
  }
}