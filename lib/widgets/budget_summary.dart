import 'package:flutter/material.dart';

import '../core/formatters.dart';
import '../core/theme.dart';
import '../logic/wallet_calculator.dart';
import 'section_card.dart';

class BudgetSummaryCard extends StatelessWidget {
  const BudgetSummaryCard({super.key, required this.snapshot, required this.name});

  final WalletSnapshot snapshot;
  final String name;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final percent = (snapshot.progress * 100).round();
    final overBudget = snapshot.budgetRemaining < 0;

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  name,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                '$percent% terpakai',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: snapshot.progress,
              minHeight: 10,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation(
                overBudget ? AppColors.negative : AppColors.seed,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: StatBlock(
                  label: 'Budget',
                  value: formatRupiah(snapshot.budgetAmount),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatBlock(
                  label: 'Terpakai',
                  value: formatRupiah(snapshot.totalExpense),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatBlock(
                  label: 'Sisa',
                  value: formatRupiah(snapshot.budgetRemaining),
                  valueColor: overBudget ? AppColors.negative : AppColors.positive,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class TodayCard extends StatelessWidget {
  const TodayCard({super.key, required this.snapshot});

  final WalletSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Row(
        children: [
          Expanded(
            child: StatBlock(
              label: 'Pengeluaran hari ini',
              value: formatRupiah(snapshot.expenseToday),
            ),
          ),
          Container(width: 1, height: 34, color: const Color(0x14000000)),
          const SizedBox(width: 12),
          Expanded(
            child: StatBlock(
              label: 'Wallet awal',
              value: formatRupiah(snapshot.walletToday),
              valueColor:
                  snapshot.walletToday < 0 ? AppColors.negative : null,
            ),
          ),
        ],
      ),
    );
  }
}

class InsightCard extends StatelessWidget {
  const InsightCard({super.key, required this.snapshot});

  final WalletSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final over = snapshot.isOverspentToday;

    return SectionCard(
      color: over ? const Color(0xFFFFF1F1) : const Color(0xFFE9F7F3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(over ? '⚠️' : '💡', style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Insight Hari Ini',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: over ? AppColors.negative : const Color(0xFF0E7C64),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  buildInsight(snapshot),
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
