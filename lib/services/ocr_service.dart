import 'dart:convert';
import 'dart:typed_data';
import 'package:community_admin/models/ocr_result.dart';
import 'package:community_admin/services/api_client.dart';

/// Gemini-powered OCR. The backend wraps Google Generative Language and
/// normalizes the response shape per type. Images are sent as base64 —
/// no upload-first step needed for OCR.
enum OcrType { invoice, meterReading, idDocument, text }

extension _OcrTypeApi on OcrType {
  String get apiValue {
    switch (this) {
      case OcrType.invoice:
        return 'invoice';
      case OcrType.meterReading:
        return 'meter_reading';
      case OcrType.idDocument:
        return 'id_document';
      case OcrType.text:
        return 'text';
    }
  }
}

class OcrService {
  final ApiClient _api;

  OcrService(this._api);

  Future<Map<String, dynamic>> _extractRaw(
    Uint8List bytes, {
    required String mimeType,
    required OcrType type,
  }) async {
    final response = await _api.post<Map<String, dynamic>>(
      '/ocr/extract',
      data: {
        'image': base64Encode(bytes),
        'mime_type': mimeType,
        'type': type.apiValue,
      },
    );
    return response.data!['data'] as Map<String, dynamic>;
  }

  Future<InvoiceOcrResult> extractInvoice(
    Uint8List bytes, {
    String mimeType = 'image/jpeg',
  }) async {
    final data = await _extractRaw(bytes, mimeType: mimeType, type: OcrType.invoice);
    return InvoiceOcrResult.fromJson(data);
  }

  Future<MeterReadingOcrResult> extractMeterReading(
    Uint8List bytes, {
    String mimeType = 'image/jpeg',
  }) async {
    final data =
        await _extractRaw(bytes, mimeType: mimeType, type: OcrType.meterReading);
    return MeterReadingOcrResult.fromJson(data);
  }

  Future<IdDocumentOcrResult> extractIdDocument(
    Uint8List bytes, {
    String mimeType = 'image/jpeg',
  }) async {
    final data =
        await _extractRaw(bytes, mimeType: mimeType, type: OcrType.idDocument);
    return IdDocumentOcrResult.fromJson(data);
  }

  Future<GenericOcrResult> extractText(
    Uint8List bytes, {
    String mimeType = 'image/jpeg',
  }) async {
    final data = await _extractRaw(bytes, mimeType: mimeType, type: OcrType.text);
    return GenericOcrResult.fromJson(data);
  }
}
