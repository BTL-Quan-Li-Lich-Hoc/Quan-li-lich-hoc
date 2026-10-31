import 'dart:async';
import 'dart:convert';

import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/qldt_models.dart';
import 'package:better_phenikaa_schedule/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Start at the class time. Confirmation requires scrolling to an earlier time.
int studyAlarmDefaultHour(DateTime startAt) => startAt.hour;
int studyAlarmDefaultMinute(DateTime startAt) => startAt.minute;

/// Native Clock shows just the subject's name. Test-only decoration stays
/// visible on BPA cards, not in the OEM Clock alarm label.
String studyAlarmClockLabel(String subjectName) {
  final name = subjectName.trim();
  const testPrefix = '[TEST 1.6] ';
  final title = name.startsWith(testPrefix)
      ? name.substring(testPrefix.length).trim()
      : name;
  return title.length <= 120 ? title : title.substring(0, 120);
}

/// Only show the Clock action on classes scheduled for tomorrow.
bool studyAlarmIsTomorrow(DateTime classStart, DateTime now) {
  final tomorrow = DateTime(now.year, now.month, now.day + 1);
  return classStart.year == tomorrow.year &&
      classStart.month == tomorrow.month &&
      classStart.day == tomorrow.day;
}

/// Only expose the control once today's clock has reached tomorrow's class
/// start time. Every allowed earlier wheel selection has then passed today.
bool studyAlarmCanOpen(DateTime classStart, DateTime now) {
  if (!studyAlarmIsTomorrow(classStart, now)) return false;
  final classMinute = classStart.hour * 60 + classStart.minute;
  final nowMinute = now.hour * 60 + now.minute;
  return classMinute > 0 && nowMinute >= classMinute;
}

/// The picker is tied to the class date, never today's date or another day.
DateTime studyAlarmOccurrence(DateTime classStart, int hour, int minute) =>
    DateTime(classStart.year, classStart.month, classStart.day, hour, minute);

/// ACTION_SET_ALARM always schedules the next HH:MM occurrence, so checking
/// tomorrow's date alone is insufficient if the same time is still ahead today.
String? studyAlarmValidation(
  DateTime classStart,
  DateTime now,
  int hour,
  int minute,
) {
  if (!studyAlarmIsTomorrow(classStart, now)) {
    return 'Chỉ đặt báo thức cho lịch học ngày mai';
  }
  if (!studyAlarmCanOpen(classStart, now)) {
    return 'Chưa đến thời gian đặt báo thức cho môn này';
  }
  final desired = studyAlarmOccurrence(classStart, hour, minute);
  if (!desired.isBefore(classStart)) {
    return 'Hãy kéo giờ báo thức về trước giờ học';
  }
  if (!desired.isAfter(now.add(const Duration(seconds: 30)))) {
    return 'Giờ báo thức đã qua';
  }
  var next = DateTime(now.year, now.month, now.day, hour, minute);
  if (!next.isAfter(now.add(const Duration(seconds: 30)))) {
    next = DateTime(now.year, now.month, now.day + 1, hour, minute);
  }
  if (next.year != desired.year ||
      next.month != desired.month ||
      next.day != desired.day) {
    return 'Giờ này Đồng hồ sẽ đặt cho hôm nay, không phải ngày mai';
  }
  return null;
}

class StudyAlarmCard extends StatefulWidget {
  const StudyAlarmCard({
    required this.item,
    required this.content,
    super.key,
  });

  final ScheduleRecord item;
  final Widget content;

  static final ValueNotifier<String?> _openItem = ValueNotifier<String?>(null);

  /// Allows the app's existing system-back handler to dismiss the picker.
  static bool dismissExpanded() {
    if (_openItem.value == null) return false;
    _openItem.value = null;
    return true;
  }

  @override
  State<StudyAlarmCard> createState() => _StudyAlarmCardState();
}

class _StudyAlarmCardState extends State<StudyAlarmCard> {
  static const _channel = MethodChannel('better_phenikaa/study_alarm');
  static const _duration = Duration(milliseconds: 250);

  late FixedExtentScrollController _hours;
  late FixedExtentScrollController _minutes;
  late int _hour;
  int _minute = 0;
  bool _sending = false;
  Timer? _eligibilityRefresh;
  String? _savedLabel;
  DateTime? _savedTime;

  String get _prefsKey => 'better_phenikaa_alarm_${Uri.encodeComponent(_identity)}';

  String get _identity =>
      '${widget.item.id}|${widget.item.startAt.toIso8601String()}';

  @override
  void initState() {
    super.initState();
    _resetPicker();
    _loadSavedAlarm();
    _scheduleEligibilityRefresh();
  }

  void _scheduleEligibilityRefresh() {
    _eligibilityRefresh?.cancel();
    final now = DateTime.now();
    final nextMinute = DateTime(now.year, now.month, now.day, now.hour, now.minute + 1);
    _eligibilityRefresh = Timer(
      nextMinute.difference(now) + const Duration(milliseconds: 100),
      () {
        if (!mounted) return;
        _clearExpiredAlarmIfNeeded();
        setState(() {});
        _scheduleEligibilityRefresh();
      },
    );
  }

  void _clearExpiredAlarmIfNeeded() {
    final savedTime = _savedTime;
    if (_sending || savedTime == null) return;
    final now = DateTime.now();
    if (now.isBefore(savedTime) && now.isBefore(widget.item.startAt)) return;
    setState(() {
      _savedTime = null;
      _savedLabel = null;
    });
    // The Clock owns the already-triggered one-shot alarm. This only clears
    // BPA's local "armed" badge; no external alarm is silently dismissed.
    _removeSavedAlarm();
  }

  Future<void> _loadSavedAlarm() async {
    final key = _prefsKey;
    final prefs = await SharedPreferences.getInstance();
    if (!mounted || key != _prefsKey) return;
    final raw = prefs.getString(key);
    if (raw == null) return;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final label = json['label'] as String?;
      final millis = json['target'] as int?;
      if (label != null && millis != null && mounted) {
        final target = DateTime.fromMillisecondsSinceEpoch(millis);
        if (!target.isAfter(DateTime.now()) ||
            !widget.item.startAt.isAfter(DateTime.now())) {
          await prefs.remove(key);
          return;
        }
        setState(() {
          _savedLabel = label;
          _savedTime = target;
        });
      }
    } on FormatException {
      await prefs.remove(key);
    } on TypeError {
      await prefs.remove(key);
    }
  }

  Future<void> _storeAlarm(String label, DateTime target) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(<String, Object>{
      'label': label, 'target': target.millisecondsSinceEpoch,
    }));
  }

  Future<void> _removeSavedAlarm() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
  }

  void _showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(text),
        duration: const Duration(seconds: 2),
      ));
  }

  void _resetPicker() {
    _hour = studyAlarmDefaultHour(widget.item.startAt);
    _minute = studyAlarmDefaultMinute(widget.item.startAt);
    _hours = FixedExtentScrollController(initialItem: _hour);
    _minutes = FixedExtentScrollController(initialItem: _minute);
  }

  @override
  void didUpdateWidget(covariant StudyAlarmCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.id != widget.item.id ||
        oldWidget.item.startAt != widget.item.startAt) {
      _hours.dispose();
      _minutes.dispose();
      _resetPicker();
      _savedLabel = null;
      _savedTime = null;
      _loadSavedAlarm();
    }
  }

  @override
  void dispose() {
    _eligibilityRefresh?.cancel();
    _hours.dispose();
    _minutes.dispose();
    super.dispose();
  }

  void _open() {
    _hours.dispose();
    _minutes.dispose();
    _resetPicker();
    StudyAlarmCard._openItem.value = _identity;
  }

  void _changeHour(int value) {
    if (_hour == value) return;
    final minute = value == widget.item.startAt.hour &&
            _minute > widget.item.startAt.minute
        ? widget.item.startAt.minute
        : _minute;
    setState(() {
      _hour = value;
      _minute = minute;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _minutes.hasClients && _minutes.selectedItem != _minute) {
        _minutes.jumpToItem(_minute);
      }
    });
  }

  void _changeMinute(int value) {
    if (_minute == value) return;
    setState(() => _minute = value);
  }

  Future<void> _confirm() async {
    if (_sending) return;
    final hour = _hour;
    final minute = _minute;
    final problem = studyAlarmValidation(
      widget.item.startAt, DateTime.now(), hour, minute,
    );
    if (problem != null) {
      _showMessage(problem);
      return;
    }
    final target = studyAlarmOccurrence(widget.item.startAt, hour, minute);
    // Display only the exact course name in the native Clock.
    // Keep target/id internally in BPA's saved-state key, never in Clock text.
    final label = studyAlarmClockLabel(widget.item.subjectName);
    setState(() => _sending = true);
    try {
      final dispatched = await _channel.invokeMethod<bool>('setAlarm', <String, Object>{
        'hour': hour,
        'minute': minute,
        'label': label,
        'target': target.millisecondsSinceEpoch,
        'classStart': widget.item.startAt.millisecondsSinceEpoch,
      });
      if (!mounted) return;
      if (dispatched != true) {
        throw PlatformException(
          code: 'clock_failed',
          message: 'Không gửi được yêu cầu tới Đồng hồ.',
        );
      }
      await _storeAlarm(label, target);
      if (!mounted) return;
      setState(() {
        _savedLabel = label;
        _savedTime = target;
      });
      StudyAlarmCard.dismissExpanded();
      _showMessage('Đã gửi lệnh đặt báo thức ${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}');
    } on PlatformException catch (error) {
      _showMessage(error.message ?? 'Không thể đặt báo thức.');
    } on MissingPluginException {
      _showMessage('Thiết bị chưa hỗ trợ đặt báo thức.');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _cancelAlarm() async {
    if (_sending || _savedLabel == null || _savedTime == null) return;
    final label = _savedLabel!;
    final target = _savedTime!;
    setState(() => _sending = true);
    try {
      // One tap sends the targeted native Clock dismiss request.
      // EXTRA_SKIP_UI is not supported by ACTION_DISMISS_ALARM:
      // the device Clock may open on some Android implementations.
      final dispatched = await _channel.invokeMethod<bool>(
        'dismissAlarm',
        <String, Object>{
          'label': label,
          'hour': target.hour,
          'minute': target.minute,
        },
      );
      if (dispatched != true) {
        throw PlatformException(
          code: 'clock_failed',
          message: 'Không gửi được yêu cầu hủy tới Đồng hồ.',
        );
      }
      // The Android intent has no result. This is an optimistic local
      // dismissal request, NOT a verified Clock deletion.
      if (_savedLabel != label || _savedTime != target) return;
      await _removeSavedAlarm();
      if (!mounted) return;
      setState(() {
        _savedLabel = null;
        _savedTime = null;
      });
      _showMessage('Đã gửi yêu cầu hủy báo thức tới Đồng hồ');
    } on PlatformException catch (error) {
      _showMessage(error.message ?? 'Không thể gửi yêu cầu hủy báo thức.');
    } on MissingPluginException {
      _showMessage('Đồng hồ không hỗ trợ lệnh hủy.');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Color _contrastingAccent(AppThemePalette palette) {
    final background = palette.card;
    final accent = palette.primary;
    final l1 = background.computeLuminance();
    final l2 = accent.computeLuminance();
    final ratio = (l1 > l2 ? (l1 + .05) / (l2 + .05) : (l2 + .05) / (l1 + .05));
    if (ratio >= 4.0) return accent;
    final fallback = palette.textPrimary;
    final f = fallback.computeLuminance();
    final fallbackRatio = (l1 > f ? (l1 + .05) / (f + .05) : (f + .05) / (l1 + .05));
    if (fallbackRatio >= 4.0) return fallback;
    return l1 > .4 ? Colors.black : Colors.white;
  }

  @override
  Widget build(BuildContext context) {
    final palette = appThemePalette;
    final accent = _contrastingAccent(palette);
    return ValueListenableBuilder<String?>(
      valueListenable: StudyAlarmCard._openItem,
      builder: (context, current, _) {
        final now = DateTime.now();
        final eligible = studyAlarmCanOpen(widget.item.startAt, now);
        // After midnight, retain X only while the scheduled alarm is pending.
        final armed = _savedLabel != null &&
            _savedTime != null &&
            now.isBefore(_savedTime!) &&
            now.isBefore(widget.item.startAt);
        final expanded = eligible && !armed && current == _identity;
        final showAction = eligible || armed;
        final selectedBeforeClass = _hour * 60 + _minute <
            widget.item.startAt.hour * 60 + widget.item.startAt.minute;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onVerticalDragEnd: expanded
                      ? (details) {
                          if ((details.primaryVelocity ?? 0) > 320) {
                            StudyAlarmCard.dismissExpanded();
                          }
                        }
                      : null,
                  child: widget.content,
                ),
                if (showAction)
                  Positioned(
                  right: 21,
                  top: 43,
                  child: Semantics(
                    button: true,
                    label: armed
                        ? 'Tắt báo thức đã đặt'
                        : expanded ? 'Xác nhận báo thức' : 'Đặt báo thức',
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        key: ValueKey<String>(
                          armed
                              ? 'alarm-cancel-${widget.item.id}'
                              : expanded
                                  ? 'alarm-confirm-${widget.item.id}'
                                  : 'alarm-open-${widget.item.id}',
                        ),
                        onTap: _sending
                            ? null
                            : armed
                                ? _cancelAlarm
                                : expanded
                                    ? (selectedBeforeClass ? _confirm : null)
                                    : _open,
                        customBorder: const CircleBorder(),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: armed ? const Color(0xFFD83333) : accent.withValues(alpha: .055),
                            border: Border.all(
                              color: armed ? const Color(0xFFD83333) : accent.withValues(alpha: .72),
                              width: 1.35,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 180),
                            switchInCurve: Curves.easeOutCubic,
                            switchOutCurve: Curves.easeInCubic,
                            transitionBuilder: (child, animation) =>
                                FadeTransition(
                              opacity: animation,
                              child: ScaleTransition(scale: animation, child: child),
                            ),
                            child: _sending
                                ? SizedBox(
                                    key: const ValueKey<String>('busy'),
                                    width: 19,
                                    height: 19,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: accent,
                                    ),
                                  )
                                : Icon(
                                    armed
                                        ? Icons.close_rounded
                                        : expanded ? Icons.check_rounded : Icons.alarm_outlined,
                                    key: ValueKey<String>(armed ? 'cancel' : expanded ? 'confirm' : 'open'),
                                    color: armed
                                        ? Colors.white
                                        : expanded && !selectedBeforeClass
                                            ? accent.withValues(alpha: .38)
                                            : accent,
                                    size: 24,
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            AnimatedSize(
              alignment: Alignment.topCenter,
              duration: _duration,
              curve: Curves.easeInOutCubic,
              child: expanded && !armed
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(10, 0, 10, 15),
                      child: Center(
                        child: SizedBox(
                          height: 144,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              _WheelColumn(
                                key: const ValueKey<String>('hours'),
                                controller: _hours,
                                count: widget.item.startAt.hour + 1,
                                selected: _hour,
                                color: accent,
                                onChanged: _changeHour,
                              ),
                              Padding(
                                padding: const EdgeInsets.only(bottom: 5),
                                child: Text(':',
                                  style: TextStyle(
                                    color: accent,
                                    fontSize: 35,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              _WheelColumn(
                                key: const ValueKey<String>('minutes'),
                                controller: _minutes,
                                count: _hour == widget.item.startAt.hour
                                    ? widget.item.startAt.minute + 1
                                    : 60,
                                selected: _minute,
                                color: accent,
                                onChanged: _changeMinute,
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        );
      },
    );
  }
}

class _WheelColumn extends StatelessWidget {
  const _WheelColumn({
    required this.controller,
    required this.count,
    required this.selected,
    required this.color,
    required this.onChanged,
    super.key,
  });

  final FixedExtentScrollController controller;
  final int count;
  final int selected;
  final Color color;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 91,
        child: ListWheelScrollView.useDelegate(
          controller: controller,
          itemExtent: 48,
          diameterRatio: 100,
          perspective: .001,
          squeeze: 1,
          overAndUnderCenterOpacity: .33,
          physics: const FixedExtentScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          onSelectedItemChanged: (index) => onChanged(index % count),
          childDelegate: ListWheelChildLoopingListDelegate(
            children: List<Widget>.generate(count, (index) {
              final focused = index == selected;
              return Center(
                child: Text(
                  index.toString().padLeft(2, '0'),
                  style: TextStyle(
                    color: color.withValues(alpha: focused ? 1 : .72),
                    fontSize: focused ? 34 : 31,
                    fontWeight: focused ? FontWeight.w700 : FontWeight.w500,
                    height: 1,
                  ),
                ),
              );
            }),
          ),
        ),
      );
}
