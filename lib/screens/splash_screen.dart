import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Matches the native launch screen (white, logo centred) so there is no colour
/// flash when Android hands over to Flutter.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.splash,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // The mark is wordmark-free, so the name is set as text below it.
            Image.asset('assets/logo.png', width: 132, height: 132),
            const SizedBox(height: 16),
            Text(
              'HolSpenD',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message ?? 'Hold Your Spending!',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 28),
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            ),
          ],
        ),
      ),
    );
  }
}
