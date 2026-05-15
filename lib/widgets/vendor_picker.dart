import 'package:community_admin/models/vendor.dart';
import 'package:community_admin/providers/service_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Async dropdown of active vendors. Used by the bill form to pick
/// the supplier. Includes a refresh affordance so a newly-created
/// vendor surfaces without recreating the picker.
class VendorPicker extends ConsumerStatefulWidget {
  final String? selectedId;
  final ValueChanged<Vendor?> onChanged;
  final String? Function(String?)? validator;

  const VendorPicker({
    super.key,
    required this.onChanged,
    this.selectedId,
    this.validator,
  });

  @override
  ConsumerState<VendorPicker> createState() => _VendorPickerState();
}

class _VendorPickerState extends ConsumerState<VendorPicker> {
  List<Vendor> _vendors = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await ref
          .read(vendorServiceProvider)
          .list(isActive: true, limit: 200);
      if (!mounted) return;
      setState(() {
        _vendors = res.items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2)),
            SizedBox(width: 12),
            Text('Loading vendors…'),
          ],
        ),
      );
    }
    if (_error != null) {
      return InkWell(
        onTap: _load,
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Text('Could not load vendors — tap to retry',
              style: TextStyle(color: Colors.red)),
        ),
      );
    }

    Vendor? selected;
    if (widget.selectedId != null) {
      for (final v in _vendors) {
        if (v.id == widget.selectedId) {
          selected = v;
          break;
        }
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<Vendor>(
        // ignore: deprecated_member_use
        value: selected,
        isExpanded: true,
        decoration: const InputDecoration(
          labelText: 'Vendor *',
          isDense: true,
        ),
        items: _vendors
            .map(
              (v) => DropdownMenuItem<Vendor>(
                value: v,
                child: Text(v.name, overflow: TextOverflow.ellipsis),
              ),
            )
            .toList(),
        onChanged: widget.onChanged,
        validator: widget.validator == null
            ? null
            : (v) => widget.validator!(v?.id),
      ),
    );
  }
}
