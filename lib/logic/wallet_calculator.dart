import '../core/date_x.dart';
import '../models/budget.dart';
import '../models/expense.dart';

enum BudgetPhase {
  /// Today is before startDate — allowance has not started flowing yet.
  upcoming,

  /// Today is inside [startDate, endDate].
  running,

  /// Today is after endDate (PRD Rule 4).
  finished,
}

/// Everything the UI needs for one point in time. Immutable, derived.
class WalletSnapshot {
  const WalletSnapshot({
    required this.phase,
    required this.totalDays,
    required this.currentDay,
    required this.dailyAllowance,
    required this.walletToday,
    required this.expenseToday,
    required this.walletRemaining,
    required this.carryOver,
    required this.totalExpense,
    required this.budgetAmount,
    required this.budgetRemaining,
    required this.progress,
    required this.tomorrowWallet,
  });

  final BudgetPhase phase;
  final int totalDays;

  /// 1-based. 0 while [phase] is upcoming.
  final int currentDay;
  final double dailyAllowance;

  /// Allowance for today plus whatever was carried over from yesterday.
  final double walletToday;
  final double expenseToday;

  /// walletToday - expenseToday. May be negative (PRD Rule 3).
  final double walletRemaining;

  /// walletToday - dailyAllowance. Negative when yesterday overspent.
  final double carryOver;
  final double totalExpense;
  final double budgetAmount;
  final double budgetRemaining;

  /// 0.0 .. 1.0 of the budget already spent.
  final double progress;

  /// null on the last day of the period — no tomorrow to fund.
  final double? tomorrowWallet;

  bool get isOverspentToday => walletRemaining < 0;
  bool get savedToday => walletRemaining > 0;
  int get daysLeft => (totalDays - currentDay).clamp(0, totalDays);
}

/// Pure, dependency-free wallet math. No Firebase, no clock, no widgets — the
/// caller passes `now` so every case is directly testable.
///
/// Model (PRD §10): the wallet is *cumulative allowance minus everything spent
/// on earlier days*. Deriving it from the expense log instead of incrementing a
/// stored counter means a late edit to Tuesday's receipt automatically corrects
/// today's wallet, and a missed midnight rollover can never lose a day.
///
///   walletToday    = dailyAllowance * currentDay - spentBeforeToday
///   walletRemaining = walletToday - expenseToday
///   carryOver      = walletToday - dailyAllowance
class WalletCalculator {
  const WalletCalculator();

  WalletSnapshot compute({
    required Budget budget,
    required List<Expense> expenses,
    required DateTime now,
  }) {
    final today = DateX.dayOnly(now);
    final totalDays = budget.totalDays;
    final allowance = budget.dailyAllowance;

    final phase = _phaseFor(budget, today);

    // Day 1 == startDate. Clamped so a finished budget still reports its last
    // day rather than running past the period.
    final rawDay = DateX.daysBetween(budget.startDate, today) + 1;
    final currentDay = switch (phase) {
      BudgetPhase.upcoming => 0,
      BudgetPhase.running => rawDay,
      BudgetPhase.finished => totalDays,
    };

    // The reference day for wallet math: for a finished budget the wallet is
    // frozen at the last day of the period.
    final effectiveDay = phase == BudgetPhase.upcoming ? 0 : currentDay;
    final referenceDate = phase == BudgetPhase.finished ? budget.endDate : today;

    var spentBeforeReference = 0.0;
    var expenseOnReference = 0.0;
    var totalExpense = 0.0;

    for (final expense in expenses) {
      totalExpense += expense.amount;
      final diff = DateX.daysBetween(expense.date, referenceDate);
      if (diff > 0) {
        spentBeforeReference += expense.amount;
      } else if (diff == 0) {
        expenseOnReference += expense.amount;
      }
      // diff < 0 => dated after the reference day (a future-dated entry); it
      // counts against the total budget but not against today's wallet.
    }

    final walletToday =
        effectiveDay == 0 ? 0.0 : allowance * effectiveDay - spentBeforeReference;
    final expenseToday = effectiveDay == 0 ? 0.0 : expenseOnReference;
    final walletRemaining = walletToday - expenseToday;
    final carryOver = effectiveDay == 0 ? 0.0 : walletToday - allowance;

    final budgetRemaining = budget.amount - totalExpense;
    final progress = budget.amount <= 0
        ? 0.0
        : (totalExpense / budget.amount).clamp(0.0, 1.0).toDouble();

    final hasTomorrow = phase == BudgetPhase.running && currentDay < totalDays;
    final tomorrowWallet = hasTomorrow ? walletRemaining + allowance : null;

    return WalletSnapshot(
      phase: phase,
      totalDays: totalDays,
      currentDay: currentDay,
      dailyAllowance: allowance,
      walletToday: walletToday,
      expenseToday: expenseToday,
      walletRemaining: walletRemaining,
      carryOver: carryOver,
      totalExpense: totalExpense,
      budgetAmount: budget.amount,
      budgetRemaining: budgetRemaining,
      progress: progress,
      tomorrowWallet: tomorrowWallet,
    );
  }

  BudgetPhase _phaseFor(Budget budget, DateTime today) {
    if (DateX.daysBetween(today, budget.startDate) > 0) {
      return BudgetPhase.upcoming;
    }
    if (DateX.daysBetween(budget.endDate, today) > 0) {
      return BudgetPhase.finished;
    }
    return BudgetPhase.running;
  }
}

/// Human-readable daily insight (PRD §8 "Daily Insight").
String buildInsight(WalletSnapshot s) {
  switch (s.phase) {
    case BudgetPhase.upcoming:
      return 'Budget kamu belum dimulai. Jatah harian nanti '
          '${_rp(s.dailyAllowance)}.';
    case BudgetPhase.finished:
      if (s.budgetRemaining >= 0) {
        return 'Periode selesai. Kamu berhasil menyisakan '
            '${_rp(s.budgetRemaining)}.';
      }
      return 'Periode selesai. Kamu melebihi budget sebesar '
          '${_rp(s.budgetRemaining.abs())}.';
    case BudgetPhase.running:
      if (s.isOverspentToday) {
        final over = _rp(s.walletRemaining.abs());
        if (s.tomorrowWallet != null) {
          return 'Hari ini kamu melebihi wallet sebesar $over. '
              'Wallet besok menjadi ${_rp(s.tomorrowWallet!)}.';
        }
        return 'Hari ini kamu melebihi wallet sebesar $over.';
      }
      if (s.expenseToday == 0) {
        return 'Hari ini kamu punya ${_rp(s.walletToday)} untuk dipakai. '
            'Belum ada pengeluaran.';
      }
      final left = 'Hari ini kamu masih memiliki ${_rp(s.walletRemaining)}.';
      if (s.tomorrowWallet != null) {
        return '$left Wallet besok menjadi ${_rp(s.tomorrowWallet!)}.';
      }
      return left;
  }
}

// Local copy to keep this file free of the intl dependency chain.
String _rp(num value) {
  final digits = value.round().abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write('.');
    buffer.write(digits[i]);
  }
  return '${value < 0 ? '-' : ''}Rp$buffer';
}
