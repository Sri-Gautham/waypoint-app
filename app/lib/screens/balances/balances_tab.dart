import 'dart:io';

import 'package:flutter/material.dart';

import '../../models/charge.dart';
import '../../models/trip.dart';
import '../../state/app_data.dart';
import '../../theme/app_colors.dart';
import '../../utils/balance_calculator.dart';
import 'add_expense_sheet.dart';
import 'balances_by_person_screen.dart';

class BalancesTab extends StatefulWidget {
  const BalancesTab({super.key});

  @override
  State<BalancesTab> createState() => _BalancesTabState();
}

class _BalancesTabState extends State<BalancesTab> {
  final Set<String> _expandedTripIds = {};
  TripStatus _filter = TripStatus.upcoming;

  // The trip card's own "Add expense" trigger shares its label text with
  // the sheet's title AND its submit button — three "Add expense" text
  // widgets can be live in the tree at once while a sheet is open. This
  // guard makes a second _addExpense call (whatever triggers it — a fast
  // double-tap before the sheet's barrier engages, or a mistargeted tap)
  // a no-op instead of stacking a second sheet on top of the first.
  bool _addingExpense = false;

  double _paidSoFar(AppData appData, String memberName) {
    return appData.payments.where((p) => p.memberName == memberName).fold(0.0, (sum, p) => sum + p.amount);
  }

  Future<void> _addExpense(Trip trip) async {
    if (_addingExpense) return;
    _addingExpense = true;
    try {
      final participants = ['You', ...trip.members.map((m) => m.name)];
      final charge = await showModalBottomSheet<Charge>(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
        builder: (_) => AddExpenseSheet(tripId: trip.id, participants: participants),
      );
      if (charge == null || !mounted) return;
      AppDataScope.of(context).addCharge(trip.id, charge);
    } finally {
      _addingExpense = false;
    }
  }

  void _openBalancesByPerson() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const BalancesByPersonScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appData = AppDataScope.of(context);

    // Overall balance, adjusted for payments, across every trip.
    final aggregateNet = <String, double>{};
    appData.chargesByTrip.forEach((tripId, charges) {
      netBalancesByMember(charges).forEach((member, amount) {
        aggregateNet[member] = (aggregateNet[member] ?? 0) + amount;
      });
    });
    double totalOwe = 0, totalOwed = 0;
    for (final member in aggregateNet.keys) {
      final adjusted = aggregateNet[member]! + _paidSoFar(appData, member);
      if (adjusted < 0) {
        totalOwe += -adjusted;
      } else {
        totalOwed += adjusted;
      }
    }
    final net = totalOwed - totalOwe;
    final netColor = net == 0 ? AppColors.textSecondary : (net < 0 ? AppColors.moneyOwe : AppColors.moneyOwed);
    final netBg = net == 0 ? AppColors.divider : (net < 0 ? const Color(0x1AA8372A) : const Color(0x1A085023));
    final netLabel = net == 0 ? 'All settled up' : (net < 0 ? 'You owe \$${(-net).toStringAsFixed(2)}' : "You're owed \$${net.toStringAsFixed(2)}");

    final trips = appData.trips.where((t) => t.status == _filter).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Balances', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: netBg, borderRadius: BorderRadius.circular(14)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('OVERALL BALANCE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: netColor, letterSpacing: 0.5)),
                const SizedBox(height: 4),
                Text(netLabel, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: netColor)),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'You owe \$${totalOwe.toStringAsFixed(2)} · You\'re owed \$${totalOwed.toStringAsFixed(2)}',
                        style: TextStyle(fontSize: 12.5, color: netColor),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: _openBalancesByPerson,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: netColor,
                        minimumSize: Size.zero,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                      child: const Text('Settle Now'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(border: Border.all(color: AppColors.border, width: 1.5), borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.all(3),
            child: Row(
              children: [
                Expanded(child: _filterButton('Upcoming', TripStatus.upcoming)),
                Expanded(child: _filterButton('Past', TripStatus.past)),
              ],
            ),
          ),
          const SizedBox(height: 14),
          for (final trip in trips) ...[
            _TripBalanceCard(
              trip: trip,
              charges: appData.chargesByTrip[trip.id] ?? const [],
              expanded: _expandedTripIds.contains(trip.id),
              onToggle: () => setState(() {
                if (!_expandedTripIds.add(trip.id)) _expandedTripIds.remove(trip.id);
              }),
              onAddExpense: () => _addExpense(trip),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  Widget _filterButton(String label, TripStatus status) {
    final selected = _filter == status;
    return GestureDetector(
      onTap: () => setState(() => _filter = status),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: selected ? AppColors.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
        ),
        alignment: Alignment.center,
        child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: selected ? Colors.white : AppColors.textPrimary)),
      ),
    );
  }
}

class _TripBalanceCard extends StatelessWidget {
  const _TripBalanceCard({
    required this.trip,
    required this.charges,
    required this.expanded,
    required this.onToggle,
    required this.onAddExpense,
  });

  final Trip trip;
  final List<Charge> charges;
  final bool expanded;
  final VoidCallback onToggle;
  final VoidCallback onAddExpense;

  IconData _iconFor(ChargeCategory c) {
    switch (c) {
      case ChargeCategory.food:
        return Icons.restaurant_outlined;
      case ChargeCategory.transport:
        return Icons.directions_car_outlined;
      case ChargeCategory.lodging:
        return Icons.home_outlined;
      case ChargeCategory.activity:
        return Icons.local_activity_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final net = netBalancesByMember(charges);
    final tripTotal = net.values.fold(0.0, (sum, v) => sum + v);
    final owesThem = tripTotal < 0;
    final balanceLabel = tripTotal == 0
        ? 'Settled up'
        : (owesThem ? 'You owe \$${(-tripTotal).toStringAsFixed(2)}' : "You're owed \$${tripTotal.toStringAsFixed(2)}");
    final balanceColor = tripTotal == 0 ? AppColors.textSecondary : (owesThem ? AppColors.moneyOwe : AppColors.moneyOwed);

    return Container(
      decoration: BoxDecoration(border: Border.all(color: AppColors.border, width: 1.5), borderRadius: BorderRadius.circular(14)),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 36, height: 36, decoration: BoxDecoration(color: trip.cover.accent, borderRadius: BorderRadius.circular(10))),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(trip.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                    Text('${trip.destination} · ${trip.dateLabel}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
          const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Divider(height: 1, color: AppColors.divider)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(balanceLabel, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: balanceColor)),
              OutlinedButton(
                onPressed: onToggle,
                style: OutlinedButton.styleFrom(
                  minimumSize: Size.zero,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  side: const BorderSide(color: AppColors.accent, width: 1.5),
                  foregroundColor: AppColors.accent,
                  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
                child: Text(expanded ? 'Hide' : 'Details'),
              ),
            ],
          ),
          if (expanded) ...[
            const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1, color: AppColors.divider)),
            if (net.isNotEmpty) ...[
              const Text('WHO OWES WHOM', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary, letterSpacing: 0.4)),
              const SizedBox(height: 8),
              for (final entry in net.entries)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(entry.key, style: const TextStyle(fontSize: 12.5, color: AppColors.textPrimary)),
                      Text(
                        entry.value < 0 ? 'You owe \$${(-entry.value).toStringAsFixed(2)}' : 'Owes you \$${entry.value.toStringAsFixed(2)}',
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: entry.value < 0 ? AppColors.moneyOwe : AppColors.moneyOwed),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
            ],
            const Text('ACTIVITY', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary, letterSpacing: 0.4)),
            const SizedBox(height: 8),
            for (final charge in charges)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(color: AppColors.divider, shape: BoxShape.circle),
                      child: Icon(_iconFor(charge.category), size: 14, color: AppColors.textSecondary),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(charge.description, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                              Text('\$${charge.amount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                            ],
                          ),
                          Text(
                            '${charge.payer == 'You' ? 'You paid' : '${charge.payer} paid'} · ${charge.date}',
                            style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                          ),
                          Text('Split: ${charge.splitWith.join(', ')}', style: const TextStyle(fontSize: 11, color: AppColors.textTertiary)),
                        ],
                      ),
                    ),
                    if (charge.receiptImage != null) ...[
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => _ReceiptViewerScreen(image: charge.receiptImage!)),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Image.file(charge.receiptImage!, width: 28, height: 28, fit: BoxFit.cover),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            const SizedBox(height: 6),
            OutlinedButton.icon(
              onPressed: onAddExpense,
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text('Add expense'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(38),
                textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ReceiptViewerScreen extends StatelessWidget {
  const _ReceiptViewerScreen({required this.image});

  final File image;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Receipt'),
      ),
      body: Center(
        child: InteractiveViewer(
          child: Image.file(image),
        ),
      ),
    );
  }
}
