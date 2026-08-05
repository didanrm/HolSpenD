import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/date_x.dart';

class Expense {
  const Expense({
    required this.id,
    required this.amount,
    required this.categoryKey,
    required this.note,
    required this.date,
    this.createdAt,
  });

  final String id;
  final double amount;
  final String categoryKey;
  final String note;

  /// Calendar day the money was spent (time component stripped).
  final DateTime date;
  final DateTime? createdAt;

  factory Expense.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    final rawDate = data['date'];
    return Expense(
      id: doc.id,
      amount: (data['amount'] as num?)?.toDouble() ?? 0,
      categoryKey: (data['category'] as String?) ?? 'lainnya',
      note: (data['note'] as String?) ?? '',
      date: rawDate is Timestamp
          ? DateX.dayOnly(rawDate.toDate())
          : DateX.dayOnly(DateTime.now()),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'amount': amount,
        'category': categoryKey,
        'note': note,
        'date': Timestamp.fromDate(DateX.dayOnly(date)),
      };

  Expense copyWith({
    double? amount,
    String? categoryKey,
    String? note,
    DateTime? date,
  }) =>
      Expense(
        id: id,
        amount: amount ?? this.amount,
        categoryKey: categoryKey ?? this.categoryKey,
        note: note ?? this.note,
        date: date ?? this.date,
        createdAt: createdAt,
      );
}
