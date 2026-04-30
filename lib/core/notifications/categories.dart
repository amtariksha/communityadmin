/// Notification category contract — admin-mobile slice of
/// `communityos/packages/shared/src/notifications.ts`.
///
/// Single source of truth for the {category → actions, default route}
/// relationship for the admin app's audience: committee members and
/// facility managers. The 7 categories here cover:
///   - Operational escalations (committee_escalation, ticket_escalation)
///   - Approvals (approval_needed, tenant_onboarding_pending)
///   - Information (announcement, financial_alert, membership_change)
///   - Reports (monthly_report)
///
/// `urgent_announcement` is NOT a separate category — the existing
/// `announcement` category carries an `urgency='urgent'` flag that the
/// backend uses to bypass quiet-hours / muted-categories filtering.
///
/// If a category is renamed in the TS contract, this file MUST be
/// updated in lockstep — otherwise the lookup at FCM tap time falls
/// through to the legacy-type shim and the user sees a generic
/// "open app" tap with no actions.
library;

// ---------------------------------------------------------------------------
// Action shape
// ---------------------------------------------------------------------------

class NotificationActionInput {
  final String placeholder;
  final int maxLength;

  const NotificationActionInput({
    required this.placeholder,
    required this.maxLength,
  });
}

/// One button on a notification.
///
/// `foreground=true` means tapping the action launches the host app;
/// `false` runs a silent background API call via `action_dispatcher`.
class NotificationAction {
  final String id;
  final String label;
  final bool destructive;
  final bool foreground;
  final bool authRequired;
  final bool requiresBiometric;
  final NotificationActionInput? inputPrompt;

  const NotificationAction({
    required this.id,
    required this.label,
    required this.foreground,
    required this.authRequired,
    this.destructive = false,
    this.requiresBiometric = false,
    this.inputPrompt,
  });
}

// ---------------------------------------------------------------------------
// Catalog descriptor
// ---------------------------------------------------------------------------

class NotificationCategoryDescriptor {
  final String id;
  final List<NotificationAction> actions;

  /// `:entity_id` placeholder gets interpolated from `data.entity_id`
  /// at tap time. Routes are relative to the app's root navigator.
  final String defaultRoute;

  /// `'urgent'` bypasses muted-categories + quiet-hours filtering on
  /// the backend send path (informational on client; backend gate).
  final String urgency;

  const NotificationCategoryDescriptor({
    required this.id,
    required this.actions,
    required this.defaultRoute,
    this.urgency = 'normal',
  });
}

// ---------------------------------------------------------------------------
// Action helpers
// ---------------------------------------------------------------------------

NotificationAction _viewAction([String label = 'View']) =>
    NotificationAction(
      id: 'view',
      label: label,
      foreground: true,
      authRequired: true,
    );

// ---------------------------------------------------------------------------
// Catalog (admin-only entries)
// ---------------------------------------------------------------------------

/// Admin-app catalog. Mirrors the TS `NOTIFICATION_CATEGORIES` map
/// filtered to entries with `audience` containing
/// `'committee_member'` or `'community_admin'`.
final Map<String, NotificationCategoryDescriptor> kAdminCategories = {
  'committee_escalation': NotificationCategoryDescriptor(
    id: 'committee_escalation',
    actions: [
      _viewAction(),
      const NotificationAction(
        id: 'acknowledge',
        label: 'Acknowledge',
        foreground: false,
        authRequired: true,
      ),
    ],
    defaultRoute: '/tickets/:entity_id',
  ),
  'approval_needed': NotificationCategoryDescriptor(
    id: 'approval_needed',
    actions: [
      const NotificationAction(
        id: 'approve',
        label: 'Approve',
        foreground: false,
        authRequired: true,
        requiresBiometric: true,
      ),
      const NotificationAction(
        id: 'reject',
        label: 'Reject',
        foreground: false,
        authRequired: true,
        destructive: true,
        requiresBiometric: true,
      ),
      _viewAction(),
    ],
    defaultRoute: '/approvals',
  ),
  'announcement': NotificationCategoryDescriptor(
    id: 'announcement',
    actions: [_viewAction()],
    defaultRoute: '/announcements',
  ),
  'ticket_escalation': NotificationCategoryDescriptor(
    id: 'ticket_escalation',
    actions: [
      const NotificationAction(
        id: 'assign',
        label: 'Assign',
        foreground: true,
        authRequired: true,
      ),
      _viewAction(),
    ],
    defaultRoute: '/tickets/:entity_id',
  ),
  'tenant_onboarding_pending': NotificationCategoryDescriptor(
    id: 'tenant_onboarding_pending',
    actions: [
      const NotificationAction(
        id: 'approve',
        label: 'Approve',
        foreground: false,
        authRequired: true,
        requiresBiometric: true,
      ),
      const NotificationAction(
        id: 'reject',
        label: 'Reject',
        foreground: false,
        authRequired: true,
        destructive: true,
        requiresBiometric: true,
      ),
      _viewAction(),
    ],
    defaultRoute: '/approvals',
  ),
  'financial_alert': NotificationCategoryDescriptor(
    id: 'financial_alert',
    actions: [_viewAction()],
    defaultRoute: '/finance',
  ),
  'membership_change': NotificationCategoryDescriptor(
    id: 'membership_change',
    actions: [_viewAction()],
    defaultRoute: '/units',
  ),
  'monthly_report': NotificationCategoryDescriptor(
    id: 'monthly_report',
    actions: [
      const NotificationAction(
        id: 'download',
        label: 'Download PDF',
        foreground: true,
        authRequired: true,
      ),
      _viewAction('View Report'),
    ],
    defaultRoute: '/notifications',
  ),
};

// ---------------------------------------------------------------------------
// Legacy notification_type → category
// ---------------------------------------------------------------------------

/// Maps backend's legacy `notification_type` strings (still emitted
/// alongside `category` for back-compat with older inbox rows) to the
/// new category id used by the catalog above.
const Map<String, String> kLegacyTypeToCategory = {
  'ticket': 'committee_escalation',
  'ticket_update': 'committee_escalation',
  'approval': 'approval_needed',
  'approval_needed': 'approval_needed',
  'leave': 'approval_needed',
  'announcement': 'announcement',
  'monthly_report': 'monthly_report',
  'membership_change': 'membership_change',
  'financial_alert': 'financial_alert',
  'tenant_onboarding': 'tenant_onboarding_pending',
};

/// Best-effort category lookup. Resolves `data.category` first
/// (Phase 1+ payloads), then falls back to `data.notification_type`
/// (legacy installs), finally to `'announcement'` so we always have a
/// catalog entry to look up actions / routes against.
String resolveCategory(Map<String, dynamic> data) {
  final cat = (data['category'] ?? '').toString();
  if (kAdminCategories.containsKey(cat)) return cat;
  final type = (data['notification_type'] ?? data['type'] ?? '').toString();
  return kLegacyTypeToCategory[type] ?? 'announcement';
}

/// Compute the deep-link route for a `data` payload. Substitutes
/// `:entity_id` with `data.entity_id`; if entity_id is missing falls
/// back to the un-substituted route's parent path so the app at least
/// opens a list view.
String? routeForData(Map<String, dynamic> data) {
  final categoryId = resolveCategory(data);
  final descriptor = kAdminCategories[categoryId];
  if (descriptor == null) return null;
  final entityId = (data['entity_id'] ?? '').toString();
  final route = descriptor.defaultRoute;
  if (route.contains(':entity_id')) {
    if (entityId.isEmpty) {
      return route.replaceFirst('/:entity_id', '');
    }
    return route.replaceFirst(':entity_id', entityId);
  }
  return route;
}
