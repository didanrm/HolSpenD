import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'core/theme.dart';
import 'firebase_options.dart';
import 'providers/app_providers.dart';
import 'screens/create_budget_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID');

  String? bootError;
  if (DefaultFirebaseOptions.isConfigured) {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } catch (e) {
      bootError = '$e';
    }
  } else {
    bootError = 'not-configured';
  }

  runApp(ProviderScope(child: HolSpenDApp(bootError: bootError)));
}

class HolSpenDApp extends StatelessWidget {
  const HolSpenDApp({super.key, this.bootError});

  final String? bootError;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HolSpenD',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      locale: const Locale('id', 'ID'),
      supportedLocales: const [Locale('id', 'ID'), Locale('en', 'US')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: bootError == null
          ? const AuthGate()
          : SetupRequiredScreen(reason: bootError!),
    );
  }
}

/// Splash -> Dashboard. Signing in is no longer a wall in front of the app:
/// a guest lands straight on the dashboard and is invited to sign in from
/// there, so the product can be understood before it asks for anything.
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    return authState.when(
      loading: () => const SplashScreen(),
      error: (e, _) => SetupRequiredScreen(reason: '$e'),
      data: (user) {
        // Guest: dashboard in read-only mode, no budget to load.
        if (user == null) return const DashboardScreen(budget: null);
        return const _BudgetGate();
      },
    );
  }
}

class _BudgetGate extends ConsumerWidget {
  const _BudgetGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final budgetAsync = ref.watch(activeBudgetProvider);

    return budgetAsync.when(
      loading: () => const SplashScreen(message: 'Menyiapkan wallet kamu...'),
      error: (e, _) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Gagal memuat budget:\n$e', textAlign: TextAlign.center),
          ),
        ),
      ),
      data: (budget) {
        if (budget == null) return const CreateBudgetScreen();
        return DashboardScreen(budget: budget);
      },
    );
  }
}

/// Shown when Firebase is not wired up yet, so the failure is self-explanatory
/// instead of a red screen.
class SetupRequiredScreen extends StatelessWidget {
  const SetupRequiredScreen({super.key, required this.reason});

  final String reason;

  @override
  Widget build(BuildContext context) {
    final notConfigured = reason == 'not-configured';

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🔧', style: TextStyle(fontSize: 42)),
                const SizedBox(height: 16),
                Text(
                  notConfigured
                      ? 'Firebase belum dikonfigurasi'
                      : 'Firebase gagal dimuat',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                Text(
                  notConfigured
                      ? 'Jalankan perintah ini di root project:\n\n'
                          'flutterfire configure\n\n'
                          'lalu jalankan ulang aplikasinya.'
                      : reason,
                  textAlign: TextAlign.center,
                  style: const TextStyle(height: 1.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
