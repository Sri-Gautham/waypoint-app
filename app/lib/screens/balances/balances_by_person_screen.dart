import 'package:flutter/material.dart';

import '../../models/payment.dart';
import '../../state/app_data.dart';
import '../../theme/app_colors.dart';
import '../../utils/balance_calculator.dart';

class BalancesByPersonScreen extends StatefulWidget {
  const BalancesByPersonScreen({super.key});

  @override
  State<BalancesByPersonScreen> createState() => _BalancesByPersonScreenState();
}

class _BalancesByPersonScreenState extends State<BalancesByPersonScreen> {
  String? _expandedMember;
  String? _settleOpenMember;
  final _draftController = TextEditingController();

  @override
  void dispose() {
    _draftController.dispose();
    super.dispose();
  }

  double _paidSoFar(AppData appData, String memberName) {
    return appData.payments.where((p) => p.memberName == memberName).fold(0.0, (sum, p) => sum + p.amount);
  }

  Map<String, Map<String, double>> _netByTripByMember(AppData appData) {
    final result = <String, Map<String, double>>{};
    appData.chargesByTrip.forEach((tripId, charges) {
      result[tripId] = netBalancesByMember(charges);
    });
    return result;
  }

  void _openSettle(String member, double owed) {
    setState(() {
      if (_settleOpenMember == member) {
        _settleOpenMember = null;
      } else {
        _settleOpenMember = member;
        _draftController.text = owed.toStringAsFixed(owed.truncateToDouble() == owed ? 0 : 2);
      }
    });
  }

  void _confirmPayment(AppData appData, String member, double owed) {
    final raw = double.tryParse(_draftController.text.trim());
    if (raw == null || raw <= 0) return;
    final amount = raw > owed ? owed : raw;
    appData.addPayment(Payment(memberName: member, amount: amount));
    setState(() => _settleOpenMember = null);
  }

  @override
  Widget build(BuildContext context) {
    final appData = AppDataScope.of(context);
    final tripNames = {for (final t in appData.trips) t.id: t.name};

    final netByTrip = _netByTripByMember(appData);
    final rawNetByMember = <String, double>{};
    final tripsByMember = <String, List<(String tripName, double amount)>>{};
    netByTrip.forEach((tripId, netMap) {
      netMap.forEach((member, amount) {
        rawNetByMember[member] = (rawNetByMember[member] ?? 0) + amount;
        (tripsByMember[member] ??= []).add((tripNames[tripId] ?? tripId, amount));
      });
    });

    final members = rawNetByMember.keys.toList();
    double totalOwe = 0, totalOwed = 0;
    for (final m in members) {
      final adjusted = rawNetByMember[m]! + _paidSoFar(appData, m);
      if (adjusted < 0) {
        totalOwe += -adjusted;
      } else {
        totalOwed += adjusted;
      }
    }
    final net = totalOwed - totalOwe;

    return Scaffold(
      appBar: AppBar(title: const Text('Balances by person', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800))),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Center(
              child: Column(
                children: [
                  Text('OVERALL', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: context.colors.textSecondary, letterSpacing: 0.5)),
                  const SizedBox(height: 4),
                  Text(
                    net == 0 ? 'All settled up' : (net < 0 ? 'You owe \$${(-net).toStringAsFixed(2)}' : "You're owed \$${net.toStringAsFixed(2)}"),
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: net == 0 ? context.colors.textSecondary : (net < 0 ? context.colors.moneyOwe : context.colors.moneyOwed)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'You owe \$${totalOwe.toStringAsFixed(2)} · You\'re owed \$${totalOwed.toStringAsFixed(2)}',
                    style: TextStyle(fontSize: 12.5, color: context.colors.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            for (final member in members) ...[
              _buildMemberCard(appData, member, rawNetByMember[member]!, tripsByMember[member] ?? []),
              const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMemberCard(AppData appData, String member, double rawNet, List<(String, double)> trips) {
    final paid = _paidSoFar(appData, member);
    final adjusted = rawNet + paid;
    final owesThem = adjusted < 0;
    final owed = adjusted.abs();
    final expanded = _expandedMember == member;
    final settleOpen = _settleOpenMember == member;
    final initials = member.split(' ').where((s) => s.isNotEmpty).map((s) => s[0]).take(2).join().toUpperCase();

    final netColor = adjusted == 0 ? context.colors.textSecondary : (owesThem ? context.colors.moneyOwe : context.colors.moneyOwed);
    final netLabel = adjusted == 0 ? 'Settled up' : (owesThem ? 'You owe \$${owed.toStringAsFixed(2)}' : "Owes you \$${owed.toStringAsFixed(2)}");

    return Container(
      decoration: BoxDecoration(border: Border.all(color: context.colors.border, width: 1.5), borderRadius: BorderRadius.circular(14)),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => setState(() => _expandedMember = expanded ? null : member),
                  child: Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: context.colors.accentTint, shape: BoxShape.circle),
                        child: Text(initials, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: context.colors.textPrimary)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Text(member, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: context.colors.textPrimary))),
                    ],
                  ),
                ),
              ),
              Text(netLabel, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: netColor)),
              if (owesThem) ...[
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () => _openSettle(member, owed),
                  style: OutlinedButton.styleFrom(
                    minimumSize: Size.zero,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    side: BorderSide(color: context.colors.accent, width: 1.5),
                    foregroundColor: context.colors.accent,
                    textStyle: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                  ),
                  child: const Text('Settle up'),
                ),
              ],
            ],
          ),
          if (settleOpen) ...[
            Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1, color: context.colors.divider)),
            Text('Record a payment to $member', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: context.colors.textSecondary)),
            const SizedBox(height: 8),
            Row(
              children: [
                Text('\$', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: context.colors.textPrimary)),
                const SizedBox(width: 6),
                Expanded(
                  child: TextField(
                    controller: _draftController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(fontSize: 15),
                    decoration: const InputDecoration(isDense: true),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('Up to \$${owed.toStringAsFixed(2)}, the full amount owed.', style: TextStyle(fontSize: 11, color: context.colors.textTertiary)),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => setState(() => _settleOpenMember = null),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _confirmPayment(appData, member, owed),
                    child: const Text('Record payment'),
                  ),
                ),
              ],
            ),
          ],
          if (expanded) ...[
            Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1, color: context.colors.divider)),
            for (final (tripName, amount) in trips)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(tripName, style: TextStyle(fontSize: 12.5, color: context.colors.textSecondary)),
                    Text(
                      amount < 0 ? 'You owe \$${(-amount).toStringAsFixed(2)}' : 'Owes you \$${amount.toStringAsFixed(2)}',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: amount < 0 ? context.colors.moneyOwe : context.colors.moneyOwed),
                    ),
                  ],
                ),
              ),
            if (paid > 0)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Payment sent', style: TextStyle(fontSize: 12.5, color: context.colors.textSecondary)),
                    Text('You paid \$${paid.toStringAsFixed(2)}', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: context.colors.moneyOwed)),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}
