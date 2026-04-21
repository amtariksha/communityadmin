import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:community_admin/services/api_client.dart';

/// Object storage direct-upload client (admin app).
///
/// Mirrors the admin web's `useUploadFileToS3`:
/// 1. POST /upload/presigned-url
/// 2. PUT bytes directly to S3 / R2 / MinIO
/// 3. Persist the returned `fileUrl`
class UploadService {
  final ApiClient _api;
  final Dio _s3 = Dio();

  UploadService(this._api);

  Future<UploadResult> upload({
    String? fileName,
    Uint8List? bytes,
    File? file,
    required String contentType,
    ProgressCallback? onProgress,
  }) async {
    assert(bytes != null || file != null,
        'Provide either bytes or file');

    final resolvedBytes = bytes ?? await file!.readAsBytes();
    final resolvedName = fileName ?? _fallbackName(file, contentType);

    final presigned = await requestPresignedUrl(
      fileName: resolvedName,
      contentType: contentType,
    );

    await _s3.put<void>(
      presigned.uploadUrl,
      data: Stream.fromIterable([resolvedBytes]),
      options: Options(
        headers: {
          'Content-Type': contentType,
          Headers.contentLengthHeader: resolvedBytes.length,
        },
      ),
      onSendProgress: onProgress,
    );

    return UploadResult(
      fileUrl: presigned.fileUrl,
      key: presigned.key,
      contentType: contentType,
      sizeBytes: resolvedBytes.length,
    );
  }

  Future<PresignedUpload> requestPresignedUrl({
    required String fileName,
    required String contentType,
  }) async {
    final response = await _api.post<Map<String, dynamic>>(
      '/upload/presigned-url',
      data: {
        'fileName': fileName,
        'contentType': contentType,
      },
    );
    final data = response.data!['data'] as Map<String, dynamic>;
    return PresignedUpload(
      uploadUrl: data['uploadUrl'] as String,
      fileUrl: data['fileUrl'] as String,
      key: data['key'] as String,
    );
  }

  Future<String> requestDownloadUrl(String key) async {
    final response = await _api.post<Map<String, dynamic>>(
      '/upload/download-url',
      data: {'key': key},
    );
    final data = response.data!['data'] as Map<String, dynamic>;
    return data['downloadUrl'] as String;
  }

  Future<void> delete(String key) async {
    await _api.delete<Map<String, dynamic>>('/upload/$key');
  }

  String _fallbackName(File? file, String contentType) {
    if (file != null) {
      final segs = file.path.split(Platform.pathSeparator);
      if (segs.isNotEmpty) return segs.last;
    }
    final ext = _extensionFor(contentType);
    return 'upload_${DateTime.now().millisecondsSinceEpoch}$ext';
  }

  String _extensionFor(String contentType) {
    switch (contentType) {
      case 'image/jpeg':
        return '.jpg';
      case 'image/png':
        return '.png';
      case 'image/webp':
        return '.webp';
      case 'application/pdf':
        return '.pdf';
      case 'text/csv':
        return '.csv';
      case 'text/plain':
        return '.txt';
      case 'application/vnd.ms-excel':
        return '.xls';
      case 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet':
        return '.xlsx';
      default:
        return '';
    }
  }
}

class PresignedUpload {
  final String uploadUrl;
  final String fileUrl;
  final String key;

  const PresignedUpload({
    required this.uploadUrl,
    required this.fileUrl,
    required this.key,
  });
}

class UploadResult {
  final String fileUrl;
  final String key;
  final String contentType;
  final int sizeBytes;

  const UploadResult({
    required this.fileUrl,
    required this.key,
    required this.contentType,
    required this.sizeBytes,
  });
}
