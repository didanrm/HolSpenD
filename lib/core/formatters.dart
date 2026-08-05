import 'package:intl/intl.dart';

final _rupiah = NumberFormat.currency(
  locale: 'id_ID',
  symbol: 'Rp',
  decimalDigits: 0,
);

final _plainNumber = NumberFormat.decimalPattern('id_ID');

/// Rp51.851 — negative values render as -Rp15.000.
String formatRupiah(num value) {
  final rounded = value.round();
  if (rounded < 0) return '-${_rupiah.format(rounded.abs())}';
  return _rupiah.format(rounded);
}

/// 51.851 (no symbol) — used inside text inputs.
String formatPlain(num value) => _plainNumber.format(value.round());

/// Parses "51.851" / "Rp51.851" / "51851" into 51851.
double parseAmount(String raw) {
  final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.isEmpty) return 0;
  return double.parse(digits);
}

String formatDate(DateTime date) => DateFormat('d MMM yyyy', 'id_ID').format(date);

String formatDateLong(DateTime date) =>
    DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(date);

String formatDayHeader(DateTime date) =>
    DateFormat('EEEE, d MMM', 'id_ID').format(date);

String formatMonth(DateTime date) => DateFormat('MMMM yyyy', 'id_ID').format(date);
