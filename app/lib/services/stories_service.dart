import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/story_item.dart';

/// Self-only 24h photo stories — see the `stories` table (RLS: strictly
/// owner-only, unlike trip_places/trip_day_status's interim looseness,
/// since there's no cross-user sharing to allow for here) and the
/// `stories` Storage bucket (private, objects RLS scoped by the first
/// path segment matching auth.uid()).
class StoriesService {
  StoriesService._();
  static final instance = StoriesService._();

  SupabaseClient get _client => Supabase.instance.client;

  /// Returns only non-expired stories, oldest first (so the viewer plays
  /// them in the order they were added). Opportunistically deletes any
  /// expired rows/files it finds along the way rather than leaving them
  /// to accumulate — there's no scheduled cleanup job for this.
  Future<List<StoryItem>> fetchMyStories() async {
    final user = _client.auth.currentUser;
    if (user == null) return const [];

    try {
      final rows = await _client.from('stories').select().eq('user_id', user.id).order('created_at');
      final all = (rows as List)
          .map((r) => StoryItem(
                id: r['id'] as String,
                imagePath: r['image_path'] as String,
                createdAt: DateTime.parse(r['created_at'] as String),
              ))
          .toList();

      final active = <StoryItem>[];
      final expired = <StoryItem>[];
      for (final story in all) {
        (story.isExpired ? expired : active).add(story);
      }
      if (expired.isNotEmpty) {
        // Fire-and-forget — a failed cleanup just means the next fetch
        // tries again, no need to hold up returning the active list.
        unawaited(_purge(expired));
      }
      return active;
    } catch (_) {
      return const [];
    }
  }

  Future<void> _purge(List<StoryItem> expired) async {
    try {
      await _client.storage.from('stories').remove(expired.map((s) => s.imagePath).toList());
      await _client.from('stories').delete().inFilter('id', expired.map((s) => s.id).toList());
    } catch (_) {
      // Next fetchMyStories() call retries — nothing to surface here.
    }
  }

  Future<StoryItem?> addStory(File imageFile) async {
    final user = _client.auth.currentUser;
    if (user == null) return null;

    try {
      final path = '${user.id}/${DateTime.now().microsecondsSinceEpoch}.jpg';
      await _client.storage.from('stories').upload(path, imageFile);
      final row = await _client
          .from('stories')
          .insert({'user_id': user.id, 'image_path': path})
          .select()
          .single();
      return StoryItem(
        id: row['id'] as String,
        imagePath: row['image_path'] as String,
        createdAt: DateTime.parse(row['created_at'] as String),
      );
    } catch (_) {
      return null;
    }
  }

  Future<bool> deleteStory(StoryItem story) async {
    try {
      await _client.storage.from('stories').remove([story.imagePath]);
      await _client.from('stories').delete().eq('id', story.id);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<Uint8List?> downloadImage(String imagePath) async {
    try {
      return await _client.storage.from('stories').download(imagePath);
    } catch (_) {
      return null;
    }
  }
}
