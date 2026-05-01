import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:community_admin/config/theme.dart';
import 'package:community_admin/config/tokens.dart';
import 'package:community_admin/providers/service_providers.dart';
import 'package:community_admin/services/cms_service.dart';

/// Shared legal-page renderer for Terms & Conditions and Privacy
/// Policy screens. Fetches from the CMS endpoint
/// (`GET /cms/pages?app=admin&type=…`); on failure falls back to a
/// bundled markdown asset and surfaces an inline "Showing offline
/// copy" banner.
///
/// QA Round 14 #14-5c. Until D1 ships the CMS endpoint, every fetch
/// returns 404 and the screen always shows the bundled placeholder.
/// Once D1 lands the live content takes over automatically.
class LegalScreen extends ConsumerStatefulWidget {
  final String title;
  final String cmsPageType;
  final String fallbackAssetPath;

  const LegalScreen({
    super.key,
    required this.title,
    required this.cmsPageType,
    required this.fallbackAssetPath,
  });

  @override
  ConsumerState<LegalScreen> createState() => _LegalScreenState();
}

class _LegalScreenState extends ConsumerState<LegalScreen> {
  String? _markdown;
  bool _isLoading = true;
  bool _showingFallback = false;
  String? _error;

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
      final cms = ref.read(cmsServiceProvider);
      final page = await cms.getPage(
        app: 'admin',
        type: widget.cmsPageType,
      );
      if (!mounted) return;
      setState(() {
        _markdown = page.bodyMarkdown;
        _showingFallback = false;
        _isLoading = false;
      });
    } on CmsUnavailableException {
      // Expected path until D1 #14-1b ships. Fall back to the
      // bundled placeholder and surface an inline banner.
      await _loadFallback();
    } catch (_) {
      await _loadFallback();
    }
  }

  Future<void> _loadFallback() async {
    try {
      final body = await rootBundle.loadString(widget.fallbackAssetPath);
      if (!mounted) return;
      setState(() {
        _markdown = body;
        _showingFallback = true;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _markdown = null;
        _error =
            'Could not load legal content. Please check your connection and try again.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.xxl),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.error_outline,
                            size: 48, color: Colors.grey.shade400),
                        const SizedBox(height: AppSpacing.md),
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: AppSpacing.md),
                        ElevatedButton(
                          onPressed: _load,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    if (_showingFallback) _OfflineBanner(onRetry: _load),
                    Expanded(
                      child: Markdown(
                        data: _markdown ?? '',
                        padding: const EdgeInsets.all(AppSpacing.xl),
                        selectable: true,
                        styleSheet: MarkdownStyleSheet(
                          h1: AppTheme.inter(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            height: 1.3,
                          ),
                          h2: AppTheme.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            height: 1.3,
                          ),
                          p: AppTheme.inter(
                            fontSize: 14,
                            color: AppTheme.textPrimary,
                            height: 1.5,
                          ),
                          a: AppTheme.inter(
                            fontSize: 14,
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}

class _OfflineBanner extends StatelessWidget {
  final VoidCallback onRetry;
  const _OfflineBanner({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      color: AppTheme.warningColor.withValues(alpha: 0.12),
      child: Row(
        children: [
          const Icon(
            Icons.cloud_off_outlined,
            size: 18,
            color: AppTheme.warningColor,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Showing offline copy. Live content not yet published.',
              style: AppTheme.inter(
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            child: Text(
              'Retry',
              style: AppTheme.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.primaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
