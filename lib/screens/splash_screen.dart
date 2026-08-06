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
            // The logo already carries the wordmark, so no title text here.
            Image.asset('assets/logo.png', width: 132, height: 132),
            const SizedBox(height: 16),
            Text(
              message ?? 'Daily Wallet Companion',
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
