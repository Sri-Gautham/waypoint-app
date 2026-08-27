import 'package:flutter/material.dart';

import '../theme/cover_theme.dart';

/// The layered mountain/lake illustration used as a trip's cover art,
/// recreated from the design canvas's SVG composition (400x200 viewBox).
class TripLandscape extends StatelessWidget {
  const TripLandscape({super.key, required this.theme, this.borderRadius = 16});

  final CoverTheme theme;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: CustomPaint(
        painter: _LandscapePainter(theme),
        size: Size.infinite,
      ),
    );
  }
}

class _LandscapePainter extends CustomPainter {
  _LandscapePainter(this.theme);

  final CoverTheme theme;

  // Coordinates below mirror the original 400x200 SVG viewBox.
  static const _viewW = 400.0;
  static const _viewH = 200.0;

  Offset _pt(double x, double y, Size size) {
    return Offset(x / _viewW * size.width, y / _viewH * size.height);
  }

  Path _polygon(List<Offset> points, Size size) {
    final scaled = points.map((p) => _pt(p.dx, p.dy, size)).toList();
    return Path()..addPolygon(scaled, true);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final fullRect = Offset.zero & size;

    // Sky
    final skyPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [theme.sky1, theme.sky2, theme.sky3],
        stops: const [0, 0.55, 1],
      ).createShader(fullRect);
    canvas.drawRect(fullRect, skyPaint);

    // Sun
    canvas.drawCircle(_pt(300, 55, size), 26 / _viewH * size.height, Paint()..color = theme.sun);

    // Back ridge
    canvas.drawPath(
      _polygon(const [
        Offset(0, 130), Offset(60, 80), Offset(120, 120), Offset(180, 70),
        Offset(240, 115), Offset(300, 75), Offset(360, 110), Offset(400, 90),
        Offset(400, 150), Offset(0, 150),
      ], size),
      Paint()..color = theme.mid,
    );

    // Front ridge
    canvas.drawPath(
      _polygon(const [
        Offset(0, 150), Offset(90, 105), Offset(170, 140), Offset(260, 100),
        Offset(340, 135), Offset(400, 115), Offset(400, 160), Offset(0, 160),
      ], size),
      Paint()..color = theme.front,
    );

    // Water band
    final bandRect = Rect.fromLTWH(0, 150 / _viewH * size.height, size.width, 50 / _viewH * size.height);
    final bandPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [theme.band1, theme.band2],
      ).createShader(bandRect);
    canvas.drawRect(bandRect, bandPaint);
  }

  @override
  bool shouldRepaint(covariant _LandscapePainter oldDelegate) => oldDelegate.theme != theme;
}
