import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/date_x.dart';
import '../core/formatters.dart';
import '../core/theme.dart';
import '../providers/app_providers.dart';
import '../widgets/amount_field.dart';
import '../widgets/section_card.dart';

class CreateBudgetScreen extends ConsumerStatefulWidget {
  const CreateBudgetScreen({super.key, this.replacingExisting = false});

  /// True when the user already has an active budget — creating a new one
  /// closes the old one (PRD Rule 4 & 5), so we warn first.
  final bool replacingExisting;

  @override
  ConsumerState<CreateBudgetScreen> createState() => _CreateBudgetScreenState();
}

class _CreateBudgetScreenState extends ConsumerState<CreateBudgetScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();

  late DateTime _startDate;
  late DateTime _endDate;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final today = DateX.dayOnly(DateTime.now());
    _startDate = today;
    // Default period: to the end of the current month.
    _endDate = DateTime(today.year, today.month + 1, 0);
    if (DateX.daysBetween(_startDate, _endDate) < 0) _endDate = today;
    _nameController.text = 'Budget ${formatMonth(today)}';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  int get _totalDays => DateX.inclusiveDayCount(_startDate, _endDate);

  double get _amount => parseAmount(_amountController.text);

  double get _allowance => _totalDays <= 0 ? 0 : _amount / _totalDays;

  Future<void> _pickDate({required bool isStart}) async {
    final initial = isStart ? _startDate : _endDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(DateTime.now().year - 1),
      lastDate: DateTime(DateTime.now().year + 3),
      locale: const Locale('id', 'ID'),
    );
    if (picked == null) return;

    setState(() {
      if (isStart) {
        _startDate = DateX.dayOnly(picked);
        // Keep the range valid without silently discarding the user's choice.
        if (DateX.daysBetween(_startDate, _endDate) < 0) _endDate = _startDate;
      } else {
        _endDate = DateX.dayOnly(picked);
        if (DateX.daysBetween(_startDate, _endDate) < 0) _startDate = _endDate;
      }
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final user = ref.read(currentUserProvider);
    if (user == null) return;

    if (widget.replacingExisting) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Ganti budget aktif?'),
          content: const Text(
            'Budget yang sedang berjalan akan ditutup dan riwayatnya tetap '
            'tersimpan. HolSpend hanya menjalankan satu budget aktif.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Ganti'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    setState(() => _saving = true);
    try {
      await ref.read(budgetRepositoryProvider).createBudget(
            uid: user.uid,
            name: _nameController.text.trim(),
            amount: _amount,
            startDate: _startDate,
            endDate: _endDate,
          );
      ref.read(analyticsProvider).budgetCreated(amount: _amount, days: _totalDays);
      if (mounted && Navigator.canPop(context)) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Gagal menyimpan budget: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.replacingExisting ? 'Budget Baru' : 'Buat Budget'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          onChanged: () => setState(() {}),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              Text(
                'Tentukan budget dan periodenya. HolSpend akan membagi otomatis '
                'menjadi jatah harian.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 22),
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Nama budget',
                  hintText: 'Budget Agustus',
                ),
                validator: (value) =>
                    (value == null || value.trim().isEmpty) ? 'Isi nama budget' : null,
              ),
              const SizedBox(height: 16),
              AmountField(controller: _amountController, label: 'Total budget'),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _DateTile(
                      label: 'Mulai',
                      date: _startDate,
                      onTap: () => _pickDate(isStart: true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _DateTile(
                      label: 'Selesai',
                      date: _endDate,
                      onTap: () => _pickDate(isStart: false),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              SectionCard(
                color: const Color(0xFFE9F7F3),
                child: Row(
                  children: [
                    Expanded(
                      child: StatBlock(
                        label: 'Jumlah hari',
                        value: '$_totalDays hari',
                      ),
                    ),
                    Expanded(
                      child: StatBlock(
                        label: 'Jatah per hari',
                        value: formatRupiah(_allowance),
                        valueColor: AppColors.seed,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 26),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: Text(_saving ? 'Menyimpan...' : 'Mulai Budget'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DateTile extends StatelessWidget {
  const _DateTile({required this.label, required this.date, required this.onTap});

  final String label;
  final DateTime date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 15),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    formatDate(date),
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
