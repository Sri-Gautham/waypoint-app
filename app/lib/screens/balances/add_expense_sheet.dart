import 'package:flutter/material.dart';

import '../../models/charge.dart';
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
  late String _payer = widget.participants.first;
  final Set<String> _splitWith = {};
  ChargeCategory _category = ChargeCategory.food;

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

  void _submit() {
    final description = _descriptionController.text.trim();
    final amount = double.tryParse(_amountController.text.trim());
    if (description.isEmpty || amount == null || amount <= 0 || _splitWith.isEmpty) return;

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
