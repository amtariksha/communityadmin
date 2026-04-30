import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:community_admin/providers/service_providers.dart';

/// Live unread-count for the bell badge. The bell widget watches this
/// FutureProvider; refresh by calling `ref.invalidate(unreadNotificationCountProvider)`
/// after mutations (mark-read, push receipt, inbox reload).
final unreadNotificationCountProvider = FutureProvider<int>((ref) async {
  final service = ref.read(notificationServiceProvider);
  return service.getUnreadCount();
});
