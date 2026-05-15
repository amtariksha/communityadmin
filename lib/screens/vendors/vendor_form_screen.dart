import 'package:community_admin/main.dart' show showRootSnackBar;
import 'package:community_admin/models/vendor.dart';
import 'package:community_admin/providers/service_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Create / edit vendor. When [vendorId] is provided we PATCH; else POST.
class VendorFormScreen extends ConsumerStatefulWidget {
  final String? vendorId;
  const VendorFormScreen({super.key, this.vendorId});

  @override
  ConsumerState<VendorFormScreen> createState() => _VendorFormScreenState();
}

class _VendorFormScreenState extends ConsumerState<VendorFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _contactPerson = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _address = TextEditingController();
  final _gstin = TextEditingController();
  final _pan = TextEditingController();
  final _bankName = TextEditingController();
  final _bankBranch = TextEditingController();
  final _bankAccountNumber = TextEditingController();
  final _bankIfsc = TextEditingController();
  final _tdsSection = TextEditingController();
  final _tdsRate = TextEditingController();

  bool _loading = false;
  bool _bootstrapping = false;
  String? _error;

  bool get _isEdit => widget.vendorId != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) _bootstrap();
  }

  Future<void> _bootstrap() async {
    setState(() => _bootstrapping = true);
    try {
      final v = await ref.read(vendorServiceProvider).get(widget.vendorId!);
      _populate(v);
    } catch (e) {
      _error = e.toString();
    }
    if (mounted) setState(() => _bootstrapping = false);
  }

  void _populate(Vendor v) {
    _name.text = v.name;
    _contactPerson.text = v.contactPerson ?? '';
    _phone.text = v.phone ?? '';
    _email.text = v.email ?? '';
    _address.text = v.address ?? '';
    _gstin.text = v.gstin ?? '';
    _pan.text = v.pan ?? '';
    _bankName.text = v.bankName ?? '';
    _bankBranch.text = v.bankBranch ?? '';
    _bankAccountNumber.text = v.bankAccountNumber ?? '';
    _bankIfsc.text = v.bankIfsc ?? '';
    _tdsSection.text = v.tdsSection ?? '';
    _tdsRate.text = v.tdsRate == null ? '' : v.tdsRate.toString();
  }

  @override
  void dispose() {
    for (final c in [
      _name,
      _contactPerson,
      _phone,
      _email,
      _address,
      _gstin,
      _pan,
      _bankName,
      _bankBranch,
      _bankAccountNumber,
      _bankIfsc,
      _tdsSection,
      _tdsRate,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Map<String, dynamic> _buildBody() {
    String? nonEmpty(TextEditingController c) {
      final v = c.text.trim();
      return v.isEmpty ? null : v;
    }

    return <String, dynamic>{
      'name': _name.text.trim(),
      if (nonEmpty(_contactPerson) != null) 'contact_person': nonEmpty(_contactPerson),
      if (nonEmpty(_phone) != null) 'phone': nonEmpty(_phone),
      if (nonEmpty(_email) != null) 'email': nonEmpty(_email),
      if (nonEmpty(_address) != null) 'address': nonEmpty(_address),
      if (nonEmpty(_gstin) != null) 'gstin': nonEmpty(_gstin)!.toUpperCase(),
      if (nonEmpty(_pan) != null) 'pan': nonEmpty(_pan)!.toUpperCase(),
      if (nonEmpty(_bankName) != null) 'bank_name': nonEmpty(_bankName),
      if (nonEmpty(_bankBranch) != null) 'bank_branch': nonEmpty(_bankBranch),
      if (nonEmpty(_bankAccountNumber) != null)
        'bank_account_number': nonEmpty(_bankAccountNumber),
      if (nonEmpty(_bankIfsc) != null) 'bank_ifsc': nonEmpty(_bankIfsc)!.toUpperCase(),
      if (nonEmpty(_tdsSection) != null) 'tds_section': nonEmpty(_tdsSection),
      if (nonEmpty(_tdsRate) != null)
        'tds_rate': num.tryParse(nonEmpty(_tdsRate)!) ?? 0,
    };
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final svc = ref.read(vendorServiceProvider);
      final body = _buildBody();
      if (_isEdit) {
        await svc.update(widget.vendorId!, body);
      } else {
        await svc.create(body);
      }
      if (!mounted) return;
      showRootSnackBar(_isEdit ? 'Vendor updated' : 'Vendor created');
      context.pop(true);
    } catch (e) {
      setState(() => _error = e.toString());
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Edit Vendor' : 'New Vendor')),
      body: _bootstrapping
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  children: [
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(_error!,
                            style: const TextStyle(color: Colors.red)),
                      ),
                    _section('Basic'),
                    _field(_name, 'Name *',
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Name is required'
                            : null),
                    _field(_contactPerson, 'Contact person'),
                    _field(_phone, 'Phone',
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        maxLength: 15),
                    _field(_email, 'Email',
                        keyboardType: TextInputType.emailAddress),
                    _field(_address, 'Address', maxLines: 2),
                    const SizedBox(height: 16),
                    _section('Tax IDs'),
                    _field(_gstin, 'GSTIN',
                        textCapitalization: TextCapitalization.characters,
                        maxLength: 15),
                    _field(_pan, 'PAN',
                        textCapitalization: TextCapitalization.characters,
                        maxLength: 10),
                    const SizedBox(height: 16),
                    _section('Bank details'),
                    _field(_bankName, 'Bank name'),
                    _field(_bankBranch, 'Branch'),
                    _field(_bankAccountNumber, 'Account number',
                        keyboardType: TextInputType.number),
                    _field(_bankIfsc, 'IFSC',
                        textCapitalization: TextCapitalization.characters,
                        maxLength: 11),
                    const SizedBox(height: 16),
                    _section('TDS'),
                    _field(_tdsSection, 'TDS section (e.g. 194C)'),
                    _field(_tdsRate, 'TDS rate (%)',
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true)),
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _save,
                        child: _loading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : Text(_isEdit ? 'Save changes' : 'Create vendor'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _section(String label) => Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 8),
        child: Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Colors.grey.shade600,
            letterSpacing: 0.8,
          ),
        ),
      );

  Widget _field(
    TextEditingController controller,
    String label, {
    TextInputType? keyboardType,
    int maxLines = 1,
    int? maxLength,
    List<TextInputFormatter>? inputFormatters,
    TextCapitalization textCapitalization = TextCapitalization.none,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          counterText: '',
        ),
        keyboardType: keyboardType,
        maxLines: maxLines,
        maxLength: maxLength,
        inputFormatters: inputFormatters,
        textCapitalization: textCapitalization,
        validator: validator,
      ),
    );
  }
}
