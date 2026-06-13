import 'package:flutter/material.dart';

/// Defers building tab content until the user opens that tab once.
/// After activation, [AutomaticKeepAliveClientMixin] keeps state alive.
class ProfileLazyTabGate extends StatefulWidget {
  const ProfileLazyTabGate({
    super.key,
    required this.tabController,
    required this.tabIndex,
    required this.child,
  });

  final TabController tabController;
  final int tabIndex;
  final Widget child;

  @override
  State<ProfileLazyTabGate> createState() => _ProfileLazyTabGateState();
}

class _ProfileLazyTabGateState extends State<ProfileLazyTabGate>
    with AutomaticKeepAliveClientMixin {
  bool _activated = false;

  @override
  void initState() {
    super.initState();
    _activated = widget.tabController.index == widget.tabIndex;
    widget.tabController.addListener(_handleTabChange);
  }

  @override
  void didUpdateWidget(covariant ProfileLazyTabGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tabController != widget.tabController) {
      oldWidget.tabController.removeListener(_handleTabChange);
      widget.tabController.addListener(_handleTabChange);
      if (!_activated && widget.tabController.index == widget.tabIndex) {
        _activated = true;
      }
    }
  }

  @override
  void dispose() {
    widget.tabController.removeListener(_handleTabChange);
    super.dispose();
  }

  void _handleTabChange() {
    if (!_activated && widget.tabController.index == widget.tabIndex) {
      setState(() => _activated = true);
    }
  }

  @override
  bool get wantKeepAlive => _activated;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (!_activated) {
      return const SizedBox.shrink();
    }
    return widget.child;
  }
}
