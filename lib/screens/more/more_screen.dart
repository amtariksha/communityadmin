import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:community_admin/config/theme.dart';
import 'package:community_admin/providers/auth_provider.dart';

class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final user = authState.user;

    return Scaffold(
      appBar: AppBar(title: const Text('More')),
      body: ListView(
        children: [
          // User info header
          Container(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppTheme.primaryColor,
                  child: Text(
                    (user?.name ?? 'A')[0].toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.name ?? 'Admin',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        user?.phone ?? '',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          _MenuItem(
            icon: Icons.people,
            title: 'Member Directory',
            onTap: () => context.go('/member-directory'),
          ),
          _MenuItem(
            icon: Icons.support_agent,
            title: 'Tickets',
            onTap: () => _showComingSoon(context),
          ),
          _MenuItem(
            icon: Icons.campaign,
            title: 'Announcements',
            onTap: () => _showComingSoon(context),
          ),
          _MenuItem(
            icon: Icons.badge,
            title: 'Staff',
            onTap: () => _showComingSoon(context),
          ),
          _MenuItem(
            icon: Icons.assessment,
            title: 'Reports',
            onTap: () => _showComingSoon(context),
          ),
          _MenuItem(
            icon: Icons.settings,
            title: 'Settings',
            onTap: () => _showComingSoon(context),
          ),
          _MenuItem(
            icon: Icons.info_outline,
            title: 'About',
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: 'CommunityOS Admin',
                applicationVersion: '1.0.0',
                applicationLegalese: 'Amtariksha Tech Pvt Ltd',
              );
            },
          ),
          const Divider(height: 1),
          _MenuItem(
            icon: Icons.swap_horiz,
            title: 'Switch Society',
            onTap: () => context.go('/select-society'),
          ),
          _MenuItem(
            icon: Icons.logout,
            title: 'Logout',
            color: AppTheme.errorColor,
            onTap: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Logout'),
                  content: const Text('Are you sure you want to logout?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Logout'),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                await ref.read(authStateProvider.notifier).logout();
              }
            },
          ),
        ],
      ),
    );
  }

  void _showComingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Coming soon')),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Color? color;

  const _MenuItem({
    required this.icon,
    required this.title,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: color ?? Colors.grey.shade700),
      title: Text(
        title,
        style: TextStyle(color: color),
      ),
      trailing: Icon(
        Icons.chevron_right,
        color: Colors.grey.shade400,
      ),
      onTap: onTap,
    );
  }
}
