import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme.dart';
import '../providers/app_providers.dart';
import '../widgets/auth_prompt.dart';
import '../widgets/section_card.dart';

/// Account screen. Doubles as the second way into sign-in for guests who
/// dismissed the prompt.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Keluar dari HolSpenD?'),
        content: const Text('Data kamu tetap tersimpan di akun Google.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(authServiceProvider).signOut();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
          children: [
            if (user == null)
              SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const CircleAvatar(
                          radius: 24,
                          backgroundColor: Color(0xFFE9F7F3),
                          child: Icon(Icons.person_outline, color: AppColors.seed),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Belum masuk',
                                style: theme.textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              Text(
                                'Masuk untuk mulai mencatat dan menyimpan datamu.',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () => showAuthPrompt(
                        context,
                        ref,
                        message: AuthPromptCopy.welcome,
                      ),
                      icon: const Icon(Icons.login),
                      label: const Text('Login / Sign Up'),
                    ),
                  ],
                ),
              )
            else
              SectionCard(
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: theme.colorScheme.primaryContainer,
                      backgroundImage: user.photoURL != null
                          ? NetworkImage(user.photoURL!)
                          : null,
                      child: user.photoURL == null
                          ? const Icon(Icons.person)
                          : null,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.displayName ?? 'Teman HolSpenD',
                            style: theme.textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          if (user.email != null)
                            Text(
                              user.email!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 14),
            SectionCard(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.language),
                    title: const Text('Bahasa'),
                    subtitle: const Text('Indonesia'),
                    trailing: Icon(
                      Icons.chevron_right,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    // Indonesian is the only language the app ships. The row is
                    // here because the design calls for it; wiring it up needs
                    // flutter_localizations and every string extracted first.
                    onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Pilihan bahasa segera hadir.'),
                      ),
                    ),
                  ),
                  const ListTile(
                    leading: Icon(Icons.info_outline),
                    title: Text('Tentang HolSpenD'),
                    subtitle: Text(
                      'Daily Wallet: budget dibagi jadi jatah harian, '
                      'sisa hari ini dibawa ke besok.',
                    ),
                  ),
                  if (user != null)
                    ListTile(
                      leading: const Icon(Icons.logout, color: AppColors.negative),
                      title: const Text(
                        'Keluar',
                        style: TextStyle(color: AppColors.negative),
                      ),
                      onTap: () => _signOut(context, ref),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
