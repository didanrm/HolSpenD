import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/date_x.dart';
import '../logic/wallet_calculator.dart';
import '../models/budget.dart';
import '../models/expense.dart';

/// Firestore layout (PRD §13):
///
///   users/{uid}                              profile + activeBudgetId
///   users/{uid}/budgets/{budgetId}           budget document
///   users/{uid}/budgets/{budgetId}/expenses/{expenseId}
class BudgetRepository {
  BudgetRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _userDoc(String uid) =>
      _db.collection('users').doc(uid);

  CollectionReference<Map<String, dynamic>> _budgets(String uid) =>
      _userDoc(uid).collection('budgets');

  CollectionReference<Map<String, dynamic>> _expenses(String uid, String budgetId) =>
      _budgets(uid).doc(budgetId).collection('expenses');

  Future<void> upsertProfile(User user) {
    return _userDoc(user.uid).set({
      'profile': {
        'name': user.displayName ?? 'Teman HolSpend',
        'email': user.email,
        'photoUrl': user.photoURL,
      },
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// The single active budget (PRD Rule 5). Emits null when there is none.
  ///
  /// Deliberately unordered: `createdAt` is a server timestamp that reads back
  /// as null until the write is acknowledged, and Firestore drops null-field
  /// docs from ordered queries — ordering here would make a freshly created
  /// budget flicker out of existence. The batch in [createBudget] guarantees at
  /// most one active budget anyway; newest wins if that ever slips.
  Stream<Budget?> watchActiveBudget(String uid) {
    return _budgets(uid)
        .where('status', isEqualTo: 'active')
        .snapshots()
        .map((snap) {
      if (snap.docs.isEmpty) return null;
      final budgets = snap.docs.map(Budget.fromDoc).toList()
        ..sort((a, b) => (b.createdAt ?? b.startDate)
            .compareTo(a.createdAt ?? a.startDate));
      return budgets.first;
    });
  }

  Stream<List<Expense>> watchExpenses(String uid, String budgetId) {
    return _expenses(uid, budgetId)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(Expense.fromDoc).toList());
  }

  /// Creates a budget and closes any previous one in a single atomic batch —
  /// there is never a moment with two active budgets or zero.
  Future<String> createBudget({
    required String uid,
    required String name,
    required double amount,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final batch = _db.batch();

    final previous = await _budgets(uid).where('status', isEqualTo: 'active').get();
    for (final doc in previous.docs) {
      batch.update(doc.reference, {
        'status': BudgetStatus.completed.name,
        'closedAt': FieldValue.serverTimestamp(),
      });
    }

    final newDoc = _budgets(uid).doc();
    final budget = Budget(
      id: newDoc.id,
      name: name,
      amount: amount,
      startDate: DateX.dayOnly(startDate),
      endDate: DateX.dayOnly(endDate),
      status: BudgetStatus.active,
    );

    batch.set(newDoc, {
      ...budget.toMap(
        walletToday: budget.dailyAllowance,
        walletRemaining: budget.dailyAllowance,
        carryOver: 0,
        currentDay: 1,
      ),
      'createdAt': FieldValue.serverTimestamp(),
    });

    batch.set(
      _userDoc(uid),
      {'activeBudgetId': newDoc.id, 'updatedAt': FieldValue.serverTimestamp()},
      SetOptions(merge: true),
    );

    await batch.commit();
    return newDoc.id;
  }

  Future<void> closeBudget(String uid, String budgetId) async {
    await _budgets(uid).doc(budgetId).update({
      'status': BudgetStatus.completed.name,
      'closedAt': FieldValue.serverTimestamp(),
    });
    await _userDoc(uid).set(
      {'activeBudgetId': null, 'updatedAt': FieldValue.serverTimestamp()},
      SetOptions(merge: true),
    );
  }

  Future<void> addExpense({
    required String uid,
    required String budgetId,
    required Expense expense,
  }) {
    return _expenses(uid, budgetId).add({
      ...expense.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateExpense({
    required String uid,
    required String budgetId,
    required Expense expense,
  }) {
    return _expenses(uid, budgetId).doc(expense.id).update({
      ...expense.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteExpense({
    required String uid,
    required String budgetId,
    required String expenseId,
  }) {
    return _expenses(uid, budgetId).doc(expenseId).delete();
  }

  /// Mirrors the computed wallet back onto the budget document (PRD §14).
  /// Purely denormalisation for notifications/analytics — the app itself always
  /// recomputes from the expense log, so a stale mirror can never corrupt the UI.
  Future<void> syncWalletMirror({
    required String uid,
    required String budgetId,
    required WalletSnapshot snapshot,
  }) {
    return _budgets(uid).doc(budgetId).set({
      'walletToday': snapshot.walletToday,
      'walletRemaining': snapshot.walletRemaining,
      'carryOver': snapshot.carryOver,
      'currentDay': snapshot.currentDay,
      'totalExpense': snapshot.totalExpense,
      'syncedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
