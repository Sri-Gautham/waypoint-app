import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../models/story_item.dart';
import '../../services/stories_service.dart';

/// Full-screen, tap-to-advance story viewer — Instagram-style progress
/// bars across the top, auto-advancing every [_segmentDuration]. Bytes
/// are fetched lazily per segment (not all up front) and cached in
/// [_imageCache] for the lifetime of this screen.
class StoryViewerScreen extends StatefulWidget {
  const StoryViewerScreen({super.key, required this.stories, this.initialIndex = 0});

  final List<StoryItem> stories;
  final int initialIndex;

  @override
  State<StoryViewerScreen> createState() => _StoryViewerScreenState();
}

class _StoryViewerScreenState extends State<StoryViewerScreen> with SingleTickerProviderStateMixin {
  static const _segmentDuration = Duration(seconds: 5);

  late final AnimationController _controller;
  late List<StoryItem> _stories = List.of(widget.stories);
  late int _index = widget.initialIndex;
  final Map<String, Uint8List> _imageCache = {};
  bool _deleting = false;

  StoryItem get _current => _stories[_index];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _segmentDuration)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) _advance();
      });
    _loadAndPlay(_index);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadAndPlay(int index) async {
    _controller.stop();
    _controller.reset();
    final path = _stories[index].imagePath;
    if (!_imageCache.containsKey(path)) {
      final bytes = await StoriesService.instance.downloadImage(path);
      if (!mounted || _index != index) return;
      if (bytes != null) _imageCache[path] = bytes;
      setState(() {});
    }
    if (!mounted || _index != index) return;
    _controller.forward(from: 0);
  }

  void _advance() {
    if (_index >= _stories.length - 1) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _index++);
    _loadAndPlay(_index);
  }

  void _back() {
    if (_index == 0) {
      _loadAndPlay(_index);
      return;
    }
    setState(() => _index--);
    _loadAndPlay(_index);
  }

  Future<void> _confirmDelete() async {
    _controller.stop();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this story?'),
        content: const Text('This photo will be removed and can\'t be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      _controller.forward();
      return;
    }

    setState(() => _deleting = true);
    final ok = await StoriesService.instance.deleteStory(_current);
    if (!mounted) return;
    setState(() => _deleting = false);
    if (!ok) {
      // Resume autoplay same as a cancelled delete — otherwise a failed
      // delete (e.g. a transient network error) leaves the current
      // segment's progress permanently stalled with no way to recover
      // except a manual tap.
      _controller.forward();
      return;
    }

    if (_stories.length == 1) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _stories = List.of(_stories)..removeAt(_index);
      if (_index >= _stories.length) _index = _stories.length - 1;
    });
    _loadAndPlay(_index);
  }

  @override
  Widget build(BuildContext context) {
    final bytes = _imageCache[_current.imagePath];
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: bytes == null
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Image.memory(bytes, fit: BoxFit.contain, width: double.infinity),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              bottom: 0,
              child: Row(
                children: [
                  Expanded(child: GestureDetector(onTap: _back, behavior: HitTestBehavior.translucent)),
                  Expanded(child: GestureDetector(onTap: _advance, behavior: HitTestBehavior.translucent)),
                ],
              ),
            ),
            Positioned(
              left: 12,
              right: 12,
              top: 8,
              child: Row(
                children: [
                  for (var i = 0; i < _stories.length; i++) ...[
                    if (i > 0) const SizedBox(width: 4),
                    Expanded(
                      child: AnimatedBuilder(
                        animation: _controller,
                        builder: (context, _) => ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(
                            value: i < _index ? 1 : (i > _index ? 0 : _controller.value),
                            minHeight: 3,
                            backgroundColor: Colors.white24,
                            valueColor: const AlwaysStoppedAnimation(Colors.white),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Positioned(
              right: 8,
              top: 20,
              child: Row(
                children: [
                  _deleting
                      ? const Padding(
                          padding: EdgeInsets.all(10),
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          ),
                        )
                      : IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.white),
                          onPressed: _confirmDelete,
                        ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
