import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/date_x.dart';
import '../core/formatters.dart';
import '../logic/wallet_calculator.dart';
import '../models/budget.dart';
import '../models/expense.dart';
import '../providers/app_providers.dart';
import '../widgets/budget_summary.dart';
import '../widgets/expense_tile.dart';
import '../widgets/section_card.dart';
import '../widgets/wallet_hero.dart';
import 'create_budget_screen.dart';
import 'expense_form_screen.dart';
import 'history_screen.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key, required this.budget});

  final Budget budget;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final snapshot = ref.watch(walletSnapshotProvider);
    final expensesAsync = ref.watch(expensesProvider);
    final today = ref.watch(todayProvider).valueOrNull ?? DateTime.now();

    // Mirror the computed wallet onto the budget doc for notifications and
    // analytics. Fire-and-forget: the UI never reads it back.
    ref.listen<WalletSnapshot?>(walletSnapshotProvider, (previous, next) {
      if (next == null || user == null) return;
      if (previous != null &&
          previous.currentDay == next.currentDay &&
          previous.totalExpense == next.totalExpense) {
        return;
      }
      ref.read(budgetRepositoryProvider).syncWalletMirror(
            uid: user.uid,
            budgetId: budget.id,
            snapshot: next,
          );
    });

    if (snapshot == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final todayExpenses = (expensesAsync.valueOrNull ?? const <Expense>[])
        .where((e) => DateX.isSameDay(e.date, today))
        .toList();

    final firstName = (user?.displayName ?? 'Teman').split(' ').first;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(activeBudgetProvider);
            ref.invalidate(expensesProvider);
            await Future<void>.delayed(const Duration(milliseconds: 400));
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 110),
            children: [
              _Header(name: firstName, photoUrl: user?.photoURL),
              const SizedBox(height: 18),
              WalletHero(snapshot: snapshot),
              const SizedBox(height: 14),
              if (snapshot.phase == BudgetPhase.finished)
                const Padding(
                  padding: EdgeInsets.only(bottom: 14),
                  child: _FinishedBanner(),
                ),
              BudgetSummaryCard(snapshot: snapshot, name: budget.name),
              const SizedBox(height: 14),
              TodayCard(snapshot: snapshot),
              const SizedBox(height: 14),
              InsightCard(snapshot: snapshot),
              const SizedBox(height: 14),
              _TodayExpenses(budget: budget, expenses: todayExpenses),
              const SizedBox(height: 10),
              Center(
                child: TextButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          const CreateBudgetScreen(replacingExisting: true),
                    ),
                  ),
                  icon: const Icon(Icons.autorenew, size: 18),
                  label: const Text('Buat budget baru'),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ExpenseFormScreen(budget: budget)),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Pengeluaran'),
      ),
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header({required this.name, this.photoUrl});

  final String name;
  final String? photoUrl;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Row(
      children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: theme.colorScheme.primaryContainer,
          backgroundImage: photoUrl != null ? NetworkImage(photoUrl!) : null,
          child: photoUrl == null ? const Text('👋') : null,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Halo, $name 👋',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              Text(
                formatDateLong(DateTime.now()),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Riwayat',
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const HistoryScreen()),
          ),
          icon: const Icon(Icons.receipt_long_outlined),
        ),
        IconButton(
          tooltip: 'Keluar',
          onPressed: () async {
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Keluar dari HolSpend?'),
                content: const Text('Data kamu tetap tersimpan di akun Google.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Batal'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Keluar'),
                  ),
                ],
              ),
            );
            if (confirmed == true) {
              await ref.read(authServiceProvider).signOut();
            }
          },
          icon: const Icon(Icons.logout),
        ),
      ],
    );
  }
}

class _TodayExpenses extends StatelessWidget {
  const _TodayExpenses({required this.budget, required this.expenses});

  final Budget budget;
  final List<Expense> expenses;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Transaksi Hari Ini',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const HistoryScreen()),
                ),
                child: const Text('Semua'),
              ),
            ],
          ),
          if (expenses.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Center(
                child: Text(
                  'Belum ada pengeluaran hari ini 🎉',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            )
          else
            for (final expense in expenses)
              ExpenseTile(
                expense: expense,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        ExpenseFormScreen(budget: budget, existing: expense),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

class _FinishedBanner extends StatelessWidget {
  const _FinishedBanner();

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      color: const Color(0xFFFFF7E6),
      child: Row(
        children: [
          const Text('🏁', style: TextStyle(fontSize: 20)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Periode budget ini sudah selesai. Buat budget baru untuk '
              'melanjutkan Daily Wallet.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
