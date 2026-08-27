import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../config/unsplash_config.dart';

enum CoverGenerationUnavailableReason { unsupportedPlatform, deviceNotCapable, cancelled, noApiKey, requestFailed }

class CoverGenerationResult {
  const CoverGenerationResult.image(Uint8List bytes) : imageBytes = bytes, reason = null;
  const CoverGenerationResult.unavailable(this.reason) : imageBytes = null;

  final Uint8List? imageBytes;
  final CoverGenerationUnavailableReason? reason;
  bool get succeeded => imageBytes != null;
}

/// Produces a trip cover image from a destination string.
///
/// iOS: Apple's on-device Image Playground (iOS 18.1+, Apple-Intelligence-
/// capable devices only) — a real generated illustration, via the native
/// bridge in ios/Runner/ImagePlaygroundBridge.swift.
///
/// Android: there's no on-device generative equivalent today (Gemini
/// Nano/AICore is text-focused, not image), so this searches Unsplash for
/// a real destination photo instead — see config/unsplash_config.dart for
/// the API key this needs.
///
/// Either platform falls back to the 4 illustrated presets (CoverTheme)
/// when generation is unavailable or fails — see GroupBasicsStep /
/// GroupDestinationStep, which call this and keep the preset selection as
/// the default.
class CoverGenerationService {
  CoverGenerationService._();
  static final instance = CoverGenerationService._();

  static const _channel = MethodChannel('com.srigautham.waypoint/image_playground');

  Future<bool> isIOSGenerationAvailable() async {
    if (!Platform.isIOS) return false;
    try {
      final available = await _channel.invokeMethod<bool>('isAvailable');
      return available ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<CoverGenerationResult> generate(String destination) {
    if (Platform.isIOS) return _generateIOS(destination);
    if (Platform.isAndroid) return _searchUnsplash(destination);
    return Future.value(const CoverGenerationResult.unavailable(CoverGenerationUnavailableReason.unsupportedPlatform));
  }

  Future<CoverGenerationResult> _generateIOS(String destination) async {
    try {
      final available = await _channel.invokeMethod<bool>('isAvailable') ?? false;
      if (!available) {
        return const CoverGenerationResult.unavailable(CoverGenerationUnavailableReason.deviceNotCapable);
      }
      final concept = 'A scenic travel illustration of $destination';
      final data = await _channel.invokeMethod<Uint8List>('generate', {'concept': concept});
      if (data == null) {
        return const CoverGenerationResult.unavailable(CoverGenerationUnavailableReason.cancelled);
      }
      return CoverGenerationResult.image(data);
    } on PlatformException {
      return const CoverGenerationResult.unavailable(CoverGenerationUnavailableReason.requestFailed);
    } on MissingPluginException {
      return const CoverGenerationResult.unavailable(CoverGenerationUnavailableReason.deviceNotCapable);
    }
  }

  Future<CoverGenerationResult> _searchUnsplash(String destination) async {
    if (UnsplashConfig.accessKey.isEmpty) {
      return const CoverGenerationResult.unavailable(CoverGenerationUnavailableReason.noApiKey);
    }
    try {
      final searchUri = Uri.https('api.unsplash.com', '/search/photos', {
        'query': destination,
        'per_page': '1',
        'orientation': 'landscape',
      });
      final searchResponse = await http.get(
        searchUri,
        headers: {'Authorization': 'Client-ID ${UnsplashConfig.accessKey}'},
      );
      if (searchResponse.statusCode != 200) {
        return const CoverGenerationResult.unavailable(CoverGenerationUnavailableReason.requestFailed);
      }
      final results = (jsonDecode(searchResponse.body) as Map<String, dynamic>)['results'] as List<dynamic>;
      if (results.isEmpty) {
        return const CoverGenerationResult.unavailable(CoverGenerationUnavailableReason.requestFailed);
      }
      final imageUrl = ((results.first as Map<String, dynamic>)['urls'] as Map<String, dynamic>)['regular'] as String;
      final imageResponse = await http.get(Uri.parse(imageUrl));
      if (imageResponse.statusCode != 200) {
        return const CoverGenerationResult.unavailable(CoverGenerationUnavailableReason.requestFailed);
      }
      return CoverGenerationResult.image(imageResponse.bodyBytes);
    } catch (_) {
      return const CoverGenerationResult.unavailable(CoverGenerationUnavailableReason.requestFailed);
    }
  }
}
