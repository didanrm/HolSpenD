import 'package:flutter_test/flutter_test.dart';
import 'package:holspend/logic/wallet_calculator.dart';
import 'package:holspend/models/budget.dart';
import 'package:holspend/models/expense.dart';

Budget prdBudget() => Budget(
      id: 'b1',
      name: 'Agustus',
      amount: 1400000,
      startDate: DateTime(2025, 8, 5),
      endDate: DateTime(2025, 8, 31),
      status: BudgetStatus.active,
    );

Expense exp(double amount, DateTime date, {String id = 'e'}) => Expense(
      id: id,
      amount: amount,
      categoryKey: 'makan',
      note: '',
      date: date,
    );

void main() {
  const calc = WalletCalculator();

  group('period math (PRD §5)', () {
    test('5 Aug .. 31 Aug is 27 inclusive days', () {
      expect(prdBudget().totalDays, 27);
    });

    test('dailyAllowance = budget / days', () {
      expect(prdBudget().dailyAllowance, closeTo(51851.85, 0.01));
    });

    test('single-day budget spends the whole amount in one day', () {
      final b = Budget(
        id: 'b',
        name: 'Sehari',
        amount: 100000,
        startDate: DateTime(2025, 8, 5),
        endDate: DateTime(2025, 8, 5),
        status: BudgetStatus.active,
      );
      expect(b.totalDays, 1);
      expect(b.dailyAllowance, 100000);
    });
  });

  group('day 1', () {
    test('wallet equals the daily allowance', () {
      final s = calc.compute(
        budget: prdBudget(),
        expenses: const [],
        now: DateTime(2025, 8, 5, 9),
      );
      expect(s.phase, BudgetPhase.running);
      expect(s.currentDay, 1);
      expect(s.walletToday, closeTo(51851.85, 0.01));
      expect(s.carryOver, closeTo(0, 0.01));
      expect(s.expenseToday, 0);
    });

    test('spending 20.000 leaves 31.851 (PRD example)', () {
      final s = calc.compute(
        budget: prdBudget(),
        expenses: [exp(20000, DateTime(2025, 8, 5))],
        now: DateTime(2025, 8, 5, 20),
      );
      expect(s.expenseToday, 20000);
      expect(s.walletRemaining, closeTo(31851.85, 0.01));
      expect(s.tomorrowWallet, closeTo(83703.70, 0.01));
    });
  });

  group('carry over (PRD Rule 2)', () {
    test('day 2 wallet = leftover + allowance = 83.702', () {
      final s = calc.compute(
        budget: prdBudget(),
        expenses: [exp(20000, DateTime(2025, 8, 5))],
        now: DateTime(2025, 8, 6, 8),
      );
      expect(s.currentDay, 2);
      expect(s.walletToday, closeTo(83703.70, 0.01));
      expect(s.carryOver, closeTo(31851.85, 0.01));
    });

    test('unspent days keep stacking', () {
      final s = calc.compute(
        budget: prdBudget(),
        expenses: const [],
        now: DateTime(2025, 8, 8),
      );
      expect(s.currentDay, 4);
      expect(s.walletToday, closeTo(51851.85 * 4, 0.05));
    });
  });

  group('overspending (PRD Rule 3)', () {
    test('negative carry over shrinks the next wallet', () {
      // Day 1: wallet 51.851, spends 71.851 -> -20.000 carried over.
      final s = calc.compute(
        budget: prdBudget(),
        expenses: [exp(71851.85, DateTime(2025, 8, 5))],
        now: DateTime(2025, 8, 6),
      );
      expect(s.carryOver, closeTo(-20000, 0.01));
      expect(s.walletToday, closeTo(31851.85, 0.01));
    });

    test('wallet itself may go negative', () {
      final s = calc.compute(
        budget: prdBudget(),
        expenses: [exp(200000, DateTime(2025, 8, 5))],
        now: DateTime(2025, 8, 6),
      );
      expect(s.walletToday, lessThan(0));
      expect(s.walletRemaining, lessThan(0));
      // Still flagged red today even though nothing was spent today: the
      // hole from yesterday is what the user has to dig out of.
      expect(s.isOverspentToday, isTrue);
    });
  });

  group('budget totals', () {
    test('remaining and progress span the whole period', () {
      final s = calc.compute(
        budget: prdBudget(),
        expenses: [
          exp(200000, DateTime(2025, 8, 5), id: 'a'),
          exp(120000, DateTime(2025, 8, 6), id: 'b'),
        ],
        now: DateTime(2025, 8, 10),
      );
      expect(s.totalExpense, 320000);
      expect(s.budgetRemaining, 1080000);
      expect(s.progress, closeTo(0.2286, 0.001));
    });

    test('progress clamps at 100% when over budget', () {
      final s = calc.compute(
        budget: prdBudget(),
        expenses: [exp(2000000, DateTime(2025, 8, 5))],
        now: DateTime(2025, 8, 10),
      );
      expect(s.progress, 1.0);
      expect(s.budgetRemaining, -600000);
    });
  });

  group('phases (PRD Rule 4)', () {
    test('before startDate the budget is upcoming', () {
      final s = calc.compute(
        budget: prdBudget(),
        expenses: const [],
        now: DateTime(2025, 8, 1),
      );
      expect(s.phase, BudgetPhase.upcoming);
      expect(s.currentDay, 0);
      expect(s.walletToday, 0);
      expect(s.tomorrowWallet, isNull);
    });

    test('after endDate the budget is finished and frozen at the last day', () {
      final s = calc.compute(
        budget: prdBudget(),
        expenses: [exp(20000, DateTime(2025, 8, 5))],
        now: DateTime(2025, 9, 4),
      );
      expect(s.phase, BudgetPhase.finished);
      expect(s.currentDay, 27);
      expect(s.tomorrowWallet, isNull);
      expect(s.budgetRemaining, 1380000);
    });

    test('last day has no tomorrow wallet', () {
      final s = calc.compute(
        budget: prdBudget(),
        expenses: const [],
        now: DateTime(2025, 8, 31),
      );
      expect(s.currentDay, 27);
      expect(s.tomorrowWallet, isNull);
      expect(s.daysLeft, 0);
    });
  });

  group('edge cases', () {
    test('time of day never shifts the day index', () {
      final late = calc.compute(
        budget: prdBudget(),
        expenses: const [],
        now: DateTime(2025, 8, 6, 23, 59),
      );
      final early = calc.compute(
        budget: prdBudget(),
        expenses: const [],
        now: DateTime(2025, 8, 6, 0, 1),
      );
      expect(late.currentDay, early.currentDay);
      expect(late.walletToday, early.walletToday);
    });

    test('future-dated expense hits the budget but not today\'s wallet', () {
      final s = calc.compute(
        budget: prdBudget(),
        expenses: [exp(50000, DateTime(2025, 8, 20))],
        now: DateTime(2025, 8, 6),
      );
      expect(s.totalExpense, 50000);
      expect(s.expenseToday, 0);
      expect(s.walletToday, closeTo(103703.70, 0.01));
    });

    test('editing an old expense retroactively fixes today', () {
      final before = calc.compute(
        budget: prdBudget(),
        expenses: [exp(50000, DateTime(2025, 8, 5))],
        now: DateTime(2025, 8, 7),
      );
      final after = calc.compute(
        budget: prdBudget(),
        expenses: [exp(10000, DateTime(2025, 8, 5))],
        now: DateTime(2025, 8, 7),
      );
      expect(after.walletToday - before.walletToday, closeTo(40000, 0.01));
    });
  });

  group('insight copy', () {
    test('mentions the money left today', () {
      final s = calc.compute(
        budget: prdBudget(),
        expenses: [exp(20000, DateTime(2025, 8, 5))],
        now: DateTime(2025, 8, 5),
      );
      expect(buildInsight(s), contains('Rp31.852'));
    });

    test('calls out overspending', () {
      final s = calc.compute(
        budget: prdBudget(),
        expenses: [exp(70000, DateTime(2025, 8, 5))],
        now: DateTime(2025, 8, 5),
      );
      expect(buildInsight(s), contains('melebihi'));
    });
  });
}
