import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:community_admin/config/theme.dart';
import 'package:community_admin/providers/auth_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStateProvider);
    final user = auth.user;
    final society = user?.societies
        .where((s) => s.id == auth.selectedTenantId)
        .firstOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Society',
                      style: TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 15)),
                  const SizedBox(height: 8),
                  _Kv('Name', society?.name ?? '\u2014'),
                  _Kv('Role', society?.role ?? '\u2014'),
                  _Kv('Tenant ID', auth.selectedTenantId ?? '\u2014'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Account',
                      style: TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 15)),
                  const SizedBox(height: 8),
                  _Kv('Name', user?.name ?? '\u2014'),
                  _Kv('Phone', user?.phone ?? '\u2014'),
                  if (user?.email != null) _Kv('Email', user!.email!),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.notifications_outlined,
                  color: AppTheme.primaryColor),
              title: const Text('Notification preferences'),
              subtitle: const Text(
                  'Mute categories, quiet hours, push & email toggles'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/settings/notifications'),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.description_outlined,
                      color: AppTheme.primaryColor),
                  title: const Text('Terms & Conditions'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/legal/terms'),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(Icons.privacy_tip_outlined,
                      color: AppTheme.primaryColor),
                  title: const Text('Privacy Policy'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/legal/privacy'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Card(
            color: AppTheme.primaryColor.withValues(alpha: 0.04),
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Advanced settings (gates, roles, compliance, payment gateway) live in the web dashboard. This screen surfaces the read-only view relevant on mobile.',
                style: TextStyle(fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Kv extends StatelessWidget {
  final String label;
  final String value;
  const _Kv(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
