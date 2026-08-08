import 'package:flutter/material.dart';

/// Fixed MVP category set (PRD §8). [key] is what gets stored in Firestore —
/// never store the label, so renaming a label does not orphan old data.
class ExpenseCategory {
  const ExpenseCategory(this.key, this.emoji, this.label, this.color);

  final String key;
  final String emoji;
  final String label;
  final Color color;

  static const makan = ExpenseCategory('makan', '🍜', 'Makan', Color(0xFFF97316));
  static const transport =
      ExpenseCategory('transport', '🚗', 'Transport', Color(0xFF3B82F6));
  static const belanja =
      ExpenseCategory('belanja', '🛒', 'Belanja', Color(0xFF8B5CF6));
  static const nongkrong =
      ExpenseCategory('nongkrong', '☕', 'Nongkrong', Color(0xFFA16207));
  static const hiburan =
      ExpenseCategory('hiburan', '🎮', 'Hiburan', Color(0xFFEC4899));
  static const kesehatan =
      ExpenseCategory('kesehatan', '💊', 'Kesehatan', Color(0xFF10B981));
  static const pendidikan =
      ExpenseCategory('pendidikan', '📚', 'Pendidikan', Color(0xFF0EA5E9));
  static const lainnya =
      ExpenseCategory('lainnya', '💡', 'Lainnya', Color(0xFF64748B));

  static const all = <ExpenseCategory>[
    makan,
    transport,
    belanja,
    nongkrong,
    hiburan,
    kesehatan,
    pendidikan,
    lainnya,
  ];

  /// Unknown keys fall back to "Lainnya" so old/foreign data still renders.
  static ExpenseCategory fromKey(String? key) =>
      all.firstWhere((c) => c.key == key, orElse: () => lainnya);
}
