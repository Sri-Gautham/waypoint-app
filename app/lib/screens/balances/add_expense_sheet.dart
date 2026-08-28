import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/charge.dart';
import '../../services/receipt_scanner_service.dart';
import '../../theme/app_colors.dart';

/// A form for logging a new expense against a trip. Returns the new
/// [Charge] via [Navigator.pop], or null if cancelled.
class AddExpenseSheet extends StatefulWidget {
  const AddExpenseSheet({super.key, required this.tripId, required this.participants});

  final String tripId;

  /// Everyone who can be picked as payer or split participant: 'You' plus
  /// the trip's members.
  final List<String> participants;

  @override
  State<AddExpenseSheet> createState() => _AddExpenseSheetState();
}

class _AddExpenseSheetState extends State<AddExpenseSheet> {
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  final _picker = ImagePicker();
  late String _payer = widget.participants.first;
  final Set<String> _splitWith = {};
  ChargeCategory _category = ChargeCategory.food;
  File? _receiptImage;
  bool _scanning = false;

  // Guards against a second Navigator.pop() firing (e.g. a fast
  // double-tap landing before the sheet's closing transition removes the
  // button from the hit-test tree) — that leaves a stray route/barrier
  // behind since there's nothing left to legitimately pop a second time.
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    _splitWith.addAll(widget.participants);
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _scanReceipt() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: AppColors.accent),
              title: const Text('Choose from library'),
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined, color: AppColors.accent),
              title: const Text('Take a photo'),
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    final picked = await _picker.pickImage(source: source, maxWidth: 1600, imageQuality: 85);
    if (picked == null || !mounted) return;

    final image = File(picked.path);
    setState(() {
      _receiptImage = image;
      _scanning = true;
    });

    double? total;
    try {
      total = await ReceiptScannerService.instance.scanTotal(image);
    } catch (_) {
      total = null;
    }
    if (!mounted) return;
    setState(() => _scanning = false);

    if (total != null) {
      _amountController.text = total.toStringAsFixed(2);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't read an amount from that receipt — enter it manually.")),
      );
    }
  }

  void _submit() {
    if (_submitted) return;
    final description = _descriptionController.text.trim();
    final amount = double.tryParse(_amountController.text.trim());
    if (description.isEmpty || amount == null || amount <= 0 || _splitWith.isEmpty) return;

    _submitted = true;
    final split = {_payer, ..._splitWith}.toList();
    final charge = Charge(
      id: 'c-${DateTime.now().microsecondsSinceEpoch}',
      tripId: widget.tripId,
      payer: _payer,
      amount: amount,
      description: description,
      category: _category,
      date: 'Just now',
      splitWith: split,
      receiptImage: _receiptImage,
    );
    Navigator.of(context).pop(charge);
  }

  Widget _categoryChip(ChargeCategory category, IconData icon, String label) {
    final selected = _category == category;
    return ChoiceChip(
      label: Text(label),
      avatar: Icon(icon, size: 16, color: selected ? Colors.white : AppColors.textSecondary),
      selected: selected,
      onSelected: (_) => setState(() => _category = category),
      selectedColor: AppColors.accent,
      labelStyle: TextStyle(color: selected ? Colors.white : AppColors.textPrimary, fontSize: 12.5),
      backgroundColor: AppColors.accentTint,
      side: BorderSide.none,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Add expense', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.accentTint, borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  if (_receiptImage != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(_receiptImage!, width: 40, height: 40, fit: BoxFit.cover),
                    )
                  else
                    const Icon(Icons.document_scanner_outlined, color: AppColors.accent, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _receiptImage == null ? 'Scan a receipt' : (_scanning ? 'Reading receipt…' : 'Amount filled from receipt'),
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                    ),
                  ),
                  OutlinedButton(
                    onPressed: _scanning ? null : _scanReceipt,
                    style: OutlinedButton.styleFrom(
                      minimumSize: Size.zero,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                      foregroundColor: AppColors.accent,
                      side: BorderSide.none,
                      backgroundColor: Colors.white,
                      textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                    ),
                    child: _scanning
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(_receiptImage == null ? 'Scan' : 'Retake'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(labelText: 'Description', hintText: 'Groceries'),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Amount', prefixText: '\$ '),
            ),
            const SizedBox(height: 18),
            const Text('CATEGORY', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary, letterSpacing: 0.4)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _categoryChip(ChargeCategory.food, Icons.restaurant_outlined, 'Food'),
                _categoryChip(ChargeCategory.transport, Icons.directions_car_outlined, 'Transport'),
                _categoryChip(ChargeCategory.lodging, Icons.home_outlined, 'Lodging'),
                _categoryChip(ChargeCategory.activity, Icons.local_activity_outlined, 'Activity'),
              ],
            ),
            const SizedBox(height: 18),
            const Text('PAID BY', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary, letterSpacing: 0.4)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final person in widget.participants)
                  ChoiceChip(
                    label: Text(person),
                    selected: _payer == person,
                    onSelected: (_) => setState(() => _payer = person),
                    selectedColor: AppColors.accent,
                    labelStyle: TextStyle(color: _payer == person ? Colors.white : AppColors.textPrimary, fontSize: 12.5),
                    backgroundColor: AppColors.accentTint,
                    side: BorderSide.none,
                  ),
              ],
            ),
            const SizedBox(height: 18),
            const Text('SPLIT WITH', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary, letterSpacing: 0.4)),
            const SizedBox(height: 4),
            for (final person in widget.participants)
              CheckboxListTile(
                value: _splitWith.contains(person),
                onChanged: (checked) {
                  setState(() {
                    if (checked ?? false) {
                      _splitWith.add(person);
                    } else {
                      _splitWith.remove(person);
                    }
                  });
                },
                title: Text(person, style: const TextStyle(fontSize: 13.5, color: AppColors.textPrimary)),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                dense: true,
                activeColor: AppColors.accent,
              ),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _submit, child: const Text('Add expense')),
          ],
        ),
      ),
    );
  }
}
