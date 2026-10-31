import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Flutter integration of experiments/vfx/bpa_pen_trace_splash.html.
/// The six source paths and 850 ms timing are intentionally kept unchanged.
class BpaPenTraceSplash extends StatefulWidget {
  const new({required this.child, super.key});

  final Widget child;

  @override
  State<BpaPenTraceSplash> createState() => _BpaPenTraceSplashState();
}

class _BpaPenTraceSplashState extends State<BpaPenTraceSplash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  );
  bool _visible = true;

  @override
  void initState() {
    super.initState();
    // Start the 1-second stroke animation after the first painted frame.
    // A slow cold-start frame must not consume the animation before it shows.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _controller.forward();
    });
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() => _visible = false);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    children: <Widget>[
      Positioned.fill(child: widget.child),
      if (_visible)
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final milliseconds = _controller.value * 1000;
                final opacity =
                    (milliseconds <= 850
                            ? 1.0
                            : (1 - (milliseconds - 850) / 150).clamp(0.0, 1.0))
                        .toDouble();
                return Opacity(
                  opacity: opacity,
                  child: ColoredBox(
                    color: Colors.white,
                    child: Center(
                      child: SizedBox.square(
                        dimension: math.min(
                          MediaQuery.sizeOf(context).width * .42,
                          172,
                        ),
                        child: CustomPaint(
                          painter: BpaPenTracePainter(milliseconds),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
    ],
  );
}

@visibleForTesting
class BpaPenTracePainter extends CustomPainter {
  BpaPenTracePainter(this.elapsedMilliseconds);

  final double elapsedMilliseconds;

  static const segmentTimes = <double>[0, 300, 510, 725, 770, 810, 850];

  static List<Path> buildPaths() => <Path>[
    Path()
      ..moveTo(52, 190)
      ..lineTo(52, 67)
      ..quadraticBezierTo(52, 42, 76, 42)
      ..lineTo(115, 42)
      ..quadraticBezierTo(152, 42, 152, 70)
      ..quadraticBezierTo(152, 92, 128, 104),
    Path()
      ..moveTo(128, 104)
      ..cubicTo(165, 91, 194, 116, 194, 147)
      ..cubicTo(194, 181, 165, 195, 134, 195)
      ..lineTo(52, 195),
    Path()
      ..moveTo(91, 188)
      ..lineTo(91, 130)
      ..quadraticBezierTo(91, 113, 110, 113)
      ..lineTo(129, 113)
      ..quadraticBezierTo(158, 113, 159, 140)
      ..quadraticBezierTo(159, 163, 128, 163)
      ..lineTo(96, 163),
    Path()
      ..moveTo(195, 75)
      ..lineTo(211, 52),
    Path()
      ..moveTo(205, 93)
      ..lineTo(227, 82),
    Path()
      ..moveTo(209, 111)
      ..lineTo(229, 117),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final scale = math.min(size.width / 230, size.height / 230);
    canvas
      ..save()
      ..translate(
        (size.width - 230 * scale) / 2,
        (size.height - 230 * scale) / 2,
      )
      ..scale(scale);
    final paths = buildPaths();
    ui.Offset? tip;
    var tipColor = const Color(0xFF286BD3);
    for (var index = 0; index < paths.length; index++) {
      final linear =
          (((elapsedMilliseconds - segmentTimes[index]) /
                      (segmentTimes[index + 1] - segmentTimes[index]))
                  .clamp(0.0, 1.0))
              .toDouble();
      final progress = linear * linear * (3 - 2 * linear);
      final metrics = paths[index].computeMetrics().toList(growable: false);
      final paint = Paint()
        ..color = index >= 3 ? const Color(0xFFF46D22) : const Color(0xFF163B70)
        ..style = PaintingStyle.stroke
        ..strokeWidth = index >= 3 ? 8 : 12
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      for (final metric in metrics) {
        canvas.drawPath(metric.extractPath(0, metric.length * progress), paint);
        if (elapsedMilliseconds >= segmentTimes[index] &&
            elapsedMilliseconds < segmentTimes[index + 1]) {
          tip = metric.getTangentForOffset(metric.length * progress)?.position;
          tipColor = index >= 3
              ? const Color(0xFFF46D22)
              : const Color(0xFF286BD3);
        }
      }
    }
    if (tip != null) {
      canvas
        ..drawCircle(tip, 11, Paint()..color = tipColor.withValues(alpha: .17))
        ..drawCircle(tip, 4, Paint()..color = tipColor);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant BpaPenTracePainter oldDelegate) =>
      oldDelegate.elapsedMilliseconds != elapsedMilliseconds;
}
