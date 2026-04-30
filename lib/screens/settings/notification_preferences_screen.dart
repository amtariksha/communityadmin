import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:community_admin/config/theme.dart';
import 'package:community_admin/core/notifications/categories.dart';
import 'package:community_admin/providers/service_providers.dart';
import 'package:community_admin/services/notification_service.dart';

/// Notification preferences for admin / committee members.
///
/// Backend stores these on the user's `notification_settings` jsonb
/// column; the server-side filter at FCM send time honours mutes +
/// quiet hours (urgent notifications bypass both).
///
/// Layout:
///   - Master toggles: Push, Email
///   - Quiet hours card: enable / start / end (24-hour pickers)
///   - Per-category mute list (one switch per admin category)
///
/// All updates batch into a single `PATCH
/// /users/me/notification-settings` on Save — sticky bottom save button.
class NotificationPreferencesScreen extends ConsumerStatefulWidget {
  const NotificationPreferencesScreen({super.key});

  @override
  ConsumerState<NotificationPreferencesScreen> createState() =>
      _NotificationPreferencesScreenState();
}

class _NotificationPreferencesScreenState
    extends ConsumerState<NotificationPreferencesScreen> {
  NotificationPreferences? _prefs;
  bool _isLoading = true;
  String? _error;
  bool _saving = false;
  bool _dirty = false;

  bool _quietEnabled = false;
  TimeOfDay _quietStart = const TimeOfDay(hour: 22, minute: 0);
  TimeOfDay _quietEnd = const TimeOfDay(hour: 7, minute: 0);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final svc = ref.read(notificationServiceProvider);
      final p = await svc.getPreferences();
      if (!mounted) return;
      setState(() {
        _prefs = p;
        _quietEnabled = p.hasQuietHours;
        if (p.quietStart != null) {
          _quietStart = _parseTime(p.quietStart!) ?? _quietStart;
        }
        if (p.quietEnd != null) {
          _quietEnd = _parseTime(p.quietEnd!) ?? _quietEnd;
        }
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  TimeOfDay? _parseTime(String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return TimeOfDay(hour: h, minute: m);
  }

  String _formatTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _pickTime({required bool start}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: start ? _quietStart : _quietEnd,
    );
    if (picked == null) return;
    setState(() {
      if (start) {
        _quietStart = picked;
      } else {
        _quietEnd = picked;
      }
      _dirty = true;
    });
  }

  void _setMaster({bool? push, bool? email}) {
    final p = _prefs!;
    setState(() {
      _prefs = p.copyWith(
        pushEnabled: push,
        emailEnabled: email,
      );
      _dirty = true;
    });
  }

  void _toggleMute(String categoryId, bool muted) {
    final p = _prefs!;
    final next = List<String>.from(p.mutedCategories);
    if (muted) {
      if (!next.contains(categoryId)) next.add(categoryId);
    } else {
      next.remove(categoryId);
    }
    setState(() {
      _prefs = p.copyWith(mutedCategories: next);
      _dirty = true;
    });
  }

  Future<void> _save() async {
    final p = _prefs!;
    setState(() => _saving = true);
    try {
      final next = p.copyWith(
        quietStart: _quietEnabled ? _formatTime(_quietStart) : null,
        quietEnd: _quietEnabled ? _formatTime(_quietEnd) : null,
        clearQuietHours: !_quietEnabled,
      );
      final svc = ref.read(notificationServiceProvider);
      final saved = await svc.updatePreferences(next);
      if (!mounted) return;
      setState(() {
        _prefs = saved;
        _dirty = false;
        _saving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preferences saved')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not save: $e'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notification preferences')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline,
                          size: 48, color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      Text(_error!),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _load,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _content(),
      bottomNavigationBar: _isLoading || _error != null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: !_dirty || _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(_dirty ? 'Save changes' : 'No changes'),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _content() {
    final p = _prefs!;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        _sectionHeader('Master toggles'),
        _ToggleTile(
          icon: '📱',
          label: 'Push notifications',
          subtitle: 'Show alerts on this device',
          value: p.pushEnabled,
          onChanged: (v) => _setMaster(push: v),
        ),
        _ToggleTile(
          icon: '✉️',
          label: 'Email notifications',
          subtitle: 'Receive emailed copies',
          value: p.emailEnabled,
          onChanged: (v) => _setMaster(email: v),
        ),
        const SizedBox(height: 20),
        _sectionHeader('Quiet hours'),
        _ToggleTile(
          icon: '🌙',
          label: 'Mute during quiet hours',
          subtitle: _quietEnabled
              ? 'From ${_formatTime(_quietStart)} to ${_formatTime(_quietEnd)}'
              : 'Always on',
          value: _quietEnabled,
          onChanged: (v) => setState(() {
            _quietEnabled = v;
            _dirty = true;
          }),
        ),
        if (_quietEnabled)
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _TimeButton(
                    label: 'Start',
                    time: _formatTime(_quietStart),
                    onTap: () => _pickTime(start: true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _TimeButton(
                    label: 'End',
                    time: _formatTime(_quietEnd),
                    onTap: () => _pickTime(start: false),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 20),
        _sectionHeader('Mute categories'),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            "Muted categories don't fire push notifications, but still "
            'land in your inbox. Urgent notifications bypass mutes.',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade700,
              height: 1.4,
            ),
          ),
        ),
        const SizedBox(height: 8),
        for (final descriptor in kAdminCategories.values)
          _ToggleTile(
            icon: _categoryEmoji(descriptor.id),
            label: _categoryLabel(descriptor.id),
            subtitle: 'Mute ${descriptor.id.replaceAll('_', ' ')}',
            value: !p.mutedCategories.contains(descriptor.id),
            onChanged: (v) => _toggleMute(descriptor.id, !v),
          ),
      ],
    );
  }

  Widget _sectionHeader(String label) => Padding(
        padding: const EdgeInsets.only(bottom: 8, top: 4),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Colors.grey.shade700,
          ),
        ),
      );

  String _categoryLabel(String id) {
    switch (id) {
      case 'committee_escalation':
        return 'Committee escalations';
      case 'approval_needed':
        return 'Approvals';
      case 'announcement':
        return 'Announcements';
      case 'ticket_escalation':
        return 'Ticket escalations';
      case 'tenant_onboarding_pending':
        return 'Tenant onboarding';
      case 'financial_alert':
        return 'Financial alerts';
      case 'membership_change':
        return 'Membership changes';
      case 'monthly_report':
        return 'Monthly reports';
      default:
        return id;
    }
  }

  String _categoryEmoji(String id) {
    switch (id) {
      case 'committee_escalation':
      case 'ticket_escalation':
        return '🎫';
      case 'approval_needed':
      case 'tenant_onboarding_pending':
        return '✅';
      case 'announcement':
        return '📢';
      case 'financial_alert':
        return '💰';
      case 'membership_change':
        return '👥';
      case 'monthly_report':
        return '📊';
      default:
        return '🔔';
    }
  }
}

class _ToggleTile extends StatelessWidget {
  final String icon;
  final String label;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Text(icon, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: value,
              onChanged: onChanged,
              activeTrackColor: AppTheme.primaryColor,
            ),
          ],
        ),
      ),
    );
  }
}

class _TimeButton extends StatelessWidget {
  final String label;
  final String time;
  final VoidCallback onTap;

  const _TimeButton({
    required this.label,
    required this.time,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 2),
            Text(
              time,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTheme.primaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
