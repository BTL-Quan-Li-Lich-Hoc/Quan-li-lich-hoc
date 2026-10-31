import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../tien_mon_premium_contract.dart';

const List<(Color, Color)> _sceneEdgeColors = <(Color, Color)>[
  (Color(0xFF3E7383), Color(0xFF272628)),
  (Color(0xFF3A78B2), Color(0xFF312E2B)),
  (Color(0xFF074384), Color(0xFF2B2F2E)),
  (Color(0xFF1F3750), Color(0xFF201D1D)),
  (Color(0xFF3C252D), Color(0xFF1F1310)),
  (Color(0xFF031428), Color(0xFF13161D)),
  (Color(0xFF021326), Color(0xFF0E0F12)),
  (Color(0xFF03152D), Color(0xFF111217)),
];

enum _AmbientParticleKind { petal, leaf, none }

final ValueNotifier<bool> tienMonAmbientPaused = ValueNotifier<bool>(false);

void setTienMonAmbientPaused(bool paused) {
  if (tienMonAmbientPaused.value == paused) return;
  tienMonAmbientPaused.value = paused;
}


// Runtime test feedback: the previous 1.50x pass still read as almost static.
// Keep the motion slow, but make its displacement/density unmistakable and
// separately boost alpha so mist/light/shimmer do not disappear into the art.
const double _ambientMotionStrength = 2.25;
const double _ambientDetailDensity = 2.25;
const double _ambientOpacityBoost = 3.00;

@immutable
class _AmbientProfile {
  const _AmbientProfile({
    required this.mistOpacity,
    required this.mistSpeed,
    required this.hazeOpacity,
    required this.lightPulse,
    required this.particleKind,
    required this.particleCount,
    required this.particleSpeed,
    required this.shimmerEnabled,
    required this.shimmerOpacity,
    required this.lightCenter,
    required this.shimmerTop,
  });

  final double mistOpacity;
  final double mistSpeed;
  final double hazeOpacity;
  final double lightPulse;
  final _AmbientParticleKind particleKind;
  final int particleCount;
  final double particleSpeed;
  final bool shimmerEnabled;
  final double shimmerOpacity;
  final Offset lightCenter;
  final double shimmerTop;
}

const List<_AmbientProfile> _ambientProfiles = <_AmbientProfile>[
  _AmbientProfile(
    mistOpacity: .16,
    mistSpeed: .92,
    hazeOpacity: .075,
    lightPulse: .10,
    particleKind: _AmbientParticleKind.petal,
    particleCount: 4,
    particleSpeed: 1.04,
    shimmerEnabled: true,
    shimmerOpacity: .055,
    lightCenter: Offset(.72, .20),
    shimmerTop: .73,
  ),
  _AmbientProfile(
    mistOpacity: .14,
    mistSpeed: 1.02,
    hazeOpacity: .065,
    lightPulse: .085,
    particleKind: _AmbientParticleKind.petal,
    particleCount: 5,
    particleSpeed: 1.10,
    shimmerEnabled: true,
    shimmerOpacity: .05,
    lightCenter: Offset(.68, .18),
    shimmerTop: .73,
  ),
  _AmbientProfile(
    mistOpacity: .095,
    mistSpeed: .82,
    hazeOpacity: .045,
    lightPulse: .055,
    particleKind: _AmbientParticleKind.leaf,
    particleCount: 4,
    particleSpeed: .94,
    shimmerEnabled: true,
    shimmerOpacity: .045,
    lightCenter: Offset(.66, .16),
    shimmerTop: .74,
  ),
  _AmbientProfile(
    mistOpacity: .11,
    mistSpeed: .88,
    hazeOpacity: .052,
    lightPulse: .065,
    particleKind: _AmbientParticleKind.leaf,
    particleCount: 4,
    particleSpeed: .92,
    shimmerEnabled: true,
    shimmerOpacity: .048,
    lightCenter: Offset(.61, .22),
    shimmerTop: .74,
  ),
  _AmbientProfile(
    mistOpacity: .17,
    mistSpeed: .94,
    hazeOpacity: .085,
    lightPulse: .12,
    particleKind: _AmbientParticleKind.petal,
    particleCount: 4,
    particleSpeed: .90,
    shimmerEnabled: true,
    shimmerOpacity: .06,
    lightCenter: Offset(.58, .25),
    shimmerTop: .74,
  ),
  _AmbientProfile(
    mistOpacity: .15,
    mistSpeed: .80,
    hazeOpacity: .07,
    lightPulse: .07,
    particleKind: _AmbientParticleKind.leaf,
    particleCount: 3,
    particleSpeed: .82,
    shimmerEnabled: true,
    shimmerOpacity: .042,
    lightCenter: Offset(.55, .24),
    shimmerTop: .75,
  ),
  _AmbientProfile(
    mistOpacity: .105,
    mistSpeed: .66,
    hazeOpacity: .055,
    lightPulse: .045,
    particleKind: _AmbientParticleKind.none,
    particleCount: 0,
    particleSpeed: .70,
    shimmerEnabled: true,
    shimmerOpacity: .028,
    lightCenter: Offset(.52, .20),
    shimmerTop: .76,
  ),
  _AmbientProfile(
    mistOpacity: .09,
    mistSpeed: .58,
    hazeOpacity: .045,
    lightPulse: .038,
    particleKind: _AmbientParticleKind.none,
    particleCount: 0,
    particleSpeed: .64,
    shimmerEnabled: true,
    shimmerOpacity: .022,
    lightCenter: Offset(.50, .18),
    shimmerTop: .76,
  ),
];

class TienMonSceneController extends ChangeNotifier {
  TienMonSceneController({DateTime Function()? clock})
    : _clock = clock ?? DateTime.now {
    _scene = TienMonPremiumContract.appSceneFor(_clock());
    _scheduleNextBoundary();
  }

  final DateTime Function() _clock;
  late int _scene;
  bool _automatic = true;
  Timer? _timer;

  int get scene => _scene;
  bool get automatic => _automatic;

  void select(int scene) {
    final automaticChanged = _automatic;
    _automatic = false;
    _timer?.cancel();
    _timer = null;
    final sceneChanged = _setScene(scene < 1 ? 1 : (scene > 8 ? 8 : scene));
    if (automaticChanged && !sceneChanged) notifyListeners();
  }

  void previous() => select(_scene == 1 ? 8 : _scene - 1);
  void next() => select(_scene == 8 ? 1 : _scene + 1);

  void useAutomatic() {
    final automaticChanged = !_automatic;
    _automatic = true;
    final sceneChanged = _resolveAuto();
    _scheduleNextBoundary();
    if (automaticChanged && !sceneChanged) notifyListeners();
  }

  bool _resolveAuto() {
    if (!_automatic) return false;
    return _setScene(TienMonPremiumContract.appSceneFor(_clock()));
  }

  void _scheduleNextBoundary() {
    _timer?.cancel();
    _timer = null;
    if (!_automatic) return;

    final now = _clock();
    final next = TienMonPremiumContract.nextAppSceneBoundaryAfter(now);
    final delay = next.difference(now);
    _timer = Timer(
      delay.isNegative || delay == Duration.zero
          ? const Duration(milliseconds: 1)
          : delay,
      () {
        if (!_automatic) return;
        _resolveAuto();
        _scheduleNextBoundary();
      },
    );
  }

  bool _setScene(int value) {
    if (_scene == value) return false;
    _scene = value;
    notifyListeners();
    return true;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

class TienMonPersistentBackground extends StatefulWidget {
  const TienMonPersistentBackground({required this.controller, super.key});

  final TienMonSceneController controller;

  @override
  State<TienMonPersistentBackground> createState() =>
      _TienMonPersistentBackgroundState();
}

class _TienMonPersistentBackgroundState
    extends State<TienMonPersistentBackground> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
  }

  @override
  void didUpdateWidget(covariant TienMonPersistentBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_changed);
      widget.controller.addListener(_changed);
    }
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scene = widget.controller.scene;
    final asset = TienMonPremiumContract.appSceneAssets[scene - 1];
    final edgeColors = _sceneEdgeColors[scene - 1];
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        _SceneEdgeExtension(
          scene: scene,
          topColor: edgeColors.$1,
          bottomColor: edgeColors.$2,
        ),
        AnimatedSwitcher(
          duration: TienMonPremiumContract.sceneCrossfade,
          switchInCurve: Curves.easeInOutCubic,
          switchOutCurve: Curves.easeInOutCubic,
          layoutBuilder: (current, previous) => Stack(
            fit: StackFit.expand,
            children: <Widget>[...previous, if (current != null) current],
          ),
          child: _FullBleedSceneArtwork(
            key: ValueKey<String>(asset),
            asset: asset,
          ),
        ),
      ],
    );
  }
}

class TienMonPersistentAmbient extends StatefulWidget {
  const TienMonPersistentAmbient({required this.controller, super.key});

  final TienMonSceneController controller;

  @override
  State<TienMonPersistentAmbient> createState() =>
      _TienMonPersistentAmbientState();
}

class _TienMonPersistentAmbientState extends State<TienMonPersistentAmbient> {
  late int _scene;

  @override
  void initState() {
    super.initState();
    _scene = widget.controller.scene;
    widget.controller.addListener(_handleSceneChanged);
  }

  @override
  void didUpdateWidget(covariant TienMonPersistentAmbient oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_handleSceneChanged);
      widget.controller.addListener(_handleSceneChanged);
      _scene = widget.controller.scene;
    }
  }

  void _handleSceneChanged() {
    final nextScene = widget.controller.scene;
    if (nextScene == _scene || !mounted) return;
    setState(() => _scene = nextScene);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleSceneChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: TienMonPremiumContract.sceneCrossfade,
    switchInCurve: Curves.easeInOutCubic,
    switchOutCurve: Curves.easeInOutCubic,
    layoutBuilder: (current, previous) => Stack(
      fit: StackFit.expand,
      children: <Widget>[...previous, if (current != null) current],
    ),
    child: _AmbientMotion(key: ValueKey<int>(_scene), scene: _scene),
  );
}

class _FullBleedSceneArtwork extends StatelessWidget {
  const _FullBleedSceneArtwork({required this.asset, super.key});

  final String asset;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final targetHeight = (media.size.height * media.devicePixelRatio)
        .round()
        .clamp(1280, 2560)
        .toInt();
    return SizedBox.expand(
      child: Image.asset(
        asset,
        fit: BoxFit.cover,
        alignment: Alignment.center,
        gaplessPlayback: true,
        filterQuality: FilterQuality.medium,
        cacheHeight: targetHeight,
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          if (wasSynchronouslyLoaded) return child;
          return AnimatedOpacity(
            opacity: frame == null ? 0 : 1,
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            child: child,
          );
        },
      ),
    );
  }
}

class _EdgeBlendMist extends StatelessWidget {
  const _EdgeBlendMist({required this.vertical, required this.gap});

  final bool vertical;
  final double gap;

  @override
  Widget build(BuildContext context) {
    if (gap <= 0) return const SizedBox.shrink();
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: vertical ? Alignment.topCenter : Alignment.centerLeft,
            end: vertical ? Alignment.bottomCenter : Alignment.centerRight,
            colors: <Color>[
              Colors.black.withValues(alpha: .10),
              Colors.transparent,
              Colors.transparent,
              Colors.black.withValues(alpha: .10),
            ],
            stops: const <double>[0, .16, .84, 1],
          ),
        ),
      ),
    );
  }
}

class _SceneEdgeExtension extends StatelessWidget {
  const _SceneEdgeExtension({
    required this.scene,
    required this.topColor,
    required this.bottomColor,
  });

  final int scene;
  final Color topColor;
  final Color bottomColor;

  @override
  Widget build(BuildContext context) => const ColoredBox(color: Colors.black);
}

class _AmbientMotion extends StatefulWidget {
  const _AmbientMotion({required this.scene, super.key});

  final int scene;

  @override
  State<_AmbientMotion> createState() => _AmbientMotionState();
}

class _AmbientMotionState extends State<_AmbientMotion>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 72),
  );
  late final DateTime _startedAt = DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller.repeat();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (!_controller.isAnimating) _controller.repeat();
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      if (_controller.isAnimating) {
        _controller.stop(canceled: false);
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final elapsedSeconds =
              DateTime.now().difference(_startedAt).inMicroseconds /
              Duration.microsecondsPerSecond;
          return CustomPaint(
            painter: _AmbientPainter(
              elapsedSeconds: elapsedSeconds,
              profile: _ambientProfiles[widget.scene - 1],
              scene: widget.scene,
            ),
          );
        },
      ),
    ),
  );
}

class _AmbientPainter extends CustomPainter {
  const _AmbientPainter({
    required this.elapsedSeconds,
    required this.profile,
    required this.scene,
  });

  final double elapsedSeconds;
  final _AmbientProfile profile;
  final int scene;

  @override
  void paint(Canvas canvas, Size size) {
    _paintMist(canvas, size);
    _paintLocalLight(canvas, size);
    if (profile.shimmerEnabled) _paintWaterShimmer(canvas, size);
    if (profile.particleKind != _AmbientParticleKind.none) {
      _paintParticles(canvas, size);
    }
    _paintAmbientMotes(canvas, size);
  }

  void _paintMist(Canvas canvas, Size size) {
    final configs = <(double, double, double, double, double, double)>[
      (.30, .76, 1.40, .27, 0, 118),
      (.68, .50, 1.22, .22, 2.15, 153),
      (.44, .28, 1.55, .18, 4.32, 201),
    ];
    for (var index = 0; index < configs.length; index++) {
      final config = configs[index];
      final period = config.$6 / profile.mistSpeed;
      final phase = elapsedSeconds * math.pi * 2 / period + config.$5;
      final center = Offset(
        size.width * config.$1 +
            math.sin(phase) *
                size.width *
                (.105 + index * .0225) *
                _ambientMotionStrength,
        size.height * config.$2 +
            math.cos(phase * .71) * (10.5 + index * 3) * _ambientMotionStrength,
      );
      final rect = Rect.fromCenter(
        center: center,
        width: size.width * config.$3,
        height: size.height * config.$4,
      );
      final alpha =
          (profile.mistOpacity * _ambientOpacityBoost * (1 - index * .18))
              .clamp(0.0, .72)
              .toDouble();
      final paint = Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            Colors.white.withValues(alpha: alpha),
            Colors.white.withValues(alpha: alpha * .42),
            Colors.transparent,
          ],
          stops: const <double>[0, .48, 1],
        ).createShader(rect);
      canvas.drawOval(rect, paint);
    }

    final hazeBreathe =
        .88 + .12 * math.sin(elapsedSeconds * math.pi * 2 / 47 + scene * .43);
    final hazeRect = Rect.fromLTWH(
      0,
      size.height * .08,
      size.width,
      size.height * .50,
    );
    final haze = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[
          Colors.white.withValues(
            alpha:
                (profile.hazeOpacity * _ambientOpacityBoost * .35 * hazeBreathe)
                    .clamp(0.0, .48)
                    .toDouble(),
          ),
          Colors.white.withValues(
            alpha: (profile.hazeOpacity * _ambientOpacityBoost * hazeBreathe)
                .clamp(0.0, .62)
                .toDouble(),
          ),
          Colors.transparent,
        ],
      ).createShader(hazeRect);
    canvas.drawRect(hazeRect, haze);
  }

  void _paintLocalLight(Canvas canvas, Size size) {
    final breathe =
        .5 + .5 * math.sin(elapsedSeconds * math.pi * 2 / 29 + scene * .71);
    final center = Offset(
      size.width * profile.lightCenter.dx,
      size.height * profile.lightCenter.dy,
    );
    final rect = Rect.fromCenter(
      center: center,
      width: size.width * 1.05,
      height: size.height * .42,
    );
    final warm = scene == 5 || scene == 6;
    final lightColor = warm ? const Color(0xFFFFD39B) : Colors.white;
    final alpha =
        (profile.lightPulse * _ambientOpacityBoost * (.52 + breathe * .48))
            .clamp(0.0, .58)
            .toDouble();
    final paint = Paint()
      ..shader = RadialGradient(
        colors: <Color>[
          lightColor.withValues(alpha: alpha),
          lightColor.withValues(alpha: alpha * .30),
          Colors.transparent,
        ],
        stops: const <double>[0, .46, 1],
      ).createShader(rect);
    canvas.drawOval(rect, paint);
  }

  void _paintWaterShimmer(Canvas canvas, Size size) {
    final top = size.height * profile.shimmerTop;
    final bandHeight = size.height * .17;
    final shimmerPhase = (elapsedSeconds / 43) % 1;
    final travel = shimmerPhase * size.width;
    for (var index = 0; index < 6; index++) {
      final y = top + bandHeight * (.16 + index * .20);
      final width = size.width * (.22 + index * .045);
      final start =
          (travel + index * size.width * .27) % (size.width + width) - width;
      final path = Path()
        ..moveTo(start, y)
        ..quadraticBezierTo(
          start + width * .50,
          y +
              math.sin(elapsedSeconds * math.pi * 2 / 13 + index * 1.17) *
                  3.75 *
                  _ambientMotionStrength,
          start + width,
          y,
        );
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1 + index * .18
        ..strokeCap = StrokeCap.round
        ..color = Colors.white.withValues(
          alpha:
              (profile.shimmerOpacity *
                      _ambientOpacityBoost *
                      (1 - index * .09))
                  .clamp(0.0, .42)
                  .toDouble(),
        );
      canvas.drawPath(path, paint);
    }
  }

  void _paintParticles(Canvas canvas, Size size) {
    final visibleCount = (profile.particleCount * _ambientDetailDensity).ceil();
    for (var index = 0; index < visibleCount; index++) {
      final phase = (index * .173 + .07) % 1;
      final travelSeconds = (56 + index * 9) / profile.particleSpeed;
      final p = (elapsedSeconds / travelSeconds + phase) % 1;
      final swayPhase = p * math.pi * 5 + index * 1.31;
      final x =
          -size.width * .08 +
          p * size.width * 1.16 +
          math.sin(swayPhase) * 9 * _ambientMotionStrength;
      final y =
          -size.height * .09 +
          p * size.height * 1.18 +
          math.cos(swayPhase * .82) * 6 * _ambientMotionStrength;
      final opacity =
          math.sin(p * math.pi).clamp(0.0, 1.0).toDouble() *
          ((.18 + (index % 2) * .045) * _ambientOpacityBoost);
      final safeOpacity = opacity.clamp(0.0, .92).toDouble();
      if (safeOpacity <= .01) continue;
      final rotation = .35 + math.sin(swayPhase * .63) * .28 + index * .11;
      final scale = .72 + (index % 3) * .14;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(rotation);
      canvas.scale(scale);
      final paint = Paint()
        ..color =
            (profile.particleKind == _AmbientParticleKind.petal
                    ? const Color(0xFFFFE3E6)
                    : const Color(0xFFBFDDA8))
                .withValues(alpha: safeOpacity);
      canvas.drawPath(
        profile.particleKind == _AmbientParticleKind.petal
            ? _petalPath()
            : _leafPath(),
        paint,
      );
      canvas.restore();
    }
  }

  void _paintAmbientMotes(Canvas canvas, Size size) {
    // Tiny drifting details make the scene read as alive even when petals/leaves
    // are between passes. Keep them sparse, slow and low-contrast.
    final baseCount = scene <= 6 ? 10 : 7;
    final count = (baseCount * _ambientDetailDensity).ceil();
    for (var index = 0; index < count; index++) {
      final travel = 38.0 + (index % 5) * 7.0;
      final p = (elapsedSeconds / travel + index * .127) % 1;
      final phase = p * math.pi * 2 + index * .93;
      final x =
          ((index * .173) % 1) * size.width +
          math.sin(phase * .71) * size.width * .028 * _ambientMotionStrength;
      final y = ((index * .091 + p * .34) % 1) * size.height;
      final twinkle = .45 + .55 * math.sin(phase).abs();
      final alpha =
          ((scene <= 5 ? .105 : .065) * _ambientOpacityBoost * twinkle)
              .clamp(0.0, .34)
              .toDouble();
      final radius = .7 + (index % 3) * .45;
      final paint = Paint()
        ..color =
            (scene == 5 || scene == 6
                    ? const Color(0xFFFFE0A8)
                    : const Color(0xFFE6F7F2))
                .withValues(alpha: alpha);
      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  Path _petalPath() => Path()
    ..moveTo(0, -6)
    ..cubicTo(5, -4, 6, 1, 1, 7)
    ..cubicTo(-3, 5, -5, 1, 0, -6)
    ..close();

  Path _leafPath() => Path()
    ..moveTo(-1, -7)
    ..cubicTo(6, -5, 7, 1, 1, 7)
    ..cubicTo(-5, 3, -6, -3, -1, -7)
    ..moveTo(-1, -6)
    ..lineTo(1, 6);

  @override
  bool shouldRepaint(covariant _AmbientPainter oldDelegate) =>
      oldDelegate.elapsedSeconds != elapsedSeconds ||
      oldDelegate.profile != profile ||
      oldDelegate.scene != scene;
}
