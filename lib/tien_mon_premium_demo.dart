import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'features/giao_dien/tien_mon_premium/background/tien_mon_background.dart';
import 'features/giao_dien/tien_mon_premium/glass/tien_mon_glass.dart';
import 'features/giao_dien/tien_mon_premium/schedule/tien_mon_schedule_views.dart';
import 'features/giao_dien/tien_mon_premium/tien_mon_premium_contract.dart';
import 'features/giao_dien/tien_mon_premium/tien_mon_premium_models.dart';
import 'features/giao_dien/tien_mon_premium/tien_mon_safe_text.dart';
import 'features/giao_dien/tien_mon_premium/widgets/tien_mon_widget_previews.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const TienMonPremiumDemoApp());
}

class TienMonPremiumDemoApp extends StatelessWidget {
  const TienMonPremiumDemoApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      brightness: Brightness.dark,
      fontFamily: TienMonPremiumContract.fontFamily,
      fontFamilyFallback: const <String>['Roboto', 'Noto Sans', 'sans-serif'],
      colorScheme: ColorScheme.fromSeed(
        seedColor: TienMonGlassTokens.jade,
        brightness: Brightness.dark,
      ),
      splashFactory: InkRipple.splashFactory,
    ),
    home: const TienMonPremiumHarness(),
  );
}

class TienMonPremiumHarness extends StatefulWidget {
  const TienMonPremiumHarness({
    super.key,
    this.adapter = const TienMonDemoScheduleAdapter(),
  });

  final TienMonScheduleAdapter adapter;

  @override
  State<TienMonPremiumHarness> createState() => _TienMonPremiumHarnessState();
}

class _TienMonPremiumHarnessState extends State<TienMonPremiumHarness> {
  late final TienMonSceneController _scenes = TienMonSceneController();
  late final Widget _persistentBackground;
  TienMonCalendarMode _calendar = TienMonCalendarMode.day;
  TienMonScheduleMode _schedule = TienMonScheduleMode.study;
  TienMonOverviewWidgetScene _widgetScene = TienMonOverviewWidgetScene.morning;
  TienMonSyncState _sync = TienMonSyncState.idle;
  DateTime _anchor = DateTime.now();
  int _direction = 1;
  int _animationEpoch = 0;

  @override
  void initState() {
    super.initState();
    _persistentBackground = RepaintBoundary(
      child: TienMonPersistentBackground(controller: _scenes),
    );
  }

  @override
  void dispose() {
    _scenes.dispose();
    super.dispose();
  }

  void _navigate(int direction) {
    setState(() {
      _direction = direction;
      _anchor = _anchor.add(
        Duration(
          days: direction * (_calendar == TienMonCalendarMode.day ? 1 : 7),
        ),
      );
    });
  }

  Future<void> _pickAnchor() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _anchor,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _direction = 0;
      _anchor = picked;
    });
  }

  // TIEN_MON_INTEGRATION: real notification data enters this sheet here.
  Future<void> _showNotifications() => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    barrierColor: Colors.black26,
    backgroundColor: Colors.transparent,
    sheetAnimationStyle: AnimationStyle(
      duration: TienMonPremiumContract.notificationSheetTransition,
      reverseDuration: TienMonPremiumContract.notificationSheetTransition,
    ),
    builder: (context) => Padding(
      padding: const EdgeInsets.fromLTRB(12, 80, 12, 12),
      child: TienMonGlass(
        opaqueSheet: true,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const TienMonText(
                  'Thông báo',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const _NotificationTile(
              icon: Icons.school_outlined,
              title: 'Lịch thi sắp tới',
              body: 'Trí tuệ nhân tạo, còn 3 ngày',
            ),
            const SizedBox(height: 10),
            const _NotificationTile(
              icon: Icons.sync,
              title: 'Đồng bộ hoàn tất',
              body: 'Lịch học đã được làm mới',
            ),
          ],
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final week = widget.adapter.loadWeek(anchor: _anchor, mode: _schedule);
    final selected = week[_anchor.weekday - 1];
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          _persistentBackground,
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 26, 22, 18),
              child: DefaultTextStyle.merge(
                style: TextStyle(
                  color: _sceneForeground(_scenes.scene),
                  shadows: _sceneForegroundShadows(_scenes.scene),
                ),
                child: IconTheme(
                  data: IconThemeData(color: _sceneForeground(_scenes.scene)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      _Header(
                        scheduleMode: _schedule,
                        onCalendar: _pickAnchor,
                        onNotifications: _showNotifications,
                        onScheduleToggle: () => setState(() {
                          _direction = 0;
                          _schedule = _schedule == TienMonScheduleMode.study
                              ? TienMonScheduleMode.exam
                              : TienMonScheduleMode.study;
                        }),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: _Segmented<TienMonCalendarMode>(
                          values: TienMonCalendarMode.values,
                          selected: _calendar,
                          labels: const <String>['Theo ngày', 'Theo tuần'],
                          onChanged: (value) => setState(() {
                            _direction = 0;
                            _calendar = value;
                            if (value == TienMonCalendarMode.day) {
                              _anchor = DateTime.now();
                            } else {
                              _anchor = _weekMonday(DateTime.now());
                            }
                          }),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _DateNavigator(
                        anchor: _anchor,
                        calendarMode: _calendar,
                        onTap: _pickAnchor,
                        onPrevious: () => _navigate(-1),
                        onNext: () => _navigate(1),
                      ),
                      if (_calendar == TienMonCalendarMode.day)
                        const SizedBox(height: 18),
                      Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          onHorizontalDragEnd:
                              _calendar == TienMonCalendarMode.day
                              ? (details) {
                                  final velocity = details.primaryVelocity ?? 0;
                                  if (velocity.abs() < 180) return;
                                  _navigate(velocity < 0 ? 1 : -1);
                                }
                              : null,
                          child: AnimatedSwitcher(
                            duration: TienMonPremiumContract
                                .calendarNavigationTransition,
                            transitionBuilder: (child, animation) =>
                                FadeTransition(
                                  opacity: animation,
                                  child: SlideTransition(
                                    position: Tween<Offset>(
                                      begin: Offset(.035 * _direction, 0),
                                      end: Offset.zero,
                                    ).animate(animation),
                                    child: child,
                                  ),
                                ),
                            child: _calendar == TienMonCalendarMode.day
                                ? TienMonDayView(
                                    key: ValueKey<String>(
                                      'day-${_anchor.toIso8601String()}-$_schedule-$_animationEpoch',
                                    ),
                                    day: selected,
                                    scene: _scenes.scene,
                                  )
                                : TienMonWeekView(
                                    key: ValueKey<String>(
                                      'week-${week.first.date.toIso8601String()}-$_schedule-$_animationEpoch',
                                    ),
                                    days: week,
                                    scene: _scenes.scene,
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
          Positioned(
            right: 22,
            bottom: 28,
            child: FloatingActionButton(
              heroTag: 'premium-options',
              onPressed: _showOptions,
              backgroundColor: const Color(0xD2194E49),
              foregroundColor: Colors.white,
              elevation: 8,
              child: const Icon(Icons.grid_view_rounded),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showOptions() => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    barrierColor: Colors.black38,
    backgroundColor: Colors.transparent,
    sheetAnimationStyle: AnimationStyle(
      duration: TienMonPremiumContract.notificationSheetTransition,
      reverseDuration: TienMonPremiumContract.notificationSheetTransition,
    ),
    builder: (context) => StatefulBuilder(
      builder: (context, modalSetState) => FractionallySizedBox(
        heightFactor: .90,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          child: TienMonGlass(
            opaqueSheet: true,
            padding: EdgeInsets.zero,
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        const TienMonText(
                          'Tùy chọn',
                          style: TextStyle(
                            fontSize: 23,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const _OptionHeading('1. Background Scene'),
                    AnimatedBuilder(
                      animation: _scenes,
                      builder: (context, _) => Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: <Widget>[
                          IconButton(
                            onPressed: () {
                              _scenes.previous();
                              modalSetState(() {});
                            },
                            icon: const Icon(Icons.chevron_left_rounded),
                          ),
                          ...List<Widget>.generate(
                            8,
                            (index) => ChoiceChip(
                              label: Text('${index + 1}'),
                              selected:
                                  !_scenes.automatic &&
                                  _scenes.scene == index + 1,
                              onSelected: (_) {
                                _scenes.select(index + 1);
                                modalSetState(() {});
                              },
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              _scenes.next();
                              modalSetState(() {});
                            },
                            icon: const Icon(Icons.chevron_right_rounded),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    const _OptionHeading('2. Time / Auto'),
                    AnimatedBuilder(
                      animation: _scenes,
                      builder: (context, _) => Row(
                        children: <Widget>[
                          ChoiceChip(
                            label: const Text('Auto theo thời gian'),
                            selected: _scenes.automatic,
                            onSelected: (_) {
                              _scenes.useAutomatic();
                              modalSetState(() {});
                            },
                          ),
                          const SizedBox(width: 10),
                          TienMonText(
                            'Scene ${_scenes.scene}',
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    const _OptionHeading('3. Study / Exam'),
                    _Segmented<TienMonScheduleMode>(
                      values: TienMonScheduleMode.values,
                      selected: _schedule,
                      labels: const <String>['Lịch học', 'Lịch thi'],
                      onChanged: (value) {
                        setState(() {
                          _direction = 0;
                          _schedule = value;
                        });
                        modalSetState(() {});
                      },
                    ),
                    const SizedBox(height: 18),
                    const _OptionHeading('4. Widget Preview'),
                    Wrap(
                      spacing: 6,
                      children: TienMonOverviewWidgetScene.values
                          .map(
                            (scene) => ChoiceChip(
                              label: Text(switch (scene) {
                                TienMonOverviewWidgetScene.morning => 'Sáng',
                                TienMonOverviewWidgetScene.afternoon => 'Chiều',
                                TienMonOverviewWidgetScene.night => 'Tối',
                              }),
                              selected: _widgetScene == scene,
                              onSelected: (_) {
                                setState(() => _widgetScene = scene);
                                modalSetState(() {});
                              },
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 10),
                    TienMonOverviewWidgetPreview(
                      scene: _widgetScene,
                      mode: _schedule,
                      syncState: _sync,
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: SizedBox(
                        width: 320,
                        child: TienMonSmallWidgetPreview(
                          mode: _schedule,
                          syncState: _sync,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const _OptionHeading('5. Sync State'),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: TienMonSyncState.values
                          .map(
                            (state) => ChoiceChip(
                              label: Text(state.name),
                              selected: _sync == state,
                              onSelected: (_) {
                                setState(() => _sync = state);
                                modalSetState(() {});
                              },
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 18),
                    const _OptionHeading('6. Animation Test'),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: <Widget>[
                        OutlinedButton.icon(
                          onPressed: () {
                            setState(() => _animationEpoch++);
                            modalSetState(() {});
                          },
                          icon: const Icon(Icons.replay_rounded),
                          label: const Text('Replay content'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () {
                            setState(() {
                              _calendar = _calendar == TienMonCalendarMode.day
                                  ? TienMonCalendarMode.week
                                  : TienMonCalendarMode.day;
                              _direction = 0;
                            });
                            modalSetState(() {});
                          },
                          icon: const Icon(Icons.swap_horiz_rounded),
                          label: const Text('Day / Week'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () {
                            setState(() {
                              _schedule = _schedule == TienMonScheduleMode.study
                                  ? TienMonScheduleMode.exam
                                  : TienMonScheduleMode.study;
                              _direction = 0;
                            });
                            modalSetState(() {});
                          },
                          icon: const Icon(Icons.layers_outlined),
                          label: const Text('Study / Exam'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

const Color _premiumTextGold = Color(0xFFFFD66B);

Color _sceneForeground(int scene) => _premiumTextGold;

List<Shadow> _sceneForegroundShadows(int scene) => const <Shadow>[
  Shadow(color: Colors.black87, blurRadius: 4),
  Shadow(color: Colors.black54, blurRadius: 8),
];

class _Header extends StatelessWidget {
  const _Header({
    required this.scheduleMode,
    required this.onCalendar,
    required this.onNotifications,
    required this.onScheduleToggle,
  });

  final TienMonScheduleMode scheduleMode;
  final VoidCallback onCalendar;
  final VoidCallback onNotifications;
  final VoidCallback onScheduleToggle;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: <Widget>[
      Expanded(
        child: AnimatedSwitcher(
          duration: TienMonPremiumContract.studyExamTransition,
          child: TienMonText(
            scheduleMode == TienMonScheduleMode.study ? 'Lịch học' : 'Lịch thi',
            key: ValueKey<TienMonScheduleMode>(scheduleMode),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w900),
          ),
        ),
      ),
      const SizedBox(width: 6),
      TienMonPressable(
        onTap: onScheduleToggle,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          constraints: const BoxConstraints(minHeight: 32),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color:
                  (scheduleMode == TienMonScheduleMode.study
                          ? TienMonGlassTokens.gold
                          : TienMonGlassTokens.jade)
                      .withValues(alpha: .92),
              width: 1.1,
            ),
          ),
          child: TienMonText(
            scheduleMode == TienMonScheduleMode.study ? 'Lịch thi' : 'Lịch học',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w900,
              color: scheduleMode == TienMonScheduleMode.study
                  ? TienMonGlassTokens.gold
                  : TienMonGlassTokens.jade,
              shadows: const <Shadow>[
                Shadow(color: Colors.black87, blurRadius: 4),
              ],
            ),
          ),
        ),
      ),
      const SizedBox(width: 4),
      IconButton(
        tooltip: 'Thông báo',
        onPressed: onNotifications,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
        icon: const Icon(Icons.notifications_none_rounded),
      ),
      IconButton.filledTonal(
        tooltip: 'Chọn ngày',
        onPressed: onCalendar,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
        style: IconButton.styleFrom(
          backgroundColor: Colors.transparent,
          side: BorderSide(
            color: (IconTheme.of(context).color ?? Colors.white).withValues(
              alpha: .55,
            ),
          ),
        ),
        icon: const Icon(Icons.calendar_month_outlined),
      ),
    ],
  );
}

class _DateNavigator extends StatelessWidget {
  const _DateNavigator({
    required this.anchor,
    required this.calendarMode,
    required this.onTap,
    required this.onPrevious,
    required this.onNext,
  });

  final DateTime anchor;
  final TienMonCalendarMode calendarMode;
  final VoidCallback onTap;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final monday = _weekMonday(anchor);
    final sunday = monday.add(const Duration(days: 6));
    final label = calendarMode == TienMonCalendarMode.day
        ? _dateLabel(anchor)
        : '${_shortDate(monday)} - ${_shortDate(sunday)}';
    return TienMonGlass(
      radius: 18,
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
      child: Row(
        children: <Widget>[
          IconButton(
            onPressed: onPrevious,
            icon: Icon(
              Icons.chevron_left_rounded,
              color: IconTheme.of(context).color?.withValues(alpha: .88),
            ),
          ),
          Expanded(
            child: TienMonPressable(
              onTap: onTap,
              borderRadius: BorderRadius.circular(15),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  vertical: calendarMode == TienMonCalendarMode.week ? 13 : 9,
                  horizontal: 8,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Flexible(
                      child: TienMonText(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    if (calendarMode == TienMonCalendarMode.day) ...<Widget>[
                      const SizedBox(width: 7),
                      Icon(
                        Icons.expand_more_rounded,
                        size: 18,
                        color: IconTheme.of(context).color
                            ?.withValues(alpha: .88),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            onPressed: onNext,
            icon: Icon(
              Icons.chevron_right_rounded,
              color: IconTheme.of(context).color?.withValues(alpha: .88),
            ),
          ),
        ],
      ),
    );
  }
}

class _Segmented<T> extends StatelessWidget {
  const _Segmented({
    required this.values,
    required this.selected,
    required this.labels,
    required this.onChanged,
  });

  final List<T> values;
  final T selected;
  final List<String> labels;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) => TienMonGlass(
    radius: 18,
    padding: const EdgeInsets.all(3),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final selectedIndex = values.indexOf(selected);
        final itemWidth = constraints.maxWidth / values.length;
        return Stack(
          children: <Widget>[
            AnimatedPositioned(
              duration: const Duration(milliseconds: 200),
              curve: Curves.linear,
              left: itemWidth * selectedIndex,
              top: 0,
              bottom: 0,
              width: itemWidth,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  color: TienMonGlassTokens.jade.withValues(alpha: .30),
                  border: Border.all(color: Colors.white54),
                ),
              ),
            ),
            Row(
              children: List<Widget>.generate(
                values.length,
                (index) => Expanded(
                  child: TienMonPressable(
                    onTap: () => onChanged(values[index]),
                    borderRadius: BorderRadius.circular(15),
                    child: SizedBox(
                      width: double.infinity,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        child: TienMonText(
                          labels[index],
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
}

class _OptionHeading extends StatelessWidget {
  const _OptionHeading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: TienMonText(
      text,
      style: const TextStyle(
        color: TienMonGlassTokens.gold,
        fontSize: 16,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => TienMonGlass(
    child: Row(
      children: <Widget>[
        Icon(icon, color: TienMonGlassTokens.gold),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              TienMonText(title),
              TienMonText(body, style: const TextStyle(color: Colors.white70)),
            ],
          ),
        ),
      ],
    ),
  );
}

DateTime _weekMonday(DateTime date) =>
    DateTime(date.year, date.month, date.day - date.weekday + 1);

String _shortDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';

String _dateLabel(DateTime date) {
  const weekdays = <String>[
    'Thứ Hai',
    'Thứ Ba',
    'Thứ Tư',
    'Thứ Năm',
    'Thứ Sáu',
    'Thứ Bảy',
    'Chủ Nhật',
  ];
  return '${weekdays[date.weekday - 1]}, ${date.day} tháng ${date.month}';
}
