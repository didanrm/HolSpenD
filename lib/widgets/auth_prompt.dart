import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme.dart';
import '../providers/app_providers.dart';

/// Copy for the two moments a guest is asked to sign in.
class AuthPromptCopy {
  /// Shown once, unprompted, the first time a guest opens the app.
  static const welcome = 'Udah siap tahan pengeluaranmu? Yuk Login/Sign Up';

  /// Shown when a guest tries to change something.
  static const action = 'Login/Sign Up dahulu untuk mulai';
}

/// Runs the Google sign-in flow. Returns true when a user ends up signed in.
///
/// Lives here rather than on a screen because three different places need it:
/// the welcome prompt, every write action, and the settings screen.
Future<bool> _signIn(WidgetRef ref) async {
  // Every service is resolved up front, before the first await: a successful
  // sign-in flips authStateProvider, AuthGate swaps the guest screen out, and
  // the WidgetRef captured here dies with it. Touching `ref` afterwards throws
  // "Cannot use ref after the widget was disposed" — which the sheet would then
  // report as a failed login even though the user is signed in.
  final auth = ref.read(authServiceProvider);
  final repository = ref.read(budgetRepositoryProvider);
  final analytics = ref.read(analyticsProvider);

  final user = await auth.signInWithGoogle();
  if (user == null) return false; // account picker dismissed

  await repository.upsertProfile(user);
  analytics.loginSucceeded();
  return true;
}

/// Bottom sheet asking the guest to sign in. Returns true if they did.
Future<bool> showAuthPrompt(
  BuildContext context,
  WidgetRef ref, {
  String message = AuthPromptCopy.action,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
    ),
    builder: (sheetContext) => _AuthSheet(message: message, signIn: () => _signIn(ref)),
  );
  return result ?? false;
}

/// Gate for every action that writes data. Signed-in users pass straight
/// through; guests get the prompt and only proceed if they sign in.
Future<bool> ensureSignedIn(BuildContext context, WidgetRef ref) async {
  if (ref.read(currentUserProvider) != null) return true;
  return showAuthPrompt(context, ref);
}

class _AuthSheet extends StatefulWidget {
  const _AuthSheet({required this.message, required this.signIn});

  final String message;
  final Future<bool> Function() signIn;

  @override
  State<_AuthSheet> createState() => _AuthSheetState();
}

class _AuthSheetState extends State<_AuthSheet> {
  bool _busy = false;
  String? _error;

  Future<void> _handle() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final ok = await widget.signIn();
      if (!mounted) return;
      if (ok) {
        Navigator.pop(context, true);
      } else {
        setState(() => _busy = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'Gagal masuk. Coba lagi.\n$e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 10, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              widget.message,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 14),
            const _Bullet('Jatah harian otomatis dari budget kamu'),
            const _Bullet('Hemat hari ini, wallet besok makin besar'),
            const _Bullet('Catat pengeluaran dalam hitungan detik'),
            const SizedBox(height: 18),
            if (_error != null) ...[
              Text(
                _error!,
                style: const TextStyle(color: AppColors.negative, fontSize: 13),
              ),
              const SizedBox(height: 12),
            ],
            FilledButton.icon(
              onPressed: _busy ? null : _handle,
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                  : const Icon(Icons.login),
              label: Text(_busy ? 'Menghubungkan...' : 'Login / Sign Up dengan Google'),
            ),
            const SizedBox(height: 6),
            Center(
              child: TextButton(
                onPressed: _busy ? null : () => Navigator.pop(context, false),
                child: const Text('Nanti saja'),
              ),
            ),
            Center(
              child: Text(
                'Data kamu tersimpan aman di akun Google kamu.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle, size: 19, color: AppColors.seed),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
