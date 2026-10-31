import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Purely decorative VFX for the existing two updater authorization gestures.
/// Never reads NFC identifiers, authorizes an update, or touches its transport.
class HenshinVfx extends StatefulWidget {
  const HenshinVfx({
    required this.progress,
    required this.successToken,
    required this.failureToken,
    this.manual = false,
    this.height = 206,
    super.key,
  });

  final double progress;
  final int successToken;
  final int failureToken;
  final bool manual;
  final double height;

  @override
  State<HenshinVfx> createState() => _HenshinVfxState();
}

class _HenshinVfxState extends State<HenshinVfx>
    with TickerProviderStateMixin {
  late final AnimationController _idle = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 12),
  )..repeat();
  late final AnimationController _burst = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1250),
  );
  late final AnimationController _rejected = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 470),
  );

  @override
  void initState() {
    super.initState();
    // Native NFC acceptance can advance to downloading before Flutter draws
    // the waiting frame. Do not miss the one-shot burst on first paint.
    if (widget.successToken > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _burst.forward(from: 0);
      });
    }
  }

  @override
  void didUpdateWidget(covariant HenshinVfx oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.successToken != oldWidget.successToken) {
      _rejected.reset();
      _burst.forward(from: 0);
    } else if (widget.failureToken != oldWidget.failureToken) {
      _burst.reset();
      _rejected.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _idle.dispose();
    _burst.dispose();
    _rejected.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (reduceMotion && _idle.isAnimating) _idle.stop();
    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: Listenable.merge(<Listenable>[
            _idle,
            _burst,
            _rejected,
          ]),
          builder: (context, _) => CustomPaint(
            painter: _HenshinPainter(
              spin: _idle.value,
              charge: widget.progress.clamp(0.0, 1.0),
              burst: reduceMotion ? (_burst.value > 0 ? 1 : 0) : _burst.value,
              rejected: _rejected.value,
              manual: widget.manual,
            ),
            child: Center(
              child: Opacity(
                opacity: _burst.value > .34 && _burst.value < .93 ? 0 : 1,
                child: Icon(
                  widget.manual ? Icons.touch_app_rounded : Icons.nfc_rounded,
                  size: 36,
                  color: _burst.value > .44
                      ? const Color(0xFFFFE37A)
                      : const Color(0xFFFF95C4),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HenshinPainter extends CustomPainter {
  const _HenshinPainter({
    required this.spin,
    required this.charge,
    required this.burst,
    required this.rejected,
    required this.manual,
  });

  final double spin;
  final double charge;
  final double burst;
  final double rejected;
  final bool manual;

  static const pink = Color(0xFFFF4591);
  static const gold = Color(0xFFFFD85D);
  static const red = Color(0xFFFF666E);

  @override
  void paint(Canvas canvas, Size size) {
    final side = math.min(size.width, size.height) * .94;
    final radius = side * .34;
    final center = Offset(size.width / 2, size.height / 2);
    final success = burst > 0;
    final golden = success || (manual && charge > .72);
    final color = rejected > .05 ? red : (golden ? gold : pink);
    final rect = Rect.fromCircle(center: center, radius: radius);

    final ambient = Paint()
      ..shader = RadialGradient(
        colors: <Color>[
          color.withValues(alpha: .14 + charge * .10),
          color.withValues(alpha: .04),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius * 1.65));
    canvas.drawCircle(center, radius * 1.65, ambient);

    // A few broad driver-like arcs: physical, restrained, not a cyber HUD.
    final rim = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = color.withValues(alpha: .36);
    canvas.drawCircle(center, radius * 1.28, rim);
    canvas.drawCircle(
      center,
      radius * .73,
      rim..color = color.withValues(alpha: .48),
    );
    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 5
      ..color = color.withValues(alpha: .18)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawArc(rect, -math.pi / 2, math.pi * 2, false, glow);
    final segments = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.butt;
    for (var i = 0; i < 16; i++) {
      final start = i * math.pi / 8 + spin * math.pi * .4;
      segments.color = color.withValues(alpha: i.isEven ? .86 : .3);
      canvas.drawArc(rect, start, math.pi / 11, false, segments);
    }
    for (var i = 0; i < 8; i++) {
      final angle = i * math.pi / 4 - spin * math.pi * .21;
      final inner = center + Offset(
        math.cos(angle) * radius * 1.1,
        math.sin(angle) * radius * 1.1,
      );
      final outer = center + Offset(
        math.cos(angle) * radius * 1.25,
        math.sin(angle) * radius * 1.25,
      );
      canvas.drawLine(
        inner,
        outer,
        Paint()
          ..strokeWidth = i.isOdd ? 1 : 2
          ..color = color.withValues(alpha: .44),
      );
    }

    // Two seconds of manual charging are visualized as exact progress.
    if (manual && charge > 0) {
      final chargeRect = Rect.fromCircle(center: center, radius: radius * .86);
      canvas.drawArc(
        chargeRect,
        -math.pi / 2,
        math.pi * 2 * charge,
        false,
        Paint()
          ..color = golden ? gold : pink
          ..strokeWidth = 6
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke,
      );
      final endpoint = -math.pi / 2 + math.pi * 2 * charge;
      canvas.drawCircle(
        center + Offset(
          math.cos(endpoint) * radius * .86,
          math.sin(endpoint) * radius * .86,
        ),
        4,
        Paint()..color = Colors.white,
      );
    }

    // Angular abstract insignia, with no characters, helmets or rider assets.
    final diamond = Path()
      ..moveTo(center.dx, center.dy - radius * .46)
      ..lineTo(center.dx + radius * .35, center.dy)
      ..lineTo(center.dx, center.dy + radius * .46)
      ..lineTo(center.dx - radius * .35, center.dy)
      ..close();
    canvas.drawPath(
      diamond,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3
        ..color = color.withValues(alpha: .5),
    );

    // Verification: abrupt magenta→gold sweep, radial shards and clear seal.
    if (success) {
      final expansion = Curves.easeOutCubic.transform(burst);
      final fade = (1 - ((burst - .25) / .7)).clamp(0.0, 1.0);
      if (fade > 0) {
        final spark = Paint()
          ..strokeWidth = 2.3
          ..strokeCap = StrokeCap.round
          ..color = gold.withValues(alpha: fade * .9);
        for (var i = 0; i < 12; i++) {
          final a = (i / 12) * math.pi * 2 + math.pi / 16;
          final r1 = radius * (.8 + expansion * .75);
          final r2 = r1 + radius * .22;
          canvas.drawLine(
            center + Offset(math.cos(a) * r1, math.sin(a) * r1),
            center + Offset(math.cos(a) * r2, math.sin(a) * r2),
            spark,
          );
        }
        canvas.drawCircle(
          center,
          radius * (.65 + 1.4 * expansion),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3 * (1 - burst) + .5
            ..color = gold.withValues(alpha: fade),
        );
      }
      final sealAlpha = ((burst - .24) * 3).clamp(0.0, 1.0);
      final sealR = radius * .5;
      canvas.drawCircle(
        center,
        sealR,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = gold.withValues(alpha: sealAlpha),
      );
      final check = Path()
        ..moveTo(center.dx - sealR * .43, center.dy)
        ..lineTo(center.dx - sealR * .09, center.dy + sealR * .31)
        ..lineTo(center.dx + sealR * .45, center.dy - sealR * .32);
      canvas.drawPath(
        check,
        Paint()
          ..color = gold.withValues(alpha: sealAlpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }

    if (rejected > 0) {
      canvas.drawArc(
        rect,
        -math.pi / 2,
        math.pi * 2 * (1 - rejected),
        false,
        Paint()
          ..color = red.withValues(alpha: .75 * (1 - rejected))
          ..strokeWidth = 7
          ..style = PaintingStyle.stroke,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _HenshinPainter oldDelegate) =>
      spin != oldDelegate.spin ||
      charge != oldDelegate.charge ||
      burst != oldDelegate.burst ||
      rejected != oldDelegate.rejected ||
      manual != oldDelegate.manual;
}
