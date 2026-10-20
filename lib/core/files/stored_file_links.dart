import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:community_admin/services/api_client.dart';

/// How the signed link asks the browser / viewer to treat the file.
enum StoredFileDisposition { inline, attachment }

/// Short-lived signed links for files kept in the society's private bucket.
///
/// The bucket refuses an anonymous GET of a stored file's raw URL
/// (`photo_url`, `image_url`, `logo_url`, ...), so everything that shows or
/// opens one asks `POST /upload/download-url` for a signed link first.
/// Links are cached in memory until shortly before they expire, and
/// concurrent requests for the same file share one call.
///
/// Whenever the server does not sign — an external link, an older API
/// without the route, offline — the raw URL is used as the app did before.
class StoredFileLinks {
  StoredFileLinks(this._api, {DateTime Function()? clock})
    : _now = clock ?? DateTime.now;

  static const _path = '/upload/download-url';
  static const _expiryMargin = Duration(minutes: 5);
  static const _signedTtlWithoutExpiry = Duration(minutes: 45);
  static const _notOursTtl = Duration(minutes: 45);
  static const _unavailableTtl = Duration(minutes: 5);
  static const _fallbackTtl = Duration(minutes: 1);

  final ApiClient _api;
  final DateTime Function() _now;
  final Map<String, _CachedLink> _cache = {};
  final Map<String, Future<String?>> _inFlight = {};

  /// Only absolute http(s) URLs are ever sent to the server; `data:`,
  /// `file:`, asset and relative paths are used as they are.
  static bool isRemote(String url) {
    final uri = Uri.tryParse(url);
    return uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty;
  }

  /// The URL to load for [rawUrl]: a signed link, or [rawUrl] itself when
  /// the server does not sign it. Null when there is nothing to show —
  /// [rawUrl] is empty, or the file is not available to this user.
  ///
  /// Answers known without a request (cache hits, non-http values) come
  /// back as a [SynchronousFuture] so a `FutureBuilder` paints them in the
  /// first frame instead of flashing its placeholder.
  Future<String?> resolve(
    String? rawUrl, {
    StoredFileDisposition disposition = StoredFileDisposition.inline,
    String? fileName,
  }) {
    final url = rawUrl?.trim() ?? '';
    if (url.isEmpty) return SynchronousFuture(null);
    if (!isRemote(url)) return SynchronousFuture(url);

    final name = fileName?.trim();
    final key = '${disposition.name}|${name ?? ''}|$url';
    final cached = _cache[key];
    if (cached != null && cached.validUntil.isAfter(_now())) {
      return SynchronousFuture(cached.link);
    }
    // A block body: `=> _inFlight.remove(key)` would return this very
    // future to whenComplete, which would then wait on itself forever.
    return _inFlight[key] ??= _fetch(key, url, disposition, name).whenComplete(
      () {
        _inFlight.remove(key);
      },
    );
  }

  Future<String?> _fetch(
    String key,
    String url,
    StoredFileDisposition disposition,
    String? fileName,
  ) async {
    final outcome = await _request(url, disposition, fileName);
    _cache[key] = outcome;
    return outcome.link;
  }

  Future<_CachedLink> _request(
    String url,
    StoredFileDisposition disposition,
    String? fileName,
  ) async {
    try {
      final res = await _api.post<Map<String, dynamic>>(
        _path,
        data: {
          'file_url': url,
          'disposition': disposition.name,
          if (fileName != null && fileName.isNotEmpty) 'file_name': fileName,
        },
      );
      final data = res.data?['data'];
      final link = data is Map ? data['downloadUrl'] : null;
      if (link is! String || link.isEmpty) return _fallback(url);
      return _CachedLink(link, _signedValidUntil(data['expiresAt']));
    } on DioException catch (e) {
      return _onRefused(url, e.response);
    } catch (e) {
      debugPrint('StoredFileLinks: link request failed (${e.runtimeType})');
      return _fallback(url);
    }
  }

  _CachedLink _onRefused(String url, Response<dynamic>? response) {
    final status = response?.statusCode;
    final body = response?.data;
    final code = body is Map ? body['code'] : null;
    if (status == 404 && code == 'file_not_found') {
      return _CachedLink(null, _now().add(_unavailableTtl));
    }
    if (status == 400 && code == 'file_url_not_ours') {
      return _CachedLink(url, _now().add(_notOursTtl));
    }
    return _fallback(url);
  }

  _CachedLink _fallback(String url) =>
      _CachedLink(url, _now().add(_fallbackTtl));

  DateTime _signedValidUntil(Object? expiresAt) {
    final expiry = expiresAt is String ? DateTime.tryParse(expiresAt) : null;
    if (expiry == null) return _now().add(_signedTtlWithoutExpiry);
    return expiry.subtract(_expiryMargin);
  }
}

class _CachedLink {
  final String? link;
  final DateTime validUntil;

  const _CachedLink(this.link, this.validUntil);
}
