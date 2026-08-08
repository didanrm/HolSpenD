import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/date_x.dart';
import '../core/formatters.dart';
import '../models/expense.dart';
import '../providers/app_providers.dart';
import '../widgets/expense_tile.dart';
import '../widgets/section_card.dart';
import 'expense_form_screen.dart';

enum HistoryFilter { hari, bulan, semua }

/// PRD §8 "Expense History": full list, filter by day/month, edit, delete.
class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  HistoryFilter _filter = HistoryFilter.bulan;
  late DateTime _anchor = DateX.dayOnly(DateTime.now());

  bool _matches(Expense expense) {
    switch (_filter) {
      case HistoryFilter.hari:
        return DateX.isSameDay(expense.date, _anchor);
      case HistoryFilter.bulan:
        return expense.date.year == _anchor.year &&
            expense.date.month == _anchor.month;
      case HistoryFilter.semua:
        return true;
    }
  }

  void _shiftAnchor(int step) {
    setState(() {
      _anchor = switch (_filter) {
        HistoryFilter.hari => _anchor.add(Duration(days: step)),
        HistoryFilter.bulan =>
          DateTime(_anchor.year, _anchor.month + step, 1),
        HistoryFilter.semua => _anchor,
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final budget = ref.watch(activeBudgetProvider).valueOrNull;
    final expensesAsync = ref.watch(expensesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Riwayat Pengeluaran')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
              child: Column(
                children: [
                  SegmentedButton<HistoryFilter>(
                    segments: const [
                      ButtonSegment(value: HistoryFilter.hari, label: Text('Hari')),
                      ButtonSegment(value: HistoryFilter.bulan, label: Text('Bulan')),
                      ButtonSegment(value: HistoryFilter.semua, label: Text('Semua')),
                    ],
                    selected: {_filter},
                    showSelectedIcon: false,
                    onSelectionChanged: (value) => setState(() {
                      _filter = value.first;
                      _anchor = DateX.dayOnly(DateTime.now());
                    }),
                  ),
                  if (_filter != HistoryFilter.semua) ...[
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          onPressed: () => _shiftAnchor(-1),
                          icon: const Icon(Icons.chevron_left),
                        ),
                        Text(
                          _filter == HistoryFilter.hari
                              ? formatDate(_anchor)
                              : formatMonth(_anchor),
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        IconButton(
                          onPressed: () => _shiftAnchor(1),
                          icon: const Icon(Icons.chevron_right),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              child: expensesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Gagal memuat data: $e')),
                data: (all) {
                  final filtered = all.where(_matches).toList()
                    ..sort((a, b) => b.date.compareTo(a.date));

                  if (filtered.isEmpty) {
                    return const _EmptyState();
                  }

                  final total =
                      filtered.fold<double>(0, (sum, e) => sum + e.amount);
                  final grouped = <DateTime, List<Expense>>{};
                  for (final expense in filtered) {
                    grouped.putIfAbsent(expense.date, () => []).add(expense);
                  }
                  final days = grouped.keys.toList()
                    ..sort((a, b) => b.compareTo(a));

                  return ListView(
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 28),
                    children: [
                      SectionCard(
                        color: const Color(0xFFE9F7F3),
                        child: Row(
                          children: [
                            Expanded(
                              child: StatBlock(
                                label: 'Total periode ini',
                                value: formatRupiah(total),
                              ),
                            ),
                            StatBlock(
                              label: 'Transaksi',
                              value: '${filtered.length}',
                              align: CrossAxisAlignment.end,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      for (final day in days) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(4, 10, 4, 6),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                formatDayHeader(day),
                                style: theme.textTheme.labelLarge?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              Text(
                                formatRupiah(
                                  grouped[day]!
                                      .fold<double>(0, (s, e) => s + e.amount),
                                ),
                                style: theme.textTheme.labelLarge?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SectionCard(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 6,
                          ),
                          child: Column(
                            children: [
                              for (final expense in grouped[day]!)
                                ExpenseTile(
                                  expense: expense,
                                  onTap: budget == null
                                      ? null
                                      : () => Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => ExpenseFormScreen(
                                                budget: budget,
                                                existing: expense,
                                              ),
                                            ),
                                          ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🧾', style: TextStyle(fontSize: 40)),
          const SizedBox(height: 12),
          Text(
            'Belum ada transaksi di periode ini.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}
