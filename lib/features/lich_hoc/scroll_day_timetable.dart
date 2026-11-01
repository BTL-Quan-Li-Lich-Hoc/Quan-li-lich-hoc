import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/qldt_models.dart';
import 'package:better_phenikaa_schedule/theme/app_theme.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

enum ScheduleDisplayMode {
  standard,
  scroll;

  String get label => switch (this) {
    standard => 'Thông thường (Ngày / Tuần)',
    scroll => 'Scroll liên tục',
  };

  String get description => switch (this) {
    standard => 'Giữ kiểu lịch ngày và tuần của Cooc.',
    scroll => 'Cuộn dọc các ngày, trong mỗi ngày môn học xếp so le.',
  };
}

enum _StudySession { all, morning, afternoon, evening }

class ScrollDayTimetable extends StatefulWidget {
  const ScrollDayTimetable({
    required this.data,
    required this.selectedDate,
    required this.onDateChanged,
    super.key,
  });

  final ImportedScheduleData data;
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateChanged;

  @override
  State<ScrollDayTimetable> createState() => _ScrollDayTimetableState();
}

class _ScrollDayTimetableState extends State<ScrollDayTimetable> {
  static const int _dayBuffer = 7;
  static const int _stripMiddle = 10000;
  static const double _pillExtent = 62;

  late final ScrollController _dayController;
  late final ScrollController _stripController;
  late final DateTime _stripOrigin;
  late DateTime _active;
  late DateTime _first;
  late DateTime _last;

  final Map<int, GlobalKey> _sectionKeys = <int, GlobalKey>{};
  final GlobalKey _listKey = GlobalKey();
  Map<int, List<ScheduleRecord>> _classes = <int, List<ScheduleRecord>>{};
  _StudySession _filter = _StudySession.all;
  bool _changingExtent = false;
  bool _programmaticStrip = false;
  int _stripAnimationSerial = 0;
  double _stripWidth = 320;

  @override
  void initState() {
    super.initState();
    _active = _onlyDate(widget.selectedDate);
    _stripOrigin = _active;
    _first = _active.subtract(const Duration(days: 1));
    _last = _active.add(const Duration(days: 14));
    _dayController = ScrollController()..addListener(_onDayScroll);
    _stripController = ScrollController(initialScrollOffset: _stripMiddle * _pillExtent);
    _readSchedule();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showActiveSection();
      _centerStrip();
    });
  }

  @override
  void didUpdateWidget(covariant ScrollDayTimetable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.data, widget.data)) _readSchedule();
    final next = _onlyDate(widget.selectedDate);
    if (!_same(next, _active)) {
      _resetToDay(next, notifyParent: false);
    }
  }

  @override
  void dispose() {
    _dayController
      ..removeListener(_onDayScroll)
      ..dispose();
    _stripController.dispose();
    super.dispose();
  }

  static DateTime _onlyDate(DateTime day) =>
      DateTime(day.year, day.month, day.day);
  static bool _same(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
  static int _key(DateTime day) =>
      day.year * 10000 + day.month * 100 + day.day;
  static String _digits(int n) => n.toString().padLeft(2, '0');
  static String _clock(DateTime date) =>
      '${_digits(date.hour)}:${_digits(date.minute)}';
  static String _dayLabel(DateTime date) {
    const weekdays = <String>[
      'Thứ Hai', 'Thứ Ba', 'Thứ Tư', 'Thứ Năm',
      'Thứ Sáu', 'Thứ Bảy', 'Chủ Nhật',
    ];
    return '${weekdays[date.weekday - 1]}, ${_digits(date.day)}/${_digits(date.month)}/${date.year}';
  }

  void _readSchedule() {
    final map = <int, List<ScheduleRecord>>{};
    for (final record in widget.data.classes) {
      map.putIfAbsent(_key(record.startAt), () => <ScheduleRecord>[])
          .add(record);
    }
    for (final list in map.values) {
      list.sort((a, b) => a.startAt.compareTo(b.startAt));
    }
    _classes = map;
  }

  List<ScheduleRecord> _onDate(DateTime day) {
    final items = _classes[_key(day)] ?? const <ScheduleRecord>[];
    return items.where((record) {
      final hour = record.startAt.hour;
      return switch (_filter) {
        _StudySession.all => true,
        _StudySession.morning => hour < 12,
        _StudySession.afternoon => hour >= 12 && hour < 18,
        _StudySession.evening => hour >= 18,
      };
    }).toList(growable: false);
  }

  GlobalKey _keyFor(DateTime day) =>
      _sectionKeys.putIfAbsent(_key(day), GlobalKey.new);

  void _showActiveSection() {
    if (!mounted) return;
    final target = _sectionKeys[_key(_active)]?.currentContext;
    if (target == null) return;
    unawaited(Scrollable.ensureVisible(
      target,
      duration: const Duration(milliseconds: 440),
      curve: Curves.easeInOutCubic,
      alignment: .02,
    ));
  }

  void _resetToDay(DateTime day, {required bool notifyParent}) {
    final next = _onlyDate(day);
    if (_same(next, _active)) {
      _showActiveSection();
      return;
    }
    setState(() {
      _active = next;
      _first = next.subtract(const Duration(days: 1));
      _last = next.add(const Duration(days: 14));
      _sectionKeys.clear();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _showActiveSection();
      _centerStrip();
    });
    if (notifyParent) widget.onDateChanged(next);
  }

  void _centerStrip() {
    if (!mounted || !_stripController.hasClients) return;
    final delta = _active.difference(_stripOrigin).inDays;
    final raw = (_stripMiddle + delta) * _pillExtent -
        (_stripWidth - _pillExtent) / 2;
    final position = _stripController.position;
    final target = raw.clamp(position.minScrollExtent, position.maxScrollExtent).toDouble();
    if ((target - _stripController.offset).abs() < 1) return;
    final serial = ++_stripAnimationSerial;
    _programmaticStrip = true;
    unawaited(_stripController.animateTo(
      target,
      duration: const Duration(milliseconds: 340),
      curve: Curves.easeInOutCubic,
    ).whenComplete(() {
      if (!mounted || serial != _stripAnimationSerial) return;
      _programmaticStrip = false;
    }));
  }

  void _onStripEnd() {
    if (_programmaticStrip || !_stripController.hasClients) return;
    final center = _stripController.offset + _stripWidth / 2;
    final index = (center / _pillExtent).floor();
    final delta = (index - _stripMiddle).clamp(-_stripMiddle, _stripMiddle);
    final selected = _stripOrigin.add(Duration(days: delta));
    if (!_same(selected, _active)) _resetToDay(selected, notifyParent: true);
  }

  void _growPast() {
    if (_changingExtent || !_dayController.hasClients) return;
    _changingExtent = true;
    final oldPixels = _dayController.offset;
    final oldExtent = _dayController.position.maxScrollExtent;
    setState(() {
      _first = _first.subtract(const Duration(days: _dayBuffer));
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _dayController.hasClients) {
        final change = _dayController.position.maxScrollExtent - oldExtent;
        _dayController.jumpTo(
          (oldPixels + change).clamp(
            _dayController.position.minScrollExtent,
            _dayController.position.maxScrollExtent,
          ).toDouble(),
        );
      }
      _changingExtent = false;
    });
  }

  void _growFuture() {
    if (_changingExtent) return;
    _changingExtent = true;
    setState(() {
      _last = _last.add(const Duration(days: _dayBuffer));
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _changingExtent = false;
    });
  }

  void _onDayScroll() {
    if (!mounted || _changingExtent || !_dayController.hasClients) return;
    final position = _dayController.position;
    if (position.pixels < 130 &&
        position.userScrollDirection == ScrollDirection.forward) {
      _growPast();
      return;
    }
    if (position.extentAfter < 500 &&
        position.userScrollDirection == ScrollDirection.reverse) {
      _growFuture();
    }
    final viewport = _listKey.currentContext?.findRenderObject();
    if (viewport is! RenderBox || !viewport.hasSize) return;
    final topY = viewport.localToGlobal(Offset.zero).dy + 44;
    for (var day = _first; !day.isAfter(_last);
        day = day.add(const Duration(days: 1))) {
      final box = _sectionKeys[_key(day)]?.currentContext?.findRenderObject();
      if (box is! RenderBox || !box.hasSize) continue;
      final y = box.localToGlobal(Offset.zero).dy;
      if (y <= topY && y + box.size.height > topY) {
        if (!_same(day, _active)) {
          setState(() => _active = day);
          widget.onDateChanged(day);
          WidgetsBinding.instance.addPostFrameCallback((_) => _centerStrip());
        }
        return;
      }
    }
  }

  void _details(ScheduleRecord record) {
    final palette = appThemePalette;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: palette.surface,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(record.subjectName,
                style: Theme.of(sheetContext).textTheme.titleLarge?.copyWith(
                  color: palette.textPrimary, fontWeight: FontWeight.w800)),
              const SizedBox(height: 14),
              _detailRow(Icons.access_time_rounded,
                  '${_clock(record.startAt)} – ${_clock(record.endAt)}'),
              if (record.room.isNotEmpty)
                _detailRow(Icons.location_on_outlined, record.room),
              if (record.periodStart != null)
                _detailRow(Icons.menu_book_outlined,
                    'Tiết ${record.periodStart}${record.periodEnd == null ? '' : '–${record.periodEnd}'}'),
              if (record.className.isNotEmpty)
                _detailRow(Icons.groups_outlined, record.className),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String text) {
    final palette = appThemePalette;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: <Widget>[
        Icon(icon, size: 19, color: palette.primary),
        const SizedBox(width: 12),
        Expanded(child: Text(text,
            style: TextStyle(color: palette.textPrimary))),
      ]),
    );
  }

  // Thẻ môn học cùng cỡ, bốn sắc độ luôn lấy từ Theme Engine.
  Widget _lessonCard(ScheduleRecord record, int position, DateTime day) {
    final palette = appThemePalette;
    final sequence = (position + day.day + day.month) % 4;
    final hue = switch (sequence) {
      0 => palette.primary,
      1 => palette.accent,
      2 => palette.cardAlt,
      _ => palette.primary,
    };
    final mix = switch (sequence) { 0 => .23, 1 => .22, 2 => .55, _ => .13 };
    final surface = Color.lerp(palette.card, hue, mix)!;
    final radius = palette.geometry == AppThemeGeometry.rounded
        ? palette.radius.clamp(10.0, 17.0).toDouble() : 8.0;
    final period = record.periodStart == null ? ''
        : 'Tiết ${record.periodStart}${record.periodEnd == null ? '' : '–${record.periodEnd}'}';
    final now = DateTime.now();
    final ongoing = !now.isBefore(record.startAt) && now.isBefore(record.endAt);

    return TweenAnimationBuilder<double>(
      key: ValueKey<String>('scroll-subject-${_key(day)}-${record.startAt.millisecondsSinceEpoch}-${record.subjectName}'),
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: 280 + (position % 4) * 45),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, (1 - t) * 12), child: child),
      ),
      child: _ScrollTouchableCard(
        onTap: () => _details(record),
        child: Container(
          width: double.infinity,
          height: 124,
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(radius),
            boxShadow: <BoxShadow>[
              BoxShadow(color: palette.shadow.withValues(alpha: .13),
                blurRadius: 12, offset: const Offset(0, 3)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(children: <Widget>[
                Expanded(child: Text(
                  '${_clock(record.startAt)}–${_clock(record.endAt)}',
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: palette.primary, fontSize: 10,
                    fontWeight: FontWeight.w800),
                )),
                if (ongoing) Icon(Icons.circle, size: 9, color: palette.accent),
              ]),
              const SizedBox(height: 7),
              Expanded(child: Text(
                record.subjectName,
                maxLines: 3, overflow: TextOverflow.ellipsis,
                style: TextStyle(color: palette.textPrimary,
                  fontSize: 12, height: 1.23, fontWeight: FontWeight.w800),
              )),
              if (record.room.isNotEmpty)
                Text(record.room, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: palette.textSecondary,
                    fontSize: 10, fontWeight: FontWeight.w600)),
              if (period.isNotEmpty)
                Text(period, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: palette.textSecondary, fontSize: 10)),
            ],
          ),
        ),
      ),
    );
  }

  // Một khối = một ngày, không áp viền đen của hình phác thảo.
  Widget _daySection(DateTime day) {
    final palette = appThemePalette;
    final items = _onDate(day);
    final left = <int>[];
    final right = <int>[];
    for (var i = 0; i < items.length; i++) {
      (i.isEven ? left : right).add(i);
    }
    final radius = palette.geometry == AppThemeGeometry.rounded
        ? palette.radius.clamp(14.0, 23.0).toDouble() : 10.0;
    final dateBadge = Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: palette.cardAlt,
        borderRadius: BorderRadius.circular(radius * .7),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[
        Icon(Icons.calendar_today_outlined, size: 14, color: palette.primary),
        const SizedBox(width: 6),
        Flexible(child: Text('${_digits(day.day)}/${_digits(day.month)}',
          maxLines: 1, overflow: TextOverflow.ellipsis,
          style: TextStyle(color: palette.textPrimary,
            fontSize: 13, fontWeight: FontWeight.w800))),
      ]),
    );
    Widget column(List<int> indices) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final index in indices) ...<Widget>[
          _lessonCard(items[index], index, day),
          const SizedBox(height: 12),
        ],
      ],
    );
    return Padding(
      key: _keyFor(day),
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(radius),
          boxShadow: <BoxShadow>[
            BoxShadow(color: palette.shadow.withValues(alpha: .09),
              blurRadius: 12, offset: const Offset(0, 3)),
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (items.isEmpty) ...<Widget>[
              Row(children: <Widget>[
                Expanded(child: Text(_dayLabel(day), maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: palette.textPrimary,
                    fontSize: 12, fontWeight: FontWeight.w700))),
                const SizedBox(width: 8),
                dateBadge,
              ]),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 13),
                child: Text('Không có lịch học',
                  style: TextStyle(color: palette.textSecondary, fontSize: 12)),
              ),
            ] else ...<Widget>[
              Row(crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(child: column(left)),
                  const SizedBox(width: 12),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      dateBadge,
                      const SizedBox(height: 12),
                      column(right),
                    ],
                  )),
                ],
              ),
              Text(_dayLabel(day), maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: palette.textSecondary,
                  fontSize: 10, fontWeight: FontWeight.w700)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _dayPill(DateTime day) {
    final palette = appThemePalette;
    final selected = _same(day, _active);
    final today = _same(day, DateTime.now());
    final radius = palette.geometry == AppThemeGeometry.rounded
        ? palette.radius.clamp(10.0, 16.0).toDouble() : 6.0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOutCubic,
        decoration: BoxDecoration(
          color: selected ? palette.primary : today ? palette.cardAlt : palette.card,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(
            color: selected ? palette.primary : palette.border.withValues(alpha: .35),
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(radius),
            onTap: () => _resetToDay(day, notifyParent: true),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[
              Text(day.weekday == 7 ? 'CN' : 'T${day.weekday + 1}',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                  color: selected ? palette.surface : palette.textSecondary)),
              Text(_digits(day.day),
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900,
                  color: selected ? palette.surface : palette.textPrimary)),
              Text('${_digits(day.month)}/${day.year % 100}',
                style: TextStyle(fontSize: 9,
                  color: selected ? palette.surface : palette.textSecondary)),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _filterChip(_StudySession session, String label) {
    final palette = appThemePalette;
    return Padding(
      padding: const EdgeInsets.only(right: 5),
      child: ChoiceChip(
        label: Text(label, style: TextStyle(fontSize: 11,
          color: _filter == session ? palette.surface : palette.textPrimary)),
        visualDensity: VisualDensity.compact,
        selectedColor: palette.primary,
        backgroundColor: palette.cardAlt,
        side: BorderSide(color: palette.border),
        selected: _filter == session,
        onSelected: (_) => setState(() => _filter = session),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = appThemePalette;
    final dayCount = _last.difference(_first).inDays + 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 310),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(.10, 0), end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  ),
                  child: Column(
                    key: ValueKey<int>(_key(_active)),
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text('Tháng ${_digits(_active.month)}/${_active.year} · ${_onDate(_active).length} môn',
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 10,
                          fontWeight: FontWeight.w800, color: palette.primary)),
                      Text(_dayLabel(_active), maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: palette.textPrimary,
                          fontSize: 13, fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => _resetToDay(DateTime.now(), notifyParent: true),
            child: const Text('Hôm nay'),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: 'Ngày trước',
            onPressed: () => _resetToDay(_active.subtract(const Duration(days: 1)), notifyParent: true),
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: 'Ngày sau',
            onPressed: () => _resetToDay(_active.add(const Duration(days: 1)), notifyParent: true),
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ]),
        SizedBox(
          height: 65,
          child: LayoutBuilder(builder: (context, constraints) {
            _stripWidth = constraints.maxWidth;
            return NotificationListener<ScrollEndNotification>(
              onNotification: (event) {
                _onStripEnd();
                return false;
              },
              child: ListView.builder(
                controller: _stripController,
                scrollDirection: Axis.horizontal,
                physics: const _ControlledDayScrollPhysics(),
                itemExtent: _pillExtent,
                itemCount: _stripMiddle * 2 + 1,
                itemBuilder: (context, index) => _dayPill(
                  _stripOrigin.add(Duration(days: index - _stripMiddle)),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 4),
        Row(children: <Widget>[
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: <Widget>[
                _filterChip(_StudySession.all, 'Tất cả'),
                _filterChip(_StudySession.morning, 'Sáng'),
                _filterChip(_StudySession.afternoon, 'Chiều'),
                _filterChip(_StudySession.evening, 'Tối'),
              ]),
            ),
          ),
          TextButton.icon(
            onPressed: () {
              if (_dayController.hasClients) {
                _dayController.animateTo(
                  0,
                  duration: const Duration(milliseconds: 320),
                  curve: Curves.easeOutCubic,
                );
              }
            },
            label: const Text('Đầu trang', style: TextStyle(fontSize: 10)),
            icon: const Icon(Icons.keyboard_arrow_up_rounded, size: 16),
          ),
        ]),
        const SizedBox(height: 8),
        Expanded(
          child: Container(
            key: _listKey,
            child: ListView.builder(
              controller: _dayController,
              physics: const _ControlledDayScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 84),
              itemCount: dayCount,
              itemBuilder: (context, index) => _daySection(
                _first.add(Duration(days: index)),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ScrollTouchableCard extends StatefulWidget {
  const _ScrollTouchableCard({required this.child, required this.onTap});

  final Widget child;
  final VoidCallback onTap;

  @override
  State<_ScrollTouchableCard> createState() => _ScrollTouchableCardState();
}

class _ScrollTouchableCardState extends State<_ScrollTouchableCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _pressed ? .975 : 1,
      duration: const Duration(milliseconds: 170),
      curve: Curves.easeOutCubic,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        child: widget.child,
      ),
    );
  }
}

class _ControlledDayScrollPhysics extends ClampingScrollPhysics {
  const _ControlledDayScrollPhysics({super.parent});

  @override
  _ControlledDayScrollPhysics applyTo(ScrollPhysics? ancestor) =>
      _ControlledDayScrollPhysics(parent: buildParent(ancestor));

  @override
  double get maxFlingVelocity => 1750;

  @override
  double carriedMomentum(double existingVelocity) => 0;

  @override
  Simulation? createBallisticSimulation(ScrollMetrics position, double velocity) =>
      super.createBallisticSimulation(position, velocity.clamp(-1750.0, 1750.0).toDouble());
}
