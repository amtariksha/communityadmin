import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:community_admin/providers/service_providers.dart';

final _dateFormat = DateFormat('d MMM yyyy');

final documentsAdminProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final data = await ref.read(documentServiceProvider).getDocuments();
  final list = data['data'] as List<dynamic>? ??
      data['documents'] as List<dynamic>? ??
      [];
  return list.cast<Map<String, dynamic>>();
});

class DocumentsAdminScreen extends ConsumerWidget {
  const DocumentsAdminScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(documentsAdminProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Documents')),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(documentsAdminProvider),
        child: async.when(
          data: (docs) {
            if (docs.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: 100),
                  Icon(Icons.folder_outlined,
                      size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Center(
                    child: Text(
                      'No documents. Upload via the web dashboard.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ),
                ],
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: docs.length,
              itemBuilder: (_, i) =>
                  _DocCard(doc: docs[i]),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('Unable to load: $e',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red)),
            ),
          ),
        ),
      ),
    );
  }
}

class _DocCard extends ConsumerWidget {
  final Map<String, dynamic> doc;
  const _DocCard({required this.doc});

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete document?'),
        content: Text('Remove ${doc['title'] ?? 'this document'}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await ref
          .read(documentServiceProvider)
          .deleteDocument(doc['id'].toString());
      ref.invalidate(documentsAdminProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final title = doc['title']?.toString() ?? 'Document';
    final category = doc['category']?.toString() ?? '';
    final createdAt =
        DateTime.tryParse(doc['created_at']?.toString() ?? '');

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.description),
        title: Text(title,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text([
          category,
          if (createdAt != null) _dateFormat.format(createdAt),
        ].where((e) => e.isNotEmpty).join(' \u00b7 ')),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.red),
          onPressed: () => _delete(context, ref),
        ),
      ),
    );
  }
}
