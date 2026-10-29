import 'package:flutter/material.dart';

/// Fixed-width text that scrolls sideways when it is wider than the screen,
/// with the edge faded where there is more to see.
class SideScroll extends StatefulWidget {
  const SideScroll({super.key, required this.child});
  final Widget child;

  @override
  State<SideScroll> createState() => SideScrollState();
}

class SideScrollState extends State<SideScroll> {
  final _controller = ScrollController();
  var _moreLeft = false;
  var _moreRight = false;

  /// True while there is more to see to the right, so that edge is faded.
  bool get moreRight => _moreRight;

  /// True once scrolled, so the left edge is faded.
  bool get moreLeft => _moreLeft;

  /// How wide the fade is.
  static const _fade = 32.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _check() {
    if (!mounted || !_controller.hasClients || !_controller.position.hasContentDimensions) return;
    _update(_controller.position);
  }

  void _update(ScrollMetrics m) {
    final left = m.pixels > 1;
    final right = m.pixels < m.maxScrollExtent - 1;
    if (left != _moreLeft || right != _moreRight) {
      setState(() {
        _moreLeft = left;
        _moreRight = right;
      });
    }
  }

  bool _onMetrics(ScrollMetricsNotification n) {
    if (n.metrics.axis == Axis.horizontal) _update(n.metrics);
    return false;
  }

  bool _onScroll(ScrollNotification n) {
    if (n.metrics.axis == Axis.horizontal) _update(n.metrics);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    // Always masked, so the scroll position survives the fade coming and going.
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (rect) {
        final edge = (_fade / rect.width).clamp(0.0, 0.5);
        return LinearGradient(
          colors: [
            _moreLeft ? Colors.transparent : Colors.black,
            Colors.black,
            Colors.black,
            _moreRight ? Colors.transparent : Colors.black,
          ],
          stops: [0, edge, 1 - edge, 1],
        ).createShader(rect);
      },
      child: NotificationListener<ScrollMetricsNotification>(
        onNotification: _onMetrics,
        child: NotificationListener<ScrollNotification>(
          onNotification: _onScroll,
          child: SingleChildScrollView(controller: _controller, scrollDirection: Axis.horizontal, child: widget.child),
        ),
      ),
    );
  }
}
