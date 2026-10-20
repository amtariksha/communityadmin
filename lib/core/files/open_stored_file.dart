import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:community_admin/core/files/stored_file_links.dart';
import 'package:community_admin/core/files/stored_file_links_provider.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens a stored file (a PDF, a photo) outside the app through a signed
/// link. [name] is the file's name when known; it becomes the saved file's
/// name. Tells the user when the file is not available or cannot be opened.
Future<void> openStoredFile(
  BuildContext context,
  String? url, {
  String? name,
  StoredFileDisposition disposition = StoredFileDisposition.inline,
}) async {
  final links = ProviderScope.containerOf(
    context,
    listen: false,
  ).read(storedFileLinksProvider);
  final messenger = ScaffoldMessenger.maybeOf(context);
  void tell(String message) =>
      messenger?.showSnackBar(SnackBar(content: Text(message)));

  final link = await links.resolve(
    url,
    disposition: disposition,
    fileName: name,
  );
  final uri = link == null ? null : Uri.tryParse(link);
  if (uri == null) {
    tell('This file is not available');
    return;
  }
  try {
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened) tell('Could not open this file');
  } catch (e) {
    debugPrint('openStoredFile: launch failed (${e.runtimeType})');
    tell('Could not open this file');
  }
}
