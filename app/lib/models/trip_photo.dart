import 'dart:io';

/// A real photo added to a trip's gallery (picked from the device).
class TripPhoto {
  const TripPhoto({required this.id, required this.file, required this.uploader});

  final String id;
  final File file;
  final String uploader;
}
