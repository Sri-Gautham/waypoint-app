import 'package:flutter/material.dart';

/// One of the illustrated trip-cover palettes from the design canvas.
/// Colors are converted from the design's oklch values to sRGB.
class CoverTheme {
  const CoverTheme({
    required this.name,
    required this.accent,
    required this.sky1,
    required this.sky2,
    required this.sky3,
    required this.sun,
    required this.mid,
    required this.front,
    required this.band1,
    required this.band2,
  });

  final String name;
  final Color accent;
  final Color sky1;
  final Color sky2;
  final Color sky3;
  final Color sun;
  final Color mid;
  final Color front;
  final Color band1;
  final Color band2;

  static const mountainLake = CoverTheme(
    name: 'Mountain Lake',
    accent: Color(0xFF2151A1),
    sky1: Color(0xFF79A9DB),
    sky2: Color(0xFFE0B491),
    sky3: Color(0xFFF1D0B7),
    sun: Color(0xFFFFDBA3),
    mid: Color(0xFF374A5D),
    front: Color(0xFF253444),
    band1: Color(0xFF42789C),
    band2: Color(0xFF213C59),
  );

  static const beach = CoverTheme(
    name: 'Beach',
    accent: Color(0xFF00858D),
    sky1: Color(0xFFF19F91),
    sky2: Color(0xFFF7BD8F),
    sky3: Color(0xFFF8D8B4),
    sun: Color(0xFFFFE79D),
    mid: Color(0xFFC8997B),
    front: Color(0xFFB57D63),
    band1: Color(0xFF2CB3B3),
    band2: Color(0xFF00717F),
  );

  static const desert = CoverTheme(
    name: 'Desert',
    accent: Color(0xFFB45000),
    sky1: Color(0xFFE09B83),
    sky2: Color(0xFFEDB793),
    sky3: Color(0xFFF3D5B9),
    sun: Color(0xFFFFD57E),
    mid: Color(0xFFA36B44),
    front: Color(0xFF834E36),
    band1: Color(0xFF9E7660),
    band2: Color(0xFF644436),
  );

  static const forest = CoverTheme(
    name: 'Forest',
    accent: Color(0xFF0B5D2A),
    sky1: Color(0xFF4A7797),
    sky2: Color(0xFF6A87B7),
    sky3: Color(0xFF96A3CB),
    sun: Color(0xFFDFD7C2),
    mid: Color(0xFF27422C),
    front: Color(0xFF122A18),
    band1: Color(0xFF204955),
    band2: Color(0xFF031E29),
  );

  static const all = [mountainLake, beach, desert, forest];
}
