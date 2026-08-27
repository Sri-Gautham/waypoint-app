enum ActivityLogKind { person, receipt, photo, chat }

/// One entry in a past trip's broader activity timeline (joins, expenses,
/// photo uploads, messages) — distinct from the Home tab's activity feed.
class ActivityLogEntry {
  const ActivityLogEntry({required this.kind, required this.text, required this.time});

  final ActivityLogKind kind;
  final String text;
  final String time;
}
