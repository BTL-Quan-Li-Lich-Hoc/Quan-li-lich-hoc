import 'package:better_phenikaa_schedule/theme/app_theme.dart';
import 'package:flutter/material.dart';

import '../glass/tien_mon_glass.dart';
import '../tien_mon_premium_contract.dart';
import '../tien_mon_premium_models.dart';
import '../tien_mon_safe_text.dart';

class TienMonEdgeSurface extends StatefulWidget {
  const TienMonEdgeSurface({
    required this.child,
    super.key,
    this.active = false,
    this.compact = false,
    this.scene = 5,
    this.padding,
  });

  final Widget child;
  final bool active;
  final bool compact;
  final int scene;
  final EdgeInsetsGeometry? padding;

  @override
  State<TienMonEdgeSurface> createState() => _TienMonEdgeSurfaceState();
}

class _TienMonEdgeSurfaceState extends State<TienMonEdgeSurface>
    with SingleTickerProviderStateMixin {
  late final AnimationController _glow = AnimationController(
    vsync: this,
    duration: TienMonPremiumContract.activeCardBreathingCycle,
  );

  @override
  void initState() {
    super.initState();
    if (widget.active) _glow.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant TienMonEdgeSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active == widget.active) return;
    if (widget.active) {
      _glow.repeat(reverse: true);
    } else {
      _glow
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _glow.dispose();
    super.dispose();
  }

  Color get _outline {
    if (widget.scene <= 2) return const Color(0xFF0C5D55);
    if (widget.scene <= 4) return const Color(0xFF0A4D65);
    if (widget.scene == 5) return const Color(0xFFFFC56A);
    if (widget.scene == 6) return const Color(0xFFE8C78A);
    return const Color(0xFF9BE8DD);
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _glow,
    builder: (context, child) {
      final border = widget.active
          ? Color.lerp(_outline, TienMonGlassTokens.gold, _glow.value)!
          : _outline;
      return Container(
        padding: widget.padding,
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(widget.compact ? 14 : 20),
          border: Border.all(
            color: border.withValues(alpha: widget.active ? .98 : .86),
            width: widget.active ? 1.55 : 1.15,
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: .38),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
            BoxShadow(
              color: border.withValues(
                alpha: widget.active ? .34 + _glow.value * .22 : .16,
              ),
              blurRadius: widget.active ? 14 : 7,
              spreadRadius: widget.active ? .5 : 0,
            ),
          ],
        ),
        child: Stack(
          children: <Widget>[
            Positioned(
              left: 10,
              right: 28,
              top: 0,
              height: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: <Color>[
                      Colors.transparent,
                      Colors.white.withValues(alpha: .92),
                      border.withValues(alpha: .42),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: .8,
              top: 14,
              bottom: 14,
              width: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[
                      Colors.white.withValues(alpha: .72),
                      border.withValues(alpha: .18),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            child!,
          ],
        ),
      );
    },
    child: widget.child,
  );
}

class TienMonScheduleCard extends StatefulWidget {
  const TienMonScheduleCard({
    required this.item,
    super.key,
    this.compact = false,
    this.reveal = 1,
    this.scene = 1,
  });

  final TienMonScheduleItem item;
  final bool compact;
  final double reveal;
  final int scene;

  @override
  State<TienMonScheduleCard> createState() => _TienMonScheduleCardState();
}

class _TienMonScheduleCardState extends State<TienMonScheduleCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _glow = AnimationController(
    vsync: this,
    duration: TienMonPremiumContract.activeCardBreathingCycle,
  );

  @override
  void initState() {
    super.initState();
    if (widget.item.isActive) _glow.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant TienMonScheduleCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.isActive == widget.item.isActive) return;
    if (widget.item.isActive) {
      _glow.repeat(reverse: true);
    } else {
      _glow
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _glow.dispose();
    super.dispose();
  }

  static const Color _textGold = Color(0xFFFFD66B);

  Color get _primaryText => _textGold;

  Color get _secondaryText => _textGold.withValues(alpha: .90);

  Color get _outline {
    if (widget.scene <= 2) return const Color(0xFF0C5D55);
    if (widget.scene <= 4) return const Color(0xFF0A4D65);
    if (widget.scene == 5) return const Color(0xFFFFC56A);
    if (widget.scene == 6) return const Color(0xFFE8C78A);
    return const Color(0xFF9BE8DD);
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _glow,
    builder: (context, child) {
      final border = widget.item.isActive
          ? Color.lerp(_outline, TienMonGlassTokens.gold, _glow.value)!
          : _outline;
      return Container(
        padding: EdgeInsets.all(widget.compact ? 9 : 13),
        decoration: BoxDecoration(
          // Intentionally no fill and no BackdropFilter: the painting stays
          // completely visible. The glass feeling comes from edge refraction.
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(widget.compact ? 14 : 20),
          border: Border.all(
            color: border.withValues(alpha: widget.item.isActive ? .98 : .86),
            width: widget.item.isActive ? 1.55 : 1.15,
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: .38),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
            BoxShadow(
              color: border.withValues(
                alpha: widget.item.isActive ? .34 + _glow.value * .22 : .16,
              ),
              blurRadius: widget.item.isActive ? 14 : 7,
              spreadRadius: widget.item.isActive ? .5 : 0,
            ),
          ],
        ),
        child: Stack(
          children: <Widget>[
            Positioned(
              left: 10,
              right: 28,
              top: 0,
              height: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: <Color>[
                      Colors.transparent,
                      Colors.white.withValues(alpha: .92),
                      border.withValues(alpha: .42),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: .8,
              top: 14,
              bottom: 14,
              width: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[
                      Colors.white.withValues(alpha: .72),
                      border.withValues(alpha: .18),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            child!,
          ],
        ),
      );
    },
    child: Opacity(
      opacity: widget.reveal.clamp(0.0, 1.0).toDouble(),
      child: Row(
        children: <Widget>[
          Container(
            width: 3,
            height: widget.compact ? 38 : 52,
            decoration: BoxDecoration(
              color: widget.item.isActive ? TienMonGlassTokens.gold : _outline,
              borderRadius: BorderRadius.circular(8),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withValues(alpha: .24),
                  blurRadius: 3,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                TienMonText(
                  widget.item.subject,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _primaryText,
                    fontWeight: FontWeight.w900,
                    shadows: tienMonTextShadows,
                  ),
                ),
                const SizedBox(height: 3),
                TienMonText(
                  '${widget.item.start} - ${widget.item.end}  ${widget.item.room}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: widget.compact ? 10 : 12,
                    color: _secondaryText,
                    fontWeight: FontWeight.w800,
                    shadows: tienMonTextShadows,
                  ),
                ),
                if (!widget.compact)
                  TienMonText(
                    widget.item.periods,
                    style: TextStyle(
                      fontSize: 11,
                      color: _secondaryText,
                      fontWeight: FontWeight.w700,
                      shadows: tienMonTextShadows,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class TienMonDayView extends StatelessWidget {
  const TienMonDayView({required this.day, this.scene = 1, super.key});

  final TienMonDaySchedule day;
  final int scene;

  @override
  Widget build(BuildContext context) {
    if (day.items.isEmpty) {
      return const _ProductionEmptyDay();
    }
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 82),
      itemCount: day.items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 14),
      itemBuilder: (context, index) => TweenAnimationBuilder<double>(
        key: ValueKey<String>(day.items[index].id),
        duration: Duration(milliseconds: 220 + index * 50),
        curve: Curves.easeOutCubic,
        tween: Tween<double>(begin: 0, end: 1),
        builder: (context, value, _) => Transform.translate(
          offset: Offset(0, 14 * (1 - value)),
          child: TienMonScheduleCard(
            key: ValueKey<String>(day.items[index].id),
            item: day.items[index],
            reveal: value,
            scene: scene,
          ),
        ),
      ),
    );
  }
}

class TienMonWeekView extends StatelessWidget {
  const TienMonWeekView({required this.days, this.scene = 1, super.key});

  final List<TienMonDaySchedule> days;
  final int scene;

  static const List<String> _labels = <String>[
    'Thứ 2',
    'Thứ 3',
    'Thứ 4',
    'Thứ 5',
    'Thứ 6',
    'Thứ 7',
    'Chủ nhật',
  ];

  @override
  Widget build(BuildContext context) => ListView.separated(
    padding: const EdgeInsets.only(bottom: 86),
    itemCount: days.length,
    separatorBuilder: (_, __) => const SizedBox(height: 6),
    itemBuilder: (context, index) => TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 180 + index * 50),
      curve: Curves.easeOutCubic,
      tween: Tween<double>(begin: 0, end: 1),
      builder: (context, value, _) => Transform.translate(
        offset: Offset(0, 10 * (1 - value)),
        child: SizedBox(
          height: 86,
          child: TienMonGlass(
            radius: 15,
            padding: EdgeInsets.zero,
            child: Opacity(
              opacity: value,
              child: Row(
                children: <Widget>[
                  SizedBox(
                    width: 79,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 9),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          TienMonText(
                            _labels[index],
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          TienMonText(
                            _shortDate(days[index].date),
                            style: const TextStyle(fontSize: 12),
                          ),
                          if (days[index].items.isNotEmpty)
                            TienMonText(
                              '${days[index].items.length} buổi',
                              style: const TextStyle(
                                color: Color(0xE6FFD66B),
                                fontSize: 10,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: days[index].items.isEmpty
                        ? const Align(
                            alignment: Alignment.centerLeft,
                            child: TienMonText(
                              'Không có lịch học',
                              style: TextStyle(
                                color: Color(0xE6FFD66B),
                                fontSize: 12,
                              ),
                            ),
                          )
                        : ListView.separated(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(
                              vertical: 6,
                              horizontal: 3,
                            ),
                            itemCount: days[index].items.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 6),
                            itemBuilder: (context, itemIndex) => SizedBox(
                              width: 135,
                              child: TienMonScheduleCard(
                                item: days[index].items[itemIndex],
                                compact: true,
                                scene: scene,
                              ),
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );

  static String _shortDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';
}

class _ProductionEmptyDay extends StatelessWidget {
  const _ProductionEmptyDay();

  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(
      padding: EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            Icons.event_available_outlined,
            size: 52,
            color: Color(0x9973D9BD),
          ),
          SizedBox(height: 14),
          TienMonText(
            'Không có lịch học',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
          ),
          SizedBox(height: 7),
          TienMonText(
            'Vuốt sang ngày khác, bấm ngày hoặc biểu tượng lịch để chọn nhanh.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xE6FFD66B),
              height: 1.45,
              fontSize: 13,
            ),
          ),
        ],
      ),
    ),
  );
}
