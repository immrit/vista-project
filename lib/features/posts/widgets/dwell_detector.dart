import 'dart:async';
import 'package:flutter/material.dart';
import 'package:visibility_detector/visibility_detector.dart';

class DwellDetector extends StatefulWidget {
  final Widget child;
  final String itemKey;
  final Duration dwellThreshold;
  final VoidCallback onDwell;
  final VoidCallback onView;

  const DwellDetector({
    super.key,
    required this.child,
    required this.itemKey,
    required this.onDwell,
    required this.onView,
    this.dwellThreshold = const Duration(seconds: 2),
  });

  @override
  State<DwellDetector> createState() => _DwellDetectorState();
}

class _DwellDetectorState extends State<DwellDetector> {
  Timer? _dwellTimer;
  bool _hasDwelled = false;
  bool _hasViewed = false;

  void _handleVisibilityChanged(VisibilityInfo info) {
    if (info.visibleFraction > 0.3 && !_hasViewed) {
      _hasViewed = true;
      widget.onView();
    }

    if (info.visibleFraction > 0.6) {
      if (!_hasDwelled && _dwellTimer == null) {
        _dwellTimer = Timer(widget.dwellThreshold, () {
          _hasDwelled = true;
          widget.onDwell();
        });
      }
    } else {
      _dwellTimer?.cancel();
      _dwellTimer = null;
    }
  }

  @override
  void dispose() {
    _dwellTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: Key('dwell_${widget.itemKey}'),
      onVisibilityChanged: _handleVisibilityChanged,
      child: widget.child,
    );
  }
}
