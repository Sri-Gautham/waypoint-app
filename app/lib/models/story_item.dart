/// A single 24h photo story item — metadata only; the image bytes are
/// fetched separately (via [StoriesService.downloadImage]) since the
/// list view only needs to know whether an active story exists.
class StoryItem {
  const StoryItem({required this.id, required this.imagePath, required this.createdAt});

  final String id;
  final String imagePath;
  final DateTime createdAt;

  DateTime get expiresAt => createdAt.add(const Duration(hours: 24));
  bool get isExpired => DateTime.now().isAfter(expiresAt);
}
