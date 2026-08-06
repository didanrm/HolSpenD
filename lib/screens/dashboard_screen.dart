import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/date_x.dart';
import '../core/formatters.dart';
import '../logic/wallet_calculator.dart';
import '../models/budget.dart';
import '../models/expense.dart';
import '../providers/app_providers.dart';
import '../widgets/auth_prompt.dart';
import '../widgets/budget_summary.dart';
import '../widgets/expense_tile.dart';
import '../widgets/section_card.dart';
import '../widgets/wallet_hero.dart';
import 'create_budget_screen.dart';
import 'expense_form_screen.dart';
import 'history_screen.dart';
import 'settings_screen.dart';

/// The app's home. [budget] is null for a guest, who sees the same layout with
/// zeroed numbers and is asked to sign in before changing anything.
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key, required this.budget});

  final Budget? budget;

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    // Invite the guest once per launch, after the first frame so the sheet does
    // not fight the route transition.
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeWelcome());
  }

  Future<void> _maybeWelcome() async {
    if (!mounted) return;
    if (ref.read(currentUserProvider) != null) return;
    if (ref.read(welcomePromptShownProvider)) return;
    ref.read(welcomePromptShownProvider.notifier).state = true;
    await showAuthPrompt(context, ref, message: AuthPromptCopy.welcome);
  }

  /// Runs [action] only once there is a signed-in user.
  Future<void> _guarded(Future<void> Function() action) async {
    if (!await ensureSignedIn(context, ref)) return;
    if (!mounted) return;
    await action();
  }

  @override
  Widget build(BuildContext context) {
    final budget = widget.budget;
    final user = ref.watch(currentUserProvider);
    final snapshot = ref.watch(walletSnapshotProvider);
    final expensesAsync = ref.watch(expensesProvider);
    final today = ref.watch(todayProvider).valueOrNull ?? DateTime.now();

    // Mirror the computed wallet onto the budget doc for notifications and
    // analytics. Fire-and-forget: the UI never reads it back.
    ref.listen<WalletSnapshot?>(walletSnapshotProvider, (previous, next) {
      if (next == null || user == null || budget == null) return;
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

    // A signed-in user with a budget but no snapshot yet is still loading.
    if (snapshot == null && budget != null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final view = snapshot ?? const WalletSnapshot.empty();
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
              WalletHero(snapshot: view),
              const SizedBox(height: 14),
              if (budget == null)
                const _GuestBanner()
              else ...[
                if (view.phase == BudgetPhase.finished)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 14),
                    child: _FinishedBanner(),
                  ),
                BudgetSummaryCard(snapshot: view, name: budget.name),
                const SizedBox(height: 14),
                TodayCard(snapshot: view),
                const SizedBox(height: 14),
                InsightCard(snapshot: view),
              ],
              const SizedBox(height: 14),
              _TodayExpenses(
                budget: budget,
                expenses: todayExpenses,
                onTapExpense: (expense) => _guarded(() async {
                  if (budget == null) return;
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          ExpenseFormScreen(budget: budget, existing: expense),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 10),
              Center(
                child: TextButton.icon(
                  onPressed: () => _guarded(() async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CreateBudgetScreen(
                          replacingExisting: widget.budget != null,
                        ),
                      ),
                    );
                  }),
                  icon: const Icon(Icons.autorenew, size: 18),
                  label: Text(
                    budget == null ? 'Mulai budget pertama' : 'Buat budget baru',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _guarded(() async {
          // After signing in the budget arrives asynchronously, so re-read it.
          final active = ref.read(activeBudgetProvider).valueOrNull;
          if (active == null) return; // AuthGate routes them to Create Budget
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => ExpenseFormScreen(budget: active)),
          );
        }),
        icon: const Icon(Icons.add),
        label: const Text('Pengeluaran'),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.name, this.photoUrl});

  final String name;
  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
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
          tooltip: 'Pengaturan',
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SettingsScreen()),
          ),
          icon: const Icon(Icons.settings_outlined),
        ),
      ],
    );
  }
}

/// Replaces the budget cards for a guest: nothing to summarise yet.
class _GuestBanner extends ConsumerWidget {
  const _GuestBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return SectionCard(
      color: const Color(0xFFE9F7F3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('👋', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Kamu belum masuk',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0E7C64),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Lihat-lihat dulu boleh. Untuk membuat budget dan '
                      'mencatat pengeluaran, masuk dulu ya.',
                      style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: () => showAuthPrompt(
              context,
              ref,
              message: AuthPromptCopy.welcome,
            ),
            icon: const Icon(Icons.login),
            label: const Text('Login / Sign Up'),
          ),
        ],
      ),
    );
  }
}

class _TodayExpenses extends StatelessWidget {
  const _TodayExpenses({
    required this.budget,
    required this.expenses,
    required this.onTapExpense,
  });

  final Budget? budget;
  final List<Expense> expenses;
  final void Function(Expense) onTapExpense;

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
                  budget == null
                      ? 'Belum ada transaksi.'
                      : 'Belum ada pengeluaran hari ini 🎉',
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
                onTap: () => onTapExpense(expense),
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
