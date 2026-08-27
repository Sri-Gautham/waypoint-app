class ActivityItem {
  const ActivityItem({required this.text, required this.time});

  final String text;
  final String time;

  static const sample = [
    ActivityItem(text: 'Sam invited you to Weekend at the Cabin', time: '2h ago'),
    ActivityItem(text: 'Priya added an expense in Lake Tahoe Crew', time: '1d ago'),
    ActivityItem(text: 'Alex sent a message in Lake Tahoe Crew', time: '2d ago'),
  ];
}
