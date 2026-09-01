import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/activity_item.dart';
import '../../models/onboarding_data.dart';
import '../../models/story_item.dart';
import '../../services/stories_service.dart';
import '../../state/app_data.dart';
import '../../theme/app_colors.dart';
import '../../widgets/trip_hero_card.dart';
import '../group/create_group_flow.dart';
import '../trip/trip_detail_screen.dart';
import 'story_viewer_screen.dart';

class HomeTab extends StatefulWidget {
  const HomeTab({super.key, required this.data});

  final OnboardingData data;

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  final _picker = ImagePicker();
  List<StoryItem> _stories = const [];
  bool _loadingStories = true;

  @override
  void initState() {
    super.initState();
    _loadStories();
  }

  Future<void> _loadStories() async {
    final stories = await StoriesService.instance.fetchMyStories();
    if (!mounted) return;
    setState(() {
      _stories = stories;
      _loadingStories = false;
    });
  }

  Future<void> _onAvatarTap() async {
    if (_stories.isNotEmpty) {
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => StoryViewerScreen(stories: _stories)),
      );
      _loadStories();
      return;
    }
    await _addStory();
  }

  Future<void> _addStory() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.photo_library_outlined, color: context.colors.accent),
              title: const Text('Choose from library'),
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
            ListTile(
              leading: Icon(Icons.camera_alt_outlined, color: context.colors.accent),
              title: const Text('Take a photo'),
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    final picked = await _picker.pickImage(source: source, maxWidth: 1600, imageQuality: 85);
    if (picked == null) return;

    final added = await StoriesService.instance.addStory(File(picked.path));
    if (!mounted || added == null) return;
    setState(() => _stories = [..._stories, added]);
  }

  @override
  Widget build(BuildContext context) {
    final appData = AppDataScope.of(context);
    final trip = appData.nextTrip;
    final data = widget.data;
    final firstName = data.firstName.isEmpty ? 'there' : data.firstName;
    final hasActiveStory = _stories.isNotEmpty;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hi, $firstName',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: context.colors.textPrimary),
                  ),
                  const SizedBox(height: 4),
                  Text("Here's what's coming up", style: TextStyle(fontSize: 13, color: context.colors.textSecondary)),
                ],
              ),
              Stack(
                clipBehavior: Clip.none,
                children: [
                  GestureDetector(
                    onTap: _loadingStories ? null : _onAvatarTap,
                    child: Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: hasActiveStory ? context.colors.accent : Colors.transparent,
                          width: 2.5,
                        ),
                      ),
                      child: Container(
                        width: 38,
                        height: 38,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: context.colors.accent, shape: BoxShape.circle),
                        child: Text(
                          data.initials,
                          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ),
                  if (hasActiveStory && !_loadingStories)
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: GestureDetector(
                        onTap: _addStory,
                        child: Container(
                          width: 18,
                          height: 18,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: context.colors.accent,
                            border: Border.all(color: context.colors.background, width: 2),
                          ),
                          child: const Icon(Icons.add, size: 11, color: Colors.white),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          TripHeroCard(
            trip: trip,
            eyebrow: 'NEXT TRIP',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => TripDetailScreen(trip: trip)),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const CreateGroupFlow()),
                  ),
                  style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(44)),
                  child: const Text('Create a group', style: TextStyle(fontSize: 13)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: null,
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44)),
                  child: const Text('Join with code', style: TextStyle(fontSize: 13)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          Text(
            'Recent activity',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: context.colors.textPrimary),
          ),
          const SizedBox(height: 12),
          for (final item in ActivityItem.sample)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: context.colors.divider)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(top: 6, right: 10),
                    decoration: BoxDecoration(color: context.colors.accent, shape: BoxShape.circle),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.text, style: TextStyle(fontSize: 13, color: context.colors.textPrimary, height: 1.4)),
                        const SizedBox(height: 2),
                        Text(item.time, style: TextStyle(fontSize: 12, color: context.colors.textTertiary)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
