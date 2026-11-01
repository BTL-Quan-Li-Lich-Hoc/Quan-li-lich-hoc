import 'package:flutter/material.dart';


abstract final class TienMonGlassTokens {
  static const double cardBlur = 9;
  static const double sheetBlur = 15;
  static const double cardOpacity = .24;
  static const double sheetOpacity = .73;
  static const double borderOpacity = .58;
  static const double highlightOpacity = .32;
  static const double shadowOpacity = .34;
  static const double radius = 22;
  static const Color jade = Color(0xFF73D9BD);
  static const Color silver = Color(0xFFE8F2EE);
  static const Color ink = Color(0xFF071A19);
  static const Color gold = Color(0xFFD8B768);
}

class TienMonGlass extends StatelessWidget {
  const TienMonGlass({
    required this.child,
    super.key,
    this.padding = const EdgeInsets.all(14),
    this.radius = TienMonGlassTokens.radius,
    this.opaqueSheet = false,
    this.selected = false,
    this.borderColor,
    this.glowStrength = 0,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final bool opaqueSheet;
  final bool selected;
  final Color? borderColor;
  final double glowStrength;

  @override
  Widget build(BuildContext context) {
    final border =
        borderColor ??
        (selected ? TienMonGlassTokens.gold : TienMonGlassTokens.silver);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: TienMonGlassTokens.ink.withValues(alpha: .24),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
          if (glowStrength > 0)
            BoxShadow(
              color: border.withValues(alpha: .14 + glowStrength * .10),
              blurRadius: 8 + glowStrength * 6,
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            color: TienMonGlassTokens.ink.withValues(
              alpha: opaqueSheet ? .42 : .22,
            ),
            border: Border.all(
              color: border.withValues(alpha: selected ? .78 : .50),
            ),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                Colors.white.withValues(alpha: opaqueSheet ? .16 : .20),
                TienMonGlassTokens.ink.withValues(
                  alpha: opaqueSheet ? .58 : .28,
                ),
              ],
            ),
          ),
          child: Stack(
            children: <Widget>[
              child,
              Positioned(
                left: radius * .45,
                right: radius * .45,
                top: 0,
                height: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: <Color>[
                        Colors.transparent,
                        Colors.white.withValues(alpha: .26),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TienMonPressable extends StatefulWidget {
  const TienMonPressable({
    required this.child,
    required this.onTap,
    super.key,
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
  });

  final Widget child;
  final VoidCallback? onTap;
  final BorderRadius borderRadius;

  @override
  State<TienMonPressable> createState() => _TienMonPressableState();
}

class _TienMonPressableState extends State<TienMonPressable> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: Stack(
      children: <Widget>[
        widget.child,
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 90),
              decoration: BoxDecoration(
                borderRadius: widget.borderRadius,
                color: _pressed
                    ? Colors.white.withValues(alpha: .055)
                    : Colors.transparent,
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: widget.borderRadius,
              onTap: widget.onTap,
              onHighlightChanged: (value) => setState(() => _pressed = value),
              splashColor: Colors.white.withValues(alpha: .08),
              highlightColor: Colors.transparent,
            ),
          ),
        ),
      ],
    ),
  );
}
