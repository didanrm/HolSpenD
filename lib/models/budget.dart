import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/date_x.dart';

enum BudgetStatus { active, completed }

class Budget {
  const Budget({
    required this.id,
    required this.name,
    required this.amount,
    required this.startDate,
    required this.endDate,
    required this.status,
    this.createdAt,
  });

  final String id;
  final String name;
  final double amount;
  final DateTime startDate;
  final DateTime endDate;
  final BudgetStatus status;
  final DateTime? createdAt;

  /// Inclusive: 5 Aug .. 31 Aug = 27 days.
  int get totalDays => DateX.inclusiveDayCount(startDate, endDate);

  double get dailyAllowance => totalDays <= 0 ? 0 : amount / totalDays;

  bool get isActive => status == BudgetStatus.active;

  factory Budget.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return Budget(
      id: doc.id,
      name: (data['name'] as String?) ?? 'Budget',
      amount: (data['amount'] as num?)?.toDouble() ?? 0,
      startDate: _toDate(data['startDate']),
      endDate: _toDate(data['endDate']),
      status: (data['status'] as String?) == 'completed'
          ? BudgetStatus.completed
          : BudgetStatus.active,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  /// [dailyAllowance] and the wallet fields are denormalised copies (PRD §14).
  /// The app never trusts them for math — it recomputes from the expense list —
  /// but they are handy for Cloud Functions / notifications / debugging.
  Map<String, dynamic> toMap({
    double? walletToday,
    double? walletRemaining,
    double? carryOver,
    int? currentDay,
  }) {
    return {
      'name': name,
      'amount': amount,
      'dailyAllowance': dailyAllowance,
      'startDate': Timestamp.fromDate(DateX.dayOnly(startDate)),
      'endDate': Timestamp.fromDate(DateX.dayOnly(endDate)),
      'totalDays': totalDays,
      'status': status.name,
      if (walletToday != null) 'walletToday': walletToday,
      if (walletRemaining != null) 'walletRemaining': walletRemaining,
      if (carryOver != null) 'carryOver': carryOver,
      if (currentDay != null) 'currentDay': currentDay,
    };
  }

  Budget copyWith({String? name, double? amount, BudgetStatus? status}) => Budget(
        id: id,
        name: name ?? this.name,
        amount: amount ?? this.amount,
        startDate: startDate,
        endDate: endDate,
        status: status ?? this.status,
        createdAt: createdAt,
      );

  static DateTime _toDate(Object? value) {
    if (value is Timestamp) return DateX.dayOnly(value.toDate());
    if (value is DateTime) return DateX.dayOnly(value);
    return DateX.dayOnly(DateTime.now());
  }
}
