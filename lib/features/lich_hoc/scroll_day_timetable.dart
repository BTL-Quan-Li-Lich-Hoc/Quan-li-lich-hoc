import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/qldt_models.dart';
import 'package:better_phenikaa_schedule/features/giao_dien/tien_mon_premium/schedule/tien_mon_schedule_views.dart';
import 'package:better_phenikaa_schedule/features/giao_dien/tien_mon_premium/tien_mon_premium_contract.dart';
import 'package:better_phenikaa_schedule/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

enum ScheduleDisplayMode {
  standard,
  scrollOneColumn,
  scrollTwoColumns;

  String get label => switch (this) {
    standard => 'Thông thường (Ngày / Tuần)',
    scrollOneColumn => 'Scroll liên tục · 1 cột',
    scrollTwoColumns => 'Scroll liên tục · 2 cột',
  };

  String get description => switch (this) {
    standard => 'Giữ kiểu lịch ngày và tuần của Cooc.',
    scrollOneColumn => 'Vuốt ngày ngang và cuộn dọc các buổi học.',
    scrollTwoColumns => 'Cuộn liên tục với thẻ môn học so le 2 cột.',
  };
}

enum _StudySession { all, morning, afternoon, evening }

class ScrollDayTimetable extends StatefulWidget {
  const ScrollDayTimetable({
    required this.data,
    required this.selectedDate,
    required this.onDateChanged,
    required this.twoColumns,
    super.key,
  });

  final ImportedScheduleData data;
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateChanged;
  final bool twoColumns;

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
    final context = _sectionKeys[_key(_active)]?.currentContext;
    if (context != null) {
      Scrollable.ensureVisible(context, duration: Duration.zero, alignment: 0.0);
    }
  }

  void _resetToDay(DateTime day, {required bool notifyParent}) {
    setState(() {
      _active = _onlyDate(day);
      _first = _active.subtract(const Duration(days: 1));
      _last = _active.add(const Duration(days: 14));
      _sectionKeys.clear();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showActiveSection();
      _centerStrip();
    });
    if (notifyParent) widget.onDateChanged(_active);
  }

  void _centerStrip() {
    if (!mounted || !_stripController.hasClients) return;
    final delta = _active.difference(_stripOrigin).inDays;
    final target = (_stripMiddle + delta) * _pillExtent -
        (_stripWidth - _pillExtent) / 2;
    _programmaticStrip = true;
    _stripController.jumpTo(
      target.clamp(
        _stripController.position.minScrollExtent,
        _stripController.position.maxScrollExtent,
      ).toDouble(),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _programmaticStrip = false;
    });
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

  Widget _lessonCard(ScheduleRecord record) {
    final palette = appThemePalette;
    final now = DateTime.now();
    final active = !now.isBefore(record.startAt) && now.isBefore(record.endAt);
    final duration = record.endAt.difference(record.startAt).inMinutes;
    final cardHeight = (90 + duration.clamp(0, 240) / 10).toDouble();
    final content = InkWell(
      onTap: () => _details(record),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: cardHeight),
        child: Padding(
          padding: const EdgeInsets.all(11),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('${_clock(record.startAt)} – ${_clock(record.endAt)}',
                  style: TextStyle(color: palette.primary,
                    fontSize: 11, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(record.subjectName, maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: palette.textPrimary,
                  fontSize: 13, fontWeight: FontWeight.w800)),
              if (record.room.isNotEmpty) ...<Widget>[
                const SizedBox(height: 6),
                Text(record.room, maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: palette.textSecondary, fontSize: 11)),
              ],
              if (record.periodStart != null) ...<Widget>[
                const SizedBox(height: 5),
                Text('Tiết ${record.periodStart}${record.periodEnd == null ? '' : '–${record.periodEnd}'}',
                    style: TextStyle(color: palette.textSecondary, fontSize: 11)),
              ],
            ],
          ),
        ),
      ),
    );
    if (palette.id == AppThemeId.tienMonPremium) {
      return TienMonEdgeSurface(
        active: active,
        scene: TienMonPremiumContract.appSceneFor(now),
        child: content,
      );
    }
    return AppThemePanel(elevated: true, child: content);
  }

  Widget _daySection(DateTime day) {
    final palette = appThemePalette;
    final items = _onDate(day);
    final title = Text(_dayLabel(day),
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: palette.textPrimary, fontWeight: FontWeight.w800));
    final contents = items.isEmpty
        ? <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Text('Không có lịch học',
                  style: TextStyle(color: palette.textSecondary)),
            ),
          ]
        : widget.twoColumns
        ? <Widget>[_twoColumnCards(items)]
        : <Widget>[
            for (final item in items)
              Padding(padding: const EdgeInsets.only(bottom: 10),
                  child: _lessonCard(item)),
          ];
    return Padding(
      key: _keyFor(day),
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(children: <Widget>[
            Expanded(child: title),
            Text('${items.length} môn',
                style: TextStyle(color: palette.textSecondary, fontSize: 11)),
          ]),
          const SizedBox(height: 10),
          ...contents,
          Divider(color: palette.border),
        ],
      ),
    );
  }

  Widget _twoColumnCards(List<ScheduleRecord> items) {
    final left = <ScheduleRecord>[];
    final right = <ScheduleRecord>[];
    for (var i = 0; i < items.length; i++) {
      (i.isEven ? left : right).add(items[i]);
    }
    Widget column(List<ScheduleRecord> entries) => Column(
      children: <Widget>[
        for (final record in entries)
          Padding(padding: const EdgeInsets.only(bottom: 9),
              child: _lessonCard(record)),
      ],
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(child: column(left)),
        const SizedBox(width: 9),
        Expanded(child: column(right)),
      ],
    );
  }

  Widget _dayPill(DateTime day) {
    final palette = appThemePalette;
    final selected = _same(day, _active);
    final today = _same(day, DateTime.now());
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
      child: Material(
        color: selected ? palette.primary
            : today ? palette.cardAlt : palette.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(palette.radius.clamp(0, 16)),
          side: BorderSide(color: palette.border),
        ),
        child: InkWell(
          onTap: () => _resetToDay(day, notifyParent: true),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(day.weekday == 7 ? 'CN' : 'T${day.weekday + 1}',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                    color: selected ? palette.surface : palette.textSecondary)),
              Text(_digits(day.day),
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900,
                    color: selected ? palette.surface : palette.textPrimary)),
              Text('${_digits(day.month)}/${day.year % 100}',
                  style: TextStyle(fontSize: 9,
                    color: selected ? palette.surface : palette.textSecondary)),
            ],
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
          Expanded(child: Text(_dayLabel(_active), maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: palette.textPrimary,
                  fontSize: 13, fontWeight: FontWeight.w800))),
          TextButton(
            onPressed: () => _resetToDay(DateTime.now(), notifyParent: true),
            child: const Text('Hôm nay'),
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
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: <Widget>[
            _filterChip(_StudySession.all, 'Tất cả'),
            _filterChip(_StudySession.morning, 'Sáng'),
            _filterChip(_StudySession.afternoon, 'Chiều'),
            _filterChip(_StudySession.evening, 'Tối'),
          ]),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Container(
            key: _listKey,
            child: ListView.builder(
              controller: _dayController,
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
