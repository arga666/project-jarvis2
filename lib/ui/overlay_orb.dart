import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

class OverlayOrbWidget extends StatefulWidget {
  const OverlayOrbWidget({super.key});

  @override
  State<OverlayOrbWidget> createState() => _OverlayOrbWidgetState();
}

class _OverlayOrbWidgetState extends State<OverlayOrbWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  String _orbState = 'idle';

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    FlutterOverlayWindow.overlayListener.listen((event) {
      if (!mounted) return;
      setState(() => _orbState = event.toString());

      if (_orbState == 'speaking') {
        _controller.duration = const Duration(milliseconds: 380);
        _controller.repeat(reverse: true);
      } else if (_orbState == 'listening') {
        _controller.duration = const Duration(milliseconds: 700);
        _controller.repeat(reverse: true);
      } else if (_orbState == 'gaming_mode') {
        _controller.stop();
      } else {
        _controller.duration = const Duration(milliseconds: 1600);
        _controller.repeat(reverse: true);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_orbState == 'gaming_mode') return const SizedBox.shrink();

    return Material(
      color: Colors.transparent,
      child: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final double scale = 0.82 + (_controller.value * 0.25);
            final double glowBlur = _orbState == 'speaking'
                ? 28.0 * _controller.value
                : 12.0 * _controller.value;

            return Transform.scale(
              scale: scale,
              child: Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const RadialGradient(
                    colors: [
                      Color(0xFF2B72D6),
                      Color(0xFF0E2A5C),
                      Color(0xFF040B1A),
                    ],
                    stops: [0.15, 0.65, 1.0],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1E56A0).withOpacity(0.65),
                      blurRadius: glowBlur,
                      spreadRadius: _orbState == 'speaking' ? 6 : 2,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
