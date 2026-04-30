import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:community_admin/services/api_client.dart';
import 'package:community_admin/services/auth_service.dart';
import 'package:community_admin/services/dashboard_service.dart';
import 'package:community_admin/services/unit_service.dart';
import 'package:community_admin/services/invoice_service.dart';
import 'package:community_admin/services/receipt_service.dart';
import 'package:community_admin/services/gate_service.dart';
import 'package:community_admin/services/ticket_service.dart';
import 'package:community_admin/services/announcement_service.dart';
import 'package:community_admin/services/staff_service.dart';
import 'package:community_admin/services/approval_service.dart';
import 'package:community_admin/services/amenity_service.dart';
import 'package:community_admin/services/voting_service.dart';
import 'package:community_admin/services/document_service.dart';
import 'package:community_admin/services/utility_service.dart';
import 'package:community_admin/services/upload_service.dart';
import 'package:community_admin/services/ocr_service.dart';
import 'package:community_admin/services/push_service.dart';
import 'package:community_admin/services/notification_service.dart';

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(ref.read(apiClientProvider));
});

final dashboardServiceProvider = Provider<DashboardService>((ref) {
  return DashboardService(ref.read(apiClientProvider));
});

final unitServiceProvider = Provider<UnitService>((ref) {
  return UnitService(ref.read(apiClientProvider));
});

final invoiceServiceProvider = Provider<InvoiceService>((ref) {
  return InvoiceService(ref.read(apiClientProvider));
});

final receiptServiceProvider = Provider<ReceiptService>((ref) {
  return ReceiptService(ref.read(apiClientProvider));
});

final gateServiceProvider = Provider<GateService>((ref) {
  return GateService(ref.read(apiClientProvider));
});

final ticketServiceProvider = Provider<TicketService>((ref) {
  return TicketService(ref.read(apiClientProvider));
});

final announcementServiceProvider = Provider<AnnouncementService>((ref) {
  return AnnouncementService(ref.read(apiClientProvider));
});

final staffServiceProvider = Provider<StaffService>((ref) {
  return StaffService(ref.read(apiClientProvider));
});

final approvalServiceProvider = Provider<ApprovalService>((ref) {
  return ApprovalService(ref.read(apiClientProvider));
});

final amenityServiceProvider = Provider<AmenityService>((ref) {
  return AmenityService(ref.read(apiClientProvider));
});

final votingServiceProvider = Provider<VotingService>((ref) {
  return VotingService(ref.read(apiClientProvider));
});

final documentServiceProvider = Provider<DocumentService>((ref) {
  return DocumentService(ref.read(apiClientProvider));
});

final utilityServiceProvider = Provider<UtilityService>((ref) {
  return UtilityService(ref.read(apiClientProvider));
});

final uploadServiceProvider = Provider<UploadService>((ref) {
  return UploadService(ref.read(apiClientProvider));
});

final ocrServiceProvider = Provider<OcrService>((ref) {
  return OcrService(ref.read(apiClientProvider));
});

final pushServiceProvider = Provider<PushService>((ref) {
  return PushService(ref.read(apiClientProvider));
});

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService(ref.read(apiClientProvider));
});
