import 'package:flutter/material.dart';

class VistaMotion {
  // Modern-like snappy curves
  static const Curve snappy = Curves.easeOutQuint;
  static const Curve springy = Curves.easeOutBack;
  static const Curve smooth = Curves.easeInOutCubic;

  // Modern-like durations
  static const Duration durationFast = Duration(milliseconds: 150);
  static const Duration durationMedium = Duration(milliseconds: 250);
  static const Duration durationSlow = Duration(milliseconds: 400);

  // Helper for reduce motion
  static Duration duration(Duration defaultDuration, {required bool reduceMotion}) {
    return reduceMotion ? Duration.zero : defaultDuration;
  }
}
