import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logic/wallet_calculator.dart';
import '../models/budget.dart';
import '../models/expense.dart';
import '../services/analytics_service.dart';
import '../services/auth_service.dart';
import '../services/budget_repository.dart';

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

final analyticsProvider = Provider<AnalyticsService>((ref) => AnalyticsService());

final budgetRepositoryProvider =
    Provider<BudgetRepository>((ref) => BudgetRepository());

final walletCalculatorProvider =
    Provider<WalletCalculator>((ref) => const WalletCalculator());

final authStateProvider = StreamProvider<User?>(
  (ref) => ref.watch(authServiceProvider).authState,
);

/// Null while signed out — that is the guest state, not an error.
final currentUserProvider = Provider<User?>(
  (ref) => ref.watch(authStateProvider).valueOrNull,
);

/// True once the welcome sign-in prompt has been shown, so it appears at most
/// once per app launch. Deliberately not persisted: a guest who reopens the app
/// tomorrow should be invited again.
final welcomePromptShownProvider = StateProvider<bool>((ref) => false);

final activeBudgetProvider = StreamProvider<Budget?>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value(null);
  return ref.watch(budgetRepositoryProvider).watchActiveBudget(user.uid);
});

final expensesProvider = StreamProvider<List<Expense>>((ref) {
  final user = ref.watch(currentUserProvider);
  final budget = ref.watch(activeBudgetProvider).valueOrNull;
  if (user == null || budget == null) return Stream.value(const <Expense>[]);
  return ref.watch(budgetRepositoryProvider).watchExpenses(user.uid, budget.id);
});

/// Ticks at every local midnight so the dashboard rolls over to the new day
/// without the user restarting the app.
final todayProvider = StreamProvider<DateTime>((ref) async* {
  DateTime today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  var current = today();
  yield current;

  while (true) {
    final now = DateTime.now();
    final nextMidnight = DateTime(now.year, now.month, now.day + 1);
    await Future<void>.delayed(nextMidnight.difference(now) + const Duration(seconds: 1));
    final next = today();
    if (next != current) {
      current = next;
      yield current;
    }
  }
});

/// The one number the whole app reads from. Null until a budget exists.
final walletSnapshotProvider = Provider<WalletSnapshot?>((ref) {
  final budget = ref.watch(activeBudgetProvider).valueOrNull;
  if (budget == null) return null;
  final expenses = ref.watch(expensesProvider).valueOrNull ?? const <Expense>[];
  final today = ref.watch(todayProvider).valueOrNull ?? DateTime.now();

  return ref.watch(walletCalculatorProvider).compute(
        budget: budget,
        expenses: expenses,
        now: today,
      );
});
