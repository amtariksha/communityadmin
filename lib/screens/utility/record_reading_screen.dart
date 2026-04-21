import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:community_admin/providers/service_providers.dart';
import 'package:community_admin/screens/utility/meters_admin_screen.dart';

class RecordReadingScreen extends ConsumerStatefulWidget {
  final String meterId;
  final String meterType;

  const RecordReadingScreen({
    super.key,
    required this.meterId,
    required this.meterType,
  });

  @override
  ConsumerState<RecordReadingScreen> createState() =>
      _RecordReadingScreenState();
}

class _RecordReadingScreenState extends ConsumerState<RecordReadingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _valueController = TextEditingController();
  DateTime _date = DateTime.now();
  bool _submitting = false;

  @override
  void dispose() {
    _valueController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final value = double.tryParse(_valueController.text.trim());
    if (value == null) return;
    setState(() => _submitting = true);
    try {
      await ref.read(utilityServiceProvider).submitReading(
            meterId: widget.meterId,
            readingValue: value,
            readingDate: DateFormat('yyyy-MM-dd').format(_date),
          );
      ref.invalidate(metersAdminProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reading recorded')),
        );
        context.go('/utility');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${_capitalize(widget.meterType)} reading'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _valueController,
              decoration: const InputDecoration(
                labelText: 'Reading value',
                border: OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(
                  decimal: true, signed: false),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Required';
                final num = double.tryParse(v.trim());
                if (num == null) return 'Must be a number';
                if (num < 0) return 'Must be non-negative';
                return null;
              },
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: _pickDate,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Reading date',
                  border: OutlineInputBorder(),
                ),
                child: Text(DateFormat('d MMM yyyy').format(_date)),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              child: _submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save Reading'),
            ),
          ],
        ),
      ),
    );
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
}
