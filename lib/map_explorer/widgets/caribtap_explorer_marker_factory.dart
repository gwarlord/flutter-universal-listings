import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

enum ExplorerMarkerState {
  defaultState,
  dimmed,
  selected,
}

class CaribTapExplorerMarkerFactory {
  CaribTapExplorerMarkerFactory._();

  static Future<Map<ExplorerMarkerState, BitmapDescriptor>>? _cache;

  static Future<Map<ExplorerMarkerState, BitmapDescriptor>> loadMarkers() {
    _cache ??= _createMarkers();
    return _cache!;
  }

  static Future<Map<ExplorerMarkerState, BitmapDescriptor>> _createMarkers() async {
    final defaultMarker = await _drawMarker(
      size: 88,
      coreRadius: 16,
      glowSigma: 7,
      outerColor: const Color(0xFF2F8FEF),
      innerColor: const Color(0xFF0D4E89),
      glowColor: const Color(0x8839B6FF),
      opacity: 1.0,
    );

    final dimmedMarker = await _drawMarker(
      size: 88,
      coreRadius: 15,
      glowSigma: 0,
      outerColor: const Color(0xFF2F8FEF),
      innerColor: const Color(0xFF0D4E89),
      glowColor: const Color(0x00000000),
      opacity: 0.35,
    );

    final selectedMarker = await _drawMarker(
      size: 98,
      coreRadius: 20,
      glowSigma: 10,
      outerColor: const Color(0xFFF4B734),
      innerColor: const Color(0xFF8B5C00),
      glowColor: const Color(0x99FFC447),
      opacity: 1.0,
    );

    return {
      ExplorerMarkerState.defaultState: defaultMarker,
      ExplorerMarkerState.dimmed: dimmedMarker,
      ExplorerMarkerState.selected: selectedMarker,
    };
  }

  static Future<BitmapDescriptor> _drawMarker({
    required int size,
    required double coreRadius,
    required double glowSigma,
    required Color outerColor,
    required Color innerColor,
    required Color glowColor,
    required double opacity,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final center = Offset(size / 2, size / 2);

    if (glowSigma > 0) {
      final glowPaint = Paint()
        ..color = glowColor.withValues(alpha: glowColor.a * opacity)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, glowSigma);
      canvas.drawCircle(center, coreRadius + 5, glowPaint);
    }

    final shadowPaint = Paint()
      ..color = const Color(0xAA06253F).withValues(alpha: 0.5 * opacity)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawCircle(center.translate(0, 3), coreRadius + 1, shadowPaint);

    final outerPaint = Paint()
      ..color = outerColor.withValues(alpha: opacity)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, coreRadius, outerPaint);

    final strokePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.20 * opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    canvas.drawCircle(center, coreRadius - 0.8, strokePaint);

    final innerPaint = Paint()
      ..color = innerColor.withValues(alpha: opacity)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, coreRadius * 0.40, innerPaint);

    final image = await recorder.endRecording().toImage(size, size);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final data = bytes!.buffer.asUint8List();
    return BitmapDescriptor.bytes(data);
  }
}
