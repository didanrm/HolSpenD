import 'package:firebase_analytics/firebase_analytics.dart';

/// Thin wrapper so screens never touch the Firebase SDK directly, and so a
/// logging failure can never break a user action.
class AnalyticsService {
  AnalyticsService({FirebaseAnalytics? analytics})
      : _analytics = analytics ?? FirebaseAnalytics.instance;

  final FirebaseAnalytics _analytics;

  Future<void> _safeLog(String name, [Map<String, Object>? params]) async {
    try {
      await _analytics.logEvent(name: name, parameters: params);
    } catch (_) {
      // Analytics is best-effort; never surface to the user.
    }
  }

  Future<void> loginSucceeded() => _safeLog('login_google');

  Future<void> budgetCreated({required double amount, required int days}) =>
      _safeLog('budget_created', {'amount': amount.round(), 'days': days});

  Future<void> expenseAdded({required String category, required double amount}) =>
      _safeLog('expense_added', {'category': category, 'amount': amount.round()});

  Future<void> expenseDeleted() => _safeLog('expense_deleted');
}
