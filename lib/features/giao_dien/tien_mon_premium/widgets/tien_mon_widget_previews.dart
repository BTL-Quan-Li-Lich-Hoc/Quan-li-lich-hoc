import 'dart:async';

import 'package:flutter/material.dart';

import '../glass/tien_mon_glass.dart';
import '../tien_mon_premium_contract.dart';
import '../tien_mon_premium_models.dart';
import '../tien_mon_safe_text.dart';

@immutable
class _OverviewPreviewItem {
  const _OverviewPreviewItem({
    required this.time,
    required this.subject,
    required this.room,
    this.date,
    this.active = false,
  });

  final String time;
  final String subject;
  final String room;
  final String? date;
  final bool active;
}

class TienMonOverviewWidgetPreview extends StatefulWidget {
  const TienMonOverviewWidgetPreview({
    required this.scene,
    required this.mode,
    required this.syncState,
    super.key,
  });

  final TienMonOverviewWidgetScene scene;
  final TienMonScheduleMode mode;
  final TienMonSyncState syncState;

  @override
  State<TienMonOverviewWidgetPreview> createState() =>
      _TienMonOverviewWidgetPreviewState();
}

class _TienMonOverviewWidgetPreviewState
    extends State<TienMonOverviewWidgetPreview>
    with TickerProviderStateMixin {
  static const Duration _f3ModeFade = Duration(milliseconds: 480);
  static const Duration _f3WindowTransition = Duration(milliseconds: 190);

  late TienMonScheduleMode _mode = widget.mode;
  late TienMonSyncState _sync = widget.syncState;
  int _dateOffset = 0;
  int _direction = 0;
  Timer? _syncTimer;
  Timer? _tickTimer;

  late final AnimationController _reload = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 820),
  );

  static const List<_OverviewPreviewItem> _studyToday = <_OverviewPreviewItem>[
    _OverviewPreviewItem(
      time: '09:30',
      subject: 'LTTBDD',
      room: 'A6-503 (PC)',
      active: true,
    ),
    _OverviewPreviewItem(time: '15:45', subject: 'TKWNC', room: 'A6-105 (PC)'),
  ];

  static const List<_OverviewPreviewItem> _studyTomorrow =
      <_OverviewPreviewItem>[
        _OverviewPreviewItem(time: '07:00', subject: 'PTTKHT', room: 'A2-301'),
        _OverviewPreviewItem(time: '13:00', subject: 'ATTT', room: 'A4-402'),
      ];

  static const List<_OverviewPreviewItem> _examToday = <_OverviewPreviewItem>[
    _OverviewPreviewItem(
      date: '02/10',
      time: '08:00',
      subject: 'TTNT (TL)',
      room: 'A2-402',
    ),
    _OverviewPreviewItem(
      date: '06/10',
      time: '13:30',
      subject: 'ATTT (TN)',
      room: 'A6-205',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _applySyncState(_sync);
  }

  @override
  void didUpdateWidget(covariant TienMonOverviewWidgetPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mode != widget.mode && _mode != widget.mode) {
      setState(() {
        _mode = widget.mode;
        _dateOffset = 0;
        _direction = 0;
      });
    }
    if (oldWidget.syncState != widget.syncState) {
      _sync = widget.syncState;
      _applySyncState(_sync);
    }
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    _tickTimer?.cancel();
    _reload.dispose();
    super.dispose();
  }

  String get _asset => switch (widget.scene) {
    TienMonOverviewWidgetScene.morning =>
      TienMonPremiumContract.widgetMorningAsset,
    TienMonOverviewWidgetScene.afternoon =>
      TienMonPremiumContract.widgetAfternoonAsset,
    TienMonOverviewWidgetScene.night => TienMonPremiumContract.widgetNightAsset,
  };

  List<_OverviewPreviewItem> get _items {
    if (_mode == TienMonScheduleMode.exam) return _examToday;
    return _dateOffset == 0 ? _studyToday : _studyTomorrow;
  }

  String get _dateLabel =>
      _dateOffset == 0 ? 'Hôm nay \u00B7 29/09' : 'Ngày mai \u00B7 30/09';

  void _applySyncState(TienMonSyncState state) {
    if (state == TienMonSyncState.loading) {
      if (!_reload.isAnimating) _reload.repeat();
    } else {
      _reload
        ..stop()
        ..value = 0;
    }
  }

  void _manualRefresh() {
    _syncTimer?.cancel();
    _tickTimer?.cancel();
    setState(() => _sync = TienMonSyncState.loading);
    _applySyncState(_sync);
    _syncTimer = Timer(const Duration(milliseconds: 1150), () {
      if (!mounted) return;
      setState(() => _sync = TienMonSyncState.success);
      _applySyncState(_sync);
      _tickTimer = Timer(const Duration(milliseconds: 1400), () {
        if (!mounted) return;
        setState(() => _sync = TienMonSyncState.idle);
        _applySyncState(_sync);
      });
    });
  }

  void _toggleMode() {
    setState(() {
      _mode = _mode == TienMonScheduleMode.study
          ? TienMonScheduleMode.exam
          : TienMonScheduleMode.study;
      _dateOffset = 0;
      _direction = 0;
    });
  }

  void _navigate(int direction) {
    final next = (_dateOffset + direction).clamp(-1, 1);
    if (next == _dateOffset) return;
    setState(() {
      _direction = direction;
      _dateOffset = next;
    });
  }

  static const Color _premiumGold = Color(0xFFFFD66B);

  Color get _iconColor => _premiumGold;

  Color get _headerText => _premiumGold;

  @override
  Widget build(BuildContext context) => AspectRatio(
    // Matches the production 4x2 family much more closely than the old
    // Claude-only layout. The skin changes; the DemoF3 hierarchy does not.
    aspectRatio: 2.68,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Image.asset(
            _asset,
            fit: BoxFit.cover,
            alignment: Alignment.center,
            gaplessPlayback: true,
          ),
          // A very small legibility veil, not a layout element. It never alters
          // the F3 positions and keeps the panorama visible.
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  Colors.black.withValues(
                    alpha: widget.scene == TienMonOverviewWidgetScene.morning
                        ? .08
                        : .18,
                  ),
                  Colors.transparent,
                  Colors.black.withValues(alpha: .12),
                ],
              ),
            ),
          ),
          AnimatedSwitcher(
            duration: _f3ModeFade,
            switchInCurve: Curves.easeInOut,
            switchOutCurve: Curves.easeInOut,
            transitionBuilder: (child, animation) =>
                FadeTransition(opacity: animation, child: child),
            child: _OverviewBody(
              key: ValueKey<TienMonScheduleMode>(_mode),
              mode: _mode,
              sync: _sync,
              reload: _reload,
              items: _items,
              dateLabel: _dateLabel,
              direction: _direction,
              iconColor: _iconColor,
              headerText: _headerText,
              onRefresh: _manualRefresh,
              onMode: _toggleMode,
              onPrevious: () => _navigate(-1),
              onNext: () => _navigate(1),
            ),
          ),
        ],
      ),
    ),
  );
}

class _OverviewBody extends StatelessWidget {
  const _OverviewBody({
    required this.mode,
    required this.sync,
    required this.reload,
    required this.items,
    required this.dateLabel,
    required this.direction,
    required this.iconColor,
    required this.headerText,
    required this.onRefresh,
    required this.onMode,
    required this.onPrevious,
    required this.onNext,
    super.key,
  });

  final TienMonScheduleMode mode;
  final TienMonSyncState sync;
  final Animation<double> reload;
  final List<_OverviewPreviewItem> items;
  final String dateLabel;
  final int direction;
  final Color iconColor;
  final Color headerText;
  final VoidCallback onRefresh;
  final VoidCallback onMode;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 4, 12, 3),
    child: Column(
      children: <Widget>[
        SizedBox(
          height: 37,
          child: Row(
            children: <Widget>[
              Icon(
                mode == TienMonScheduleMode.study
                    ? Icons.school_rounded
                    : Icons.event_available_outlined,
                size: 25,
                color: headerText,
                shadows: const <Shadow>[
                  Shadow(color: Colors.black54, blurRadius: 4),
                ],
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    TienMonText(
                      mode == TienMonScheduleMode.study
                          ? dateLabel
                          : 'Lịch thi \u00B7 Học kỳ hiện tại',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: headerText,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w900,
                        shadows: const <Shadow>[
                          Shadow(color: Colors.black54, blurRadius: 4),
                        ],
                      ),
                    ),
                    TienMonText(
                      mode == TienMonScheduleMode.study
                          ? '${items.length} môn học'
                          : '${items.length} môn thi sắp tới',
                      style: TextStyle(
                        color: headerText.withValues(alpha: .78),
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        shadows: const <Shadow>[
                          Shadow(color: Colors.black54, blurRadius: 3),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              _PreviewIconButton(
                icon: Icons.calendar_month_outlined,
                color: iconColor,
                onTap: () {},
              ),
              const SizedBox(width: 2),
              _PreviewRefreshButton(
                sync: sync,
                rotation: reload,
                color: iconColor,
                onTap: onRefresh,
              ),
              const SizedBox(width: 2),
              _PreviewIconButton(
                icon: mode == TienMonScheduleMode.exam
                    ? Icons.arrow_back_rounded
                    : Icons.notifications_rounded,
                color: mode == TienMonScheduleMode.study
                    ? const Color(0xFFE65050)
                    : iconColor,
                onTap: onMode,
              ),
            ],
          ),
        ),
        const SizedBox(height: 2),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 190),
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position:
                    Tween<Offset>(
                      begin: Offset(.08 * direction, 0),
                      end: Offset.zero,
                    ).animate(
                      CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeOutCubic,
                      ),
                    ),
                child: child,
              ),
            ),
            child: _OverviewCards(
              key: ValueKey<String>('$dateLabel-$mode'),
              items: items,
              mode: mode,
            ),
          ),
        ),
        SizedBox(
          height: 18,
          child: Row(
            children: <Widget>[
              _PreviewIconButton(
                icon: Icons.chevron_left_rounded,
                color: iconColor.withValues(alpha: .82),
                onTap: onPrevious,
                compact: true,
              ),
              Expanded(
                child: CustomPaint(
                  painter: _F3TimelinePainter(
                    count: items.length,
                    active: items.indexWhere((item) => item.active),
                    color: TienMonGlassTokens.jade,
                    track: const Color(0xFFFFD66B).withValues(alpha: .72),
                  ),
                ),
              ),
              _PreviewIconButton(
                icon: Icons.chevron_right_rounded,
                color: iconColor.withValues(alpha: .82),
                onTap: onNext,
                compact: true,
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _OverviewCards extends StatelessWidget {
  const _OverviewCards({required this.items, required this.mode, super.key});

  final List<_OverviewPreviewItem> items;
  final TienMonScheduleMode mode;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      const columns = 4;
      const gap = 5.0;
      final cardWidth = (constraints.maxWidth - gap * (columns - 1)) / columns;
      return Align(
        alignment: Alignment.topLeft,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: List<Widget>.generate(columns, (index) {
            if (index >= items.length) {
              return Padding(
                padding: EdgeInsets.only(right: index == columns - 1 ? 0 : gap),
                child: SizedBox(width: cardWidth),
              );
            }
            return Padding(
              padding: EdgeInsets.only(right: index == columns - 1 ? 0 : gap),
              child: SizedBox(
                width: cardWidth,
                child: _F3SkinnedCard(
                  item: items[index],
                  exam: mode == TienMonScheduleMode.exam,
                ),
              ),
            );
          }),
        ),
      );
    },
  );
}

class _F3SkinnedCard extends StatelessWidget {
  const _F3SkinnedCard({required this.item, required this.exam});

  final _OverviewPreviewItem item;
  final bool exam;

  @override
  Widget build(BuildContext context) => Container(
    height: 55,
    padding: const EdgeInsets.fromLTRB(7, 4, 7, 4),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(12),
      color: const Color(0xA0183431),
      border: Border.all(
        color: item.active ? const Color(0xFFD8B768) : const Color(0x9AE8F2EE),
        width: item.active ? 1.25 : .75,
      ),
      boxShadow: item.active
          ? const <BoxShadow>[
              BoxShadow(color: Color(0x6673D9BD), blurRadius: 8),
            ]
          : const <BoxShadow>[
              BoxShadow(color: Color(0x42000000), blurRadius: 4),
            ],
    ),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (exam && item.date != null)
          TienMonText(
            item.date!,
            style: const TextStyle(
              fontSize: 7.5,
              color: Color(0xFFE8D69A),
              height: 1,
            ),
          ),
        TienMonText(
          item.time,
          maxLines: 1,
          style: const TextStyle(
            fontSize: 14.5,
            height: 1,
            color: Color(0xFFFFF7E7),
            fontWeight: FontWeight.w900,
            shadows: <Shadow>[Shadow(color: Colors.black87, blurRadius: 3)],
          ),
        ),
        const SizedBox(height: 2),
        TienMonText(
          item.subject,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 8.2,
            height: 1,
            color: Colors.white,
            fontWeight: FontWeight.w800,
            shadows: <Shadow>[Shadow(color: Colors.black87, blurRadius: 3)],
          ),
        ),
        TienMonText(
          item.room,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 7.2,
            height: 1,
            color: Color(0xE8FFFFFF),
            shadows: <Shadow>[Shadow(color: Colors.black87, blurRadius: 3)],
          ),
        ),
      ],
    ),
  );
}

class _PreviewIconButton extends StatelessWidget {
  const _PreviewIconButton({
    required this.icon,
    required this.color,
    required this.onTap,
    this.compact = false,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) => InkResponse(
    onTap: onTap,
    radius: compact ? 12 : 16,
    child: SizedBox(
      width: compact ? 25 : 29,
      height: compact ? 18 : 31,
      child: Icon(
        icon,
        size: compact ? 16 : 19,
        color: color,
        shadows: const <Shadow>[Shadow(color: Colors.black54, blurRadius: 4)],
      ),
    ),
  );
}

class _PreviewRefreshButton extends StatelessWidget {
  const _PreviewRefreshButton({
    required this.sync,
    required this.rotation,
    required this.color,
    required this.onTap,
  });

  final TienMonSyncState sync;
  final Animation<double> rotation;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final icon = switch (sync) {
      TienMonSyncState.success => Icons.check_rounded,
      TienMonSyncState.failure => Icons.warning_amber_rounded,
      _ => Icons.refresh_rounded,
    };
    final iconColor = switch (sync) {
      TienMonSyncState.success => const Color(0xFF58E091),
      TienMonSyncState.failure => const Color(0xFFFF7B72),
      _ => color,
    };
    final child = Icon(
      icon,
      size: 19,
      color: iconColor,
      shadows: const <Shadow>[Shadow(color: Colors.black54, blurRadius: 4)],
    );
    return InkResponse(
      onTap: sync == TienMonSyncState.loading ? null : onTap,
      radius: 16,
      child: SizedBox(
        width: 29,
        height: 31,
        child: Center(
          child: sync == TienMonSyncState.loading
              ? RotationTransition(turns: rotation, child: child)
              : child,
        ),
      ),
    );
  }
}

class _F3TimelinePainter extends CustomPainter {
  const _F3TimelinePainter({
    required this.count,
    required this.active,
    required this.color,
    required this.track,
  });

  final int count;
  final int active;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;
    canvas.drawLine(
      Offset(3, y),
      Offset(size.width - 3, y),
      Paint()
        ..color = track
        ..strokeWidth = 1.2
        ..strokeCap = StrokeCap.round,
    );
    if (count <= 0) return;
    final step = size.width / (count + 1);
    for (var i = 0; i < count; i++) {
      final center = Offset(step * (i + 1), y);
      final selected = i == active;
      if (selected) {
        canvas.drawCircle(
          center,
          6.5,
          Paint()..color = Colors.white.withValues(alpha: .42),
        );
      }
      canvas.drawCircle(
        center,
        selected ? 4.8 : 3.5,
        Paint()..color = color.withValues(alpha: selected ? 1 : .88),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _F3TimelinePainter oldDelegate) =>
      oldDelegate.count != count ||
      oldDelegate.active != active ||
      oldDelegate.color != color ||
      oldDelegate.track != track;
}

class TienMonSmallWidgetPreview extends StatefulWidget {
  const TienMonSmallWidgetPreview({
    required this.mode,
    required this.syncState,
    super.key,
  });

  final TienMonScheduleMode mode;
  final TienMonSyncState syncState;

  @override
  State<TienMonSmallWidgetPreview> createState() =>
      _TienMonSmallWidgetPreviewState();
}

class _TienMonSmallWidgetPreviewState extends State<TienMonSmallWidgetPreview>
    with SingleTickerProviderStateMixin {
  static const Color _gold = Color(0xFFFFD66B);
  late TienMonScheduleMode _mode = widget.mode;
  late TienMonSyncState _sync = widget.syncState;
  int _dateOffset = 0;
  int _direction = 0;
  Timer? _syncTimer;
  Timer? _tickTimer;

  late final AnimationController _reload = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 820),
  );

  static const Map<int, _OverviewPreviewItem> _study =
      <int, _OverviewPreviewItem>{
        -1: _OverviewPreviewItem(
          date: '28/09',
          time: '13:00 - 15:40',
          subject: 'An toàn thông tin',
          room: 'A4-402',
        ),
        0: _OverviewPreviewItem(
          date: '29/09',
          time: '15:45 - 18:25',
          subject: 'Thiết kế web nâng cao',
          room: 'A6-105 (PC)',
          active: true,
        ),
        1: _OverviewPreviewItem(
          date: '30/09',
          time: '07:00 - 09:30',
          subject: 'Phân tích thiết kế hệ thống',
          room: 'A2-301',
        ),
      };

  static const Map<int, _OverviewPreviewItem> _exam =
      <int, _OverviewPreviewItem>{
        -1: _OverviewPreviewItem(
          date: '02/10',
          time: '08:00',
          subject: 'Trí tuệ nhân tạo',
          room: 'A2-402',
        ),
        0: _OverviewPreviewItem(
          date: '06/10',
          time: '13:30',
          subject: 'An toàn thông tin',
          room: 'A6-205',
        ),
        1: _OverviewPreviewItem(
          date: '10/10',
          time: '09:00',
          subject: 'Thiết kế web nâng cao',
          room: 'A6-301',
        ),
      };

  @override
  void initState() {
    super.initState();
    _applySyncState(_sync);
  }

  @override
  void didUpdateWidget(covariant TienMonSmallWidgetPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mode != widget.mode) {
      _mode = widget.mode;
      _dateOffset = 0;
      _direction = 0;
    }
    if (oldWidget.syncState != widget.syncState) {
      _sync = widget.syncState;
      _applySyncState(_sync);
    }
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    _tickTimer?.cancel();
    _reload.dispose();
    super.dispose();
  }

  _OverviewPreviewItem get _item =>
      (_mode == TienMonScheduleMode.study ? _study : _exam)[_dateOffset]!;

  void _applySyncState(TienMonSyncState state) {
    if (state == TienMonSyncState.loading) {
      if (!_reload.isAnimating) _reload.repeat();
    } else {
      _reload
        ..stop()
        ..value = 0;
    }
  }

  void _manualRefresh() {
    _syncTimer?.cancel();
    _tickTimer?.cancel();
    setState(() => _sync = TienMonSyncState.loading);
    _applySyncState(_sync);
    _syncTimer = Timer(const Duration(milliseconds: 1150), () {
      if (!mounted) return;
      setState(() => _sync = TienMonSyncState.success);
      _applySyncState(_sync);
      _tickTimer = Timer(const Duration(milliseconds: 1400), () {
        if (!mounted) return;
        setState(() => _sync = TienMonSyncState.idle);
        _applySyncState(_sync);
      });
    });
  }

  void _navigate(int direction) {
    final next = (_dateOffset + direction).clamp(-1, 1);
    if (next == _dateOffset) return;
    setState(() {
      _direction = direction;
      _dateOffset = next;
    });
  }

  void _toggleMode() {
    setState(() {
      _mode = _mode == TienMonScheduleMode.study
          ? TienMonScheduleMode.exam
          : TienMonScheduleMode.study;
      _dateOffset = 0;
      _direction = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final item = _item;
    return AspectRatio(
      // DemoF3 native small widget is a wide one-row widget (~640x150).
      aspectRatio: 4.27,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onVerticalDragEnd: (details) {
          final velocity = details.primaryVelocity ?? 0;
          if (velocity.abs() < 160) return;
          // Preserve DemoF3 direction: swipe down -> next day, up -> previous.
          _navigate(velocity > 0 ? 1 : -1);
        },
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _gold.withValues(alpha: .76), width: 1),
            gradient: const LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: <Color>[
                Color(0xFF082D2B),
                Color(0xFF155953),
                Color(0xFF667E7B),
              ],
              stops: <double>[0, .60, 1],
            ),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Color(0x55000000),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                const Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: 86,
                  child: CustomPaint(painter: _BambooPainter()),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 7, 50, 7),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 190),
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position:
                            Tween<Offset>(
                              begin: Offset(0, .14 * _direction),
                              end: Offset.zero,
                            ).animate(
                              CurvedAnimation(
                                parent: animation,
                                curve: Curves.easeOutCubic,
                              ),
                            ),
                        child: child,
                      ),
                    ),
                    child: _SmallF3Content(
                      key: ValueKey<String>('$_mode-$_dateOffset'),
                      item: item,
                      exam: _mode == TienMonScheduleMode.exam,
                    ),
                  ),
                ),
                Positioned(
                  right: 4,
                  top: 2,
                  bottom: 2,
                  width: 40,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: <Widget>[
                      _PreviewIconButton(
                        icon: Icons.calendar_month_outlined,
                        color: _gold,
                        onTap: () => setState(() {
                          _dateOffset = 0;
                          _direction = 0;
                        }),
                        compact: true,
                      ),
                      _SmallRefreshButton(
                        sync: _sync,
                        rotation: _reload,
                        onTap: _manualRefresh,
                      ),
                      _PreviewIconButton(
                        icon: _mode == TienMonScheduleMode.study
                            ? Icons.notifications_rounded
                            : Icons.arrow_back_rounded,
                        color: _mode == TienMonScheduleMode.study
                            ? const Color(0xFFFF5757)
                            : _gold,
                        onTap: _toggleMode,
                        compact: true,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SmallF3Content extends StatelessWidget {
  const _SmallF3Content({required this.item, required this.exam, super.key});

  final _OverviewPreviewItem item;
  final bool exam;
  static const Color _gold = Color(0xFFFFD66B);

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: <Widget>[
      TienMonText(
        item.subject,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: _gold,
          fontSize: 13,
          fontWeight: FontWeight.w900,
          shadows: <Shadow>[Shadow(color: Colors.black87, blurRadius: 4)],
        ),
      ),
      if (exam)
        const TienMonText(
          'Thi: Tự luận',
          maxLines: 1,
          style: TextStyle(
            color: _gold,
            fontSize: 8.5,
            fontWeight: FontWeight.w800,
            shadows: <Shadow>[Shadow(color: Colors.black87, blurRadius: 3)],
          ),
        ),
      Row(
        children: <Widget>[
          Expanded(
            child: TienMonText(
              '${item.room} \u00B7 ${item.date}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _gold,
                fontSize: 9,
                fontWeight: FontWeight.w700,
                shadows: <Shadow>[Shadow(color: Colors.black87, blurRadius: 3)],
              ),
            ),
          ),
          const SizedBox(width: 8),
          TienMonText(
            item.time,
            maxLines: 1,
            style: const TextStyle(
              color: _gold,
              fontSize: 9.5,
              fontWeight: FontWeight.w900,
              shadows: <Shadow>[Shadow(color: Colors.black87, blurRadius: 3)],
            ),
          ),
        ],
      ),
    ],
  );
}

class _SmallRefreshButton extends StatelessWidget {
  const _SmallRefreshButton({
    required this.sync,
    required this.rotation,
    required this.onTap,
  });

  final TienMonSyncState sync;
  final Animation<double> rotation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final icon = switch (sync) {
      TienMonSyncState.success => Icons.check_rounded,
      TienMonSyncState.failure => Icons.warning_amber_rounded,
      _ => Icons.refresh_rounded,
    };
    final color = switch (sync) {
      TienMonSyncState.success => const Color(0xFF63E79B),
      TienMonSyncState.failure => const Color(0xFFFF6B63),
      _ => const Color(0xFFFFD66B),
    };
    final child = Icon(
      icon,
      size: 16,
      color: color,
      shadows: const <Shadow>[Shadow(color: Colors.black87, blurRadius: 3)],
    );
    return InkResponse(
      onTap: sync == TienMonSyncState.loading ? null : onTap,
      radius: 12,
      child: SizedBox(
        width: 25,
        height: 18,
        child: Center(
          child: sync == TienMonSyncState.loading
              ? RotationTransition(turns: rotation, child: child)
              : child,
        ),
      ),
    );
  }
}

class _BambooPainter extends CustomPainter {
  const _BambooPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final stem = Paint()
      ..color = TienMonGlassTokens.gold.withValues(alpha: .32)
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    final leaf = Paint()
      ..color = TienMonGlassTokens.jade.withValues(alpha: .23)
      ..style = PaintingStyle.fill;

    final base = Offset(size.width * .28, size.height * 1.02);
    final tip = Offset(size.width * .48, -size.height * .06);
    canvas.drawLine(base, tip, stem);
    for (var index = 1; index < 6; index++) {
      final progress = index / 7;
      final center = Offset.lerp(base, tip, progress)!;
      canvas.drawCircle(center, 2.3, stem);
      final direction = index.isEven ? 1.0 : -1.0;
      final leafPath = Path()
        ..moveTo(center.dx, center.dy)
        ..quadraticBezierTo(
          center.dx + 23 * direction,
          center.dy - 16,
          center.dx + 34 * direction,
          center.dy - 5,
        )
        ..quadraticBezierTo(
          center.dx + 18 * direction,
          center.dy + 2,
          center.dx,
          center.dy,
        );
      canvas.drawPath(leafPath, leaf);
    }
    canvas.drawCircle(
      Offset(size.width * .22, size.height * .22),
      13,
      Paint()
        ..color = TienMonGlassTokens.gold.withValues(alpha: .18)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
  }

  @override
  bool shouldRepaint(covariant _BambooPainter oldDelegate) => false;
}
