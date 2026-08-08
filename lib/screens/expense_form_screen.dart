import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/date_x.dart';
import '../core/formatters.dart';
import '../models/budget.dart';
import '../models/expense.dart';
import '../models/expense_category.dart';
import '../providers/app_providers.dart';
import '../widgets/amount_field.dart';

/// Add (PRD §8 "Tambah Pengeluaran") and edit (PRD §8 "Expense History").
class ExpenseFormScreen extends ConsumerStatefulWidget {
  const ExpenseFormScreen({super.key, required this.budget, this.existing});

  final Budget budget;
  final Expense? existing;

  bool get isEdit => existing != null;

  @override
  ConsumerState<ExpenseFormScreen> createState() => _ExpenseFormScreenState();
}

class _ExpenseFormScreenState extends ConsumerState<ExpenseFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  late String _categoryKey;
  late DateTime _date;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _categoryKey = existing?.categoryKey ?? ExpenseCategory.makan.key;
    _date = existing?.date ?? _defaultDate();
    if (existing != null) {
      _amountController.text = formatPlain(existing.amount);
      _noteController.text = existing.note;
    }
  }

  /// Today, unless today falls outside the budget period — then clamp into it
  /// so an expense can never be dated outside the budget it belongs to.
  DateTime _defaultDate() {
    final today = DateX.dayOnly(DateTime.now());
    if (DateX.daysBetween(today, widget.budget.startDate) > 0) {
      return widget.budget.startDate;
    }
    if (DateX.daysBetween(widget.budget.endDate, today) > 0) {
      return widget.budget.endDate;
    }
    return today;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: widget.budget.startDate,
      lastDate: widget.budget.endDate,
      locale: const Locale('id', 'ID'),
    );
    if (picked != null) setState(() => _date = DateX.dayOnly(picked));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    setState(() => _saving = true);
    final repo = ref.read(budgetRepositoryProvider);
    final expense = Expense(
      id: widget.existing?.id ?? '',
      amount: parseAmount(_amountController.text),
      categoryKey: _categoryKey,
      note: _noteController.text.trim(),
      date: _date,
    );

    try {
      if (widget.isEdit) {
        await repo.updateExpense(
          uid: user.uid,
          budgetId: widget.budget.id,
          expense: expense,
        );
      } else {
        await repo.addExpense(
          uid: user.uid,
          budgetId: widget.budget.id,
          expense: expense,
        );
        ref.read(analyticsProvider).expenseAdded(
              category: expense.categoryKey,
              amount: expense.amount,
            );
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Gagal menyimpan: $e')));
      }
    }
  }

  Future<void> _delete() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus pengeluaran?'),
        content: const Text('Catatan ini akan dihapus permanen.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _saving = true);
    try {
      await ref.read(budgetRepositoryProvider).deleteExpense(
            uid: user.uid,
            budgetId: widget.budget.id,
            expenseId: widget.existing!.id,
          );
      ref.read(analyticsProvider).expenseDeleted();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Gagal menghapus: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEdit ? 'Edit Pengeluaran' : 'Tambah Pengeluaran'),
        actions: [
          if (widget.isEdit)
            IconButton(
              onPressed: _saving ? null : _delete,
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Hapus',
            ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              AmountField(
                controller: _amountController,
                autofocus: !widget.isEdit,
              ),
              const SizedBox(height: 22),
              Text('Kategori', style: theme.textTheme.labelLarge),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final category in ExpenseCategory.all)
                    _CategoryChip(
                      category: category,
                      selected: category.key == _categoryKey,
                      onTap: () => setState(() => _categoryKey = category.key),
                    ),
                ],
              ),
              const SizedBox(height: 22),
              TextFormField(
                controller: _noteController,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Catatan (opsional)',
                  hintText: 'Makan siang di kantin',
                ),
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: theme.colorScheme.outlineVariant),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 18),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          formatDateLong(_date),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 28),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: Text(_saving ? 'Menyimpan...' : 'Simpan'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.category,
    required this.selected,
    required this.onTap,
  });

  final ExpenseCategory category;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? category.color.withValues(alpha: 0.16) : Colors.white,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: selected
                ? category.color
                : Theme.of(context).colorScheme.outlineVariant,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(category.emoji),
            const SizedBox(width: 6),
            Text(
              category.label,
              style: TextStyle(
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
