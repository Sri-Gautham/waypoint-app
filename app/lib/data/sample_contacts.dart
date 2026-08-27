class Contact {
  const Contact({required this.id, required this.name, required this.sub, required this.initials});

  final String id;
  final String name;
  final String sub;
  final String initials;
}

const sampleContacts = [
  Contact(id: 'c1', name: 'Sam Park', sub: '(512) 555-0142', initials: 'SP'),
  Contact(id: 'c2', name: 'Alex Kim', sub: 'alex.kim@email.com', initials: 'AK'),
  Contact(id: 'c3', name: 'Priya Nair', sub: '(415) 555-0193', initials: 'PN'),
  Contact(id: 'c4', name: 'Jordan Lee', sub: 'jordan.lee@email.com', initials: 'JL'),
  Contact(id: 'c5', name: 'Morgan Diaz', sub: '(303) 555-0177', initials: 'MD'),
];
