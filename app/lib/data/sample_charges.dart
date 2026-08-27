import '../models/charge.dart';

/// Starting set of charges per trip id. Mutable copies of these lists are
/// held in [BalancesTab]'s state so new expenses can be added at runtime.
Map<String, List<Charge>> seedCharges() {
  return {
    't1': [
      const Charge(
        id: 'c1',
        tripId: 't1',
        payer: 'Sam Park',
        amount: 84,
        description: 'Groceries',
        category: ChargeCategory.food,
        date: 'Aug 20',
        splitWith: ['You', 'Sam Park', 'Alex Kim'],
      ),
      const Charge(
        id: 'c2',
        tripId: 't1',
        payer: 'Alex Kim',
        amount: 42,
        description: 'Firewood & ice',
        category: ChargeCategory.activity,
        date: 'Aug 21',
        splitWith: ['You', 'Sam Park', 'Alex Kim'],
      ),
    ],
    't2': [
      const Charge(
        id: 'c3',
        tripId: 't2',
        payer: 'You',
        amount: 20,
        description: 'Cabin deposit split',
        category: ChargeCategory.lodging,
        date: 'Oct 18',
        splitWith: ['You', 'Priya Nair'],
      ),
      const Charge(
        id: 'c4',
        tripId: 't2',
        payer: 'You',
        amount: 16,
        description: 'Gas for the drive',
        category: ChargeCategory.transport,
        date: 'Oct 19',
        splitWith: ['You', 'Jordan Lee'],
      ),
      const Charge(
        id: 'c5',
        tripId: 't2',
        payer: 'You',
        amount: 10,
        description: 'Snacks & drinks',
        category: ChargeCategory.food,
        date: 'Oct 19',
        splitWith: ['You', 'Sam Park'],
      ),
    ],
    't3': [
      const Charge(
        id: 'c6',
        tripId: 't3',
        payer: 'You',
        amount: 150,
        description: 'Winery tour tickets',
        category: ChargeCategory.activity,
        date: 'Jun 12',
        splitWith: ['You', 'Sam Park', 'Alex Kim', 'Morgan Diaz'],
      ),
      const Charge(
        id: 'c7',
        tripId: 't3',
        payer: 'Morgan Diaz',
        amount: 60,
        description: 'Lunch',
        category: ChargeCategory.food,
        date: 'Jun 13',
        splitWith: ['You', 'Sam Park', 'Alex Kim', 'Morgan Diaz'],
      ),
    ],
  };
}
