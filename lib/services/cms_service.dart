import 'package:community_admin/services/api_client.dart';
import 'package:dio/dio.dart';

/// Single CMS page row from `GET /cms/pages?app=&type=`. Mirrors the
/// shape defined in QA Round 14 plan §D1 (`cms_pages` table).
class CmsPage {
  final String title;
  final String bodyMarkdown;
  final int version;
  final String? publishedAt;

  const CmsPage({
    required this.title,
    required this.bodyMarkdown,
    required this.version,
    this.publishedAt,
  });

  factory CmsPage.fromJson(Map<String, dynamic> json) {
    return CmsPage(
      title: json['title'] as String? ?? '',
      bodyMarkdown: json['body_markdown'] as String? ??
          json['bodyMarkdown'] as String? ??
          '',
      version: (json['version'] as num?)?.toInt() ?? 1,
      publishedAt: json['published_at'] as String? ??
          json['publishedAt'] as String?,
    );
  }
}

/// Thrown when the CMS endpoint can't satisfy a fetch — 404, network
/// error, parse failure. Caller decides the fallback (legal screens
/// fall back to bundled `assets/legal/admin_*.md`).
class CmsUnavailableException implements Exception {
  final String message;
  const CmsUnavailableException(this.message);

  @override
  String toString() => 'CmsUnavailableException: $message';
}

/// Fetches CMS pages for the admin app. The backend `GET /cms/pages`
/// endpoint is part of QA Round 14 D1 (#14-1b) and may not yet be
/// shipped; this service is written to fail clean so callers can
/// fall back to bundled assets without UI thrash.
class CmsService {
  final ApiClient _api;
  CmsService(this._api);

  /// Page types the backend understands.
  static const String typeTerms = 'terms_and_conditions';
  static const String typePrivacy = 'privacy_policy';

  /// Fetch the latest published page for `app` + `type`. Throws
  /// [CmsUnavailableException] on any error so the caller can
  /// degrade gracefully.
  Future<CmsPage> getPage({
    required String app,
    required String type,
  }) async {
    try {
      final res = await _api.get<Map<String, dynamic>>(
        '/cms/pages',
        queryParameters: {'app': app, 'type': type},
      );
      final body = res.data;
      if (body == null) {
        throw const CmsUnavailableException('Empty response');
      }
      // Accept either { data: {...} } envelope or bare object.
      final data = (body['data'] as Map<String, dynamic>?) ?? body;
      return CmsPage.fromJson(data);
    } on DioException catch (e) {
      throw CmsUnavailableException(
        e.response?.statusCode == 404
            ? 'Page not yet published'
            : (e.message ?? 'Network error'),
      );
    } catch (e) {
      throw CmsUnavailableException(e.toString());
    }
  }
}
