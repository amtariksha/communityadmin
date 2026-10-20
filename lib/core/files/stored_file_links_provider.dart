import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:community_admin/core/files/stored_file_links.dart';
import 'package:community_admin/providers/auth_provider.dart';
import 'package:community_admin/providers/service_providers.dart';

/// One [StoredFileLinks] (and its in-memory link cache) per signed-in admin
/// and society, so one session's signed links never outlive it.
final storedFileLinksProvider = Provider<StoredFileLinks>((ref) {
  ref.watch(authStateProvider.select((s) => (s.user?.id, s.selectedTenantId)));
  return StoredFileLinks(ref.read(apiClientProvider));
});
