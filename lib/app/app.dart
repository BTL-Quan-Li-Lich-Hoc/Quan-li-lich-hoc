import 'dart:async';
import 'dart:convert';

import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/diagnostics/qldt_sync_diagnostics.dart';
import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/exam_period.dart';
import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/qldt_login.dart';
import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/qldt_login_result.dart';
import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/qldt_models.dart';
import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/schedule_difference_sheet.dart';
import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/semester_changes.dart';
import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/semester_data.dart';
import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/semester_retention.dart';
import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/sync_reminder_policy.dart';
import 'package:better_phenikaa_schedule/features/dong_bo_hang_ngay/daily_sync.dart';
import 'package:better_phenikaa_schedule/features/giao_dien/xem_truoc/theme_picker.dart';
import 'package:better_phenikaa_schedule/features/giao_dien/tien_mon_premium/schedule/tien_mon_schedule_views.dart';
import 'package:better_phenikaa_schedule/features/giao_dien/tien_mon_premium/tien_mon_premium_contract.dart';
import 'package:better_phenikaa_schedule/features/lich_hoc/week_timetable.dart';
import 'package:better_phenikaa_schedule/features/tien_ich_lich_hoc/widget_publisher.dart';
import 'package:better_phenikaa_schedule/features/tro_li/assistant_text.dart';
import 'package:better_phenikaa_schedule/theme/app_theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BetterPhenikaaScheduleApp extends StatefulWidget {
  const new({super.key});

  @override
  State<BetterPhenikaaScheduleApp> createState() =>
      _BetterPhenikaaScheduleAppState();
}

class _BetterPhenikaaScheduleAppState extends State<BetterPhenikaaScheduleApp> {
  final AppThemeController _themes = AppThemeController.instance;

  @override
  void initState() {
    super.initState();
    unawaited(_themes.load());
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _themes,
      builder: (context, _) {
        final palette = _themes.palette;
        return MaterialApp(
          title: 'Better Phenikaa App',
          debugShowCheckedModeBanner: false,
          themeAnimationDuration: Duration.zero,
          theme: buildBetterTheme(palette),
          home: const _AppRoot(),
        );
      },
    );
  }
}

enum _AppPage { timetable, exam, account, notifications }

class _AppRoot extends StatefulWidget {
  const new();

  @override
  State<_AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<_AppRoot> with WidgetsBindingObserver {
  static const _storageKey = 'better_phenikaa_snapshot_v1';
  static const _routeKey = 'better_phenikaa_qldt_registration_route_v1';
  static const _widgetSessionChannel = MethodChannel(
    'better_phenikaa/widget_session',
  );

  bool _booting = true;
  bool _syncing = false;
  bool _panelOpen = false;
  ImportedScheduleData? _data;
  _AppPage _page = _AppPage.timetable;
  DateTime _selectedDate = DateTime.now();
  bool _showPastExams = false;
  String? _errorMessage;
  String? _examNotice;
  SemesterDifference? _latestDifference;
  bool _unreadDifference = false;
  _AppPage _notificationReturnPage = _AppPage.timetable;
  Timer? _examClockTimer;
  Timer? _syncStaleTimer;
  Timer? _semesterExpiryTimer;
  Timer? _exitGestureTimer;
  bool _exitGestureArmed = false;
  DateTime? _lastSuccessfulSync;
  AssistantPack _assistantPack = AssistantPack.normal;
  String _accountDisplayName = '';
  static const _seenDifferenceKey = 'better_phenikaa_seen_difference_v1';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AppThemeController.instance.addListener(_handleThemeChanged);
    unawaited(_restore());
  }

  void _handleThemeChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _examClockTimer?.cancel();
    _syncStaleTimer?.cancel();
    _semesterExpiryTimer?.cancel();
    _exitGestureTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    AppThemeController.instance.removeListener(_handleThemeChanged);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || _data == null) return;
    unawaited(_expireStoredSemesters());
    setState(() {});
    _scheduleExamClock();
    unawaited(_refreshExamNotice());
    unawaited(_refreshDifference());
    unawaited(_refreshSyncStatus());
  }

  Future<void> _refreshSyncStatus() async {
    try {
      final last = await DailySync.lastSuccessfulSync() ?? _data?.syncedAt;
      if (!mounted) return;
      setState(() => _lastSuccessfulSync = last);
      _syncStaleTimer?.cancel();
      if (last == null) return;
      final due = last.add(const Duration(days: 2, milliseconds: 1));
      if (due.isAfter(DateTime.now())) {
        _syncStaleTimer = Timer(due.difference(DateTime.now()), () {
          if (mounted) setState(() {});
        });
      }
    } on Object {
      // Local schedule and sync remain usable if the status channel is absent.
    }
  }

  void _showSyncWarning() {
    unawaited(
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            AssistantText.titleOf(AssistantEvent.syncStale, _assistantPack),
          ),
          content: Text(
            AssistantText.of(AssistantEvent.syncStale, _assistantPack),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Đóng'),
            ),
          ],
        ),
      ),
    );
  }

  void _scheduleExamClock() {
    _examClockTimer?.cancel();
    final data = _data;
    if (data == null) return;
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day + 1);
    final nextEnd = data.exams
        .map((exam) => exam.endAt)
        .where((end) => !end.isBefore(now))
        .fold<DateTime?>(
          null,
          (next, end) => next == null || end.isBefore(next) ? end : next,
        );
    final boundary = nextEnd == null || !nextEnd.isBefore(midnight)
        ? midnight
        : nextEnd.add(const Duration(milliseconds: 1));
    _examClockTimer = Timer(boundary.difference(now), () {
      if (!mounted) return;
      setState(() {});
      _scheduleExamClock();
    });
  }

  void _scheduleSemesterExpiry(
    RetainedSemester current,
    RetainedSemester? previous,
  ) {
    _semesterExpiryTimer?.cancel();
    final now = DateTime.now();
    final boundaries = <DateTime>[
      current.expiresOn.add(const Duration(days: 1)),
      if (previous != null) previous.expiresOn.add(const Duration(days: 1)),
    ]..sort();
    final next = boundaries.where((date) => date.isAfter(now)).firstOrNull;
    if (next != null) {
      _semesterExpiryTimer = Timer(next.difference(now), () {
        unawaited(_expireStoredSemesters());
      });
    }
  }

  Future<void> _expireStoredSemesters() async {
    final prefs = await SharedPreferences.getInstance();
    final current = await CurrentSemesterStore().read();
    if (current == null) return;
    final start = SemesterRetention.startOf(
      current,
      prefs.getString(SemesterRetention.currentStartKey),
    );
    if (start == null) return;
    final retained = RetainedSemester(current, start);
    final now = DateTime.now();
    if (!retained.activeAt(now)) {
      await CurrentSemesterStore().clear();
      await prefs.remove(_storageKey);
      await prefs.remove(SemesterRetention.currentStartKey);
      await prefs.remove(SemesterRetention.previousKey);
      await WidgetPublisher.clear();
      _semesterExpiryTimer?.cancel();
      if (mounted) setState(() => _data = null);
      return;
    }
    final previous = SemesterRetention.readPrevious(prefs, now);
    if (previous == null) await prefs.remove(SemesterRetention.previousKey);
    final data = SemesterRetention.combine(current, previous);
    if (prefs.getString(_storageKey) != data.encode()) {
      await prefs.setString(_storageKey, data.encode());
      await WidgetPublisher.publish(data, resetToToday: false);
    }
    _scheduleSemesterExpiry(retained, previous);
    if (mounted) setState(() => _data = data);
  }

  void _onNotificationTap() {
    _notificationReturnPage = _page == _AppPage.notifications
        ? _AppPage.timetable
        : _page;
    _openPage(_AppPage.notifications);
  }

  Future<void> _refreshDifference() async {
    final difference = await SemesterDifferenceStore().read();
    final prefs = await SharedPreferences.getInstance();
    final unread =
        difference?.hasChanges == true &&
        prefs.getString(_seenDifferenceKey) != jsonEncode(difference!.toJson());
    if (mounted) {
      setState(() {
        _latestDifference = difference;
        _unreadDifference = unread;
      });
    }
  }

  Future<void> _showDifferences() async {
    await _refreshDifference();
    if (!mounted) return;
    final difference = _latestDifference;
    if (difference != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _seenDifferenceKey,
        jsonEncode(difference.toJson()),
      );
      if (mounted) setState(() => _unreadDifference = false);
    }
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => ScheduleDifferenceSheet(difference: difference),
    );
  }

  Future<void> _refreshExamNotice() async {
    try {
      final notice = await DailySync.examNotice();
      if (mounted) setState(() => _examNotice = notice);
    } on Object {
      // The saved schedule remains usable if the notification channel is unavailable.
    }
  }

  Future<void> _repairStoredDisplayName() async {
    final name = (await readCachedQldtDisplayName()).trim();
    if (name.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final store = CurrentSemesterStore();
    final semester = await store.read();
    if (semester != null && semester.displayName.trim() != name) {
      await store.save(
        CurrentSemester(
          semesterId: semester.semesterId,
          semesterName: semester.semesterName,
          displayName: name,
          syncedAt: semester.syncedAt,
          subjects: semester.subjects,
        ),
      );
    }

    final raw = prefs.getString(_storageKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final data = ImportedScheduleData.decode(raw);
        if (data.displayName.trim() != name) {
          await prefs.setString(
            _storageKey,
            ImportedScheduleData(
              displayName: name,
              records: data.records,
              syncedAt: data.syncedAt,
              source: data.source,
            ).encode(),
          );
        }
      } on Object {
        // A profile repair must never invalidate the saved timetable.
      }
    }
  }

  Future<void> _restore() async {
    try {
      await _repairStoredDisplayName();
      final prefs = await SharedPreferences.getInstance();
      _assistantPack = await AssistantSelection.load();
      _accountDisplayName = await readQldtAccountDisplayName();
      var raw = prefs.getString(_storageKey);
      var semester = await CurrentSemesterStore().read();
      final startedAt = semester == null
          ? null
          : SemesterRetention.startOf(
              semester,
              prefs.getString(SemesterRetention.currentStartKey),
            );
      if (semester != null &&
          startedAt != null &&
          !RetainedSemester(semester, startedAt).activeAt(DateTime.now())) {
        await CurrentSemesterStore().clear();
        await prefs.remove(_storageKey);
        await prefs.remove(SemesterRetention.currentStartKey);
        await prefs.remove(SemesterRetention.previousKey);
        await WidgetPublisher.clear();
        semester = null;
        raw = null;
      }
      if (semester != null || (raw != null && raw.isNotEmpty)) {
        final previous = semester == null
            ? null
            : SemesterRetention.readPrevious(prefs, DateTime.now());
        if (semester != null && previous == null) {
          await prefs.remove(SemesterRetention.previousKey);
        }
        final data =
            (semester == null
                ? null
                : SemesterRetention.combine(semester, previous)) ??
            ImportedScheduleData.decode(raw!);
        _data = data;
        _selectedDate = _initialDateFor(data);
        _scheduleExamClock();
        if (semester != null && startedAt != null) {
          _scheduleSemesterExpiry(
            RetainedSemester(semester, startedAt),
            previous,
          );
        }
        await WidgetPublisher.publish(data, resetToToday: false);
        if (semester != null) {
          try {
            await DailySync.syncReminders();
          } on Object {
            _errorMessage =
                'Không lên lịch được nhắc lịch thi. Hãy thử đồng bộ lại.';
          }
        }
        await DailySync.disable();
        _examNotice = await DailySync.examNotice();
        await _refreshDifference();
      }
    } on Object catch (error) {
      _errorMessage = 'Không đọc được dữ liệu cục bộ: $error';
    }
    if (_data != null) await _refreshSyncStatus();
    await Future<void>.delayed(const Duration(milliseconds: 650));
    if (mounted) {
      setState(() => _booting = false);
    }
  }

  Future<SemesterDifference?> _save(QldtLoginResult result) async {
    final prefs = await SharedPreferences.getInstance();
    final store = CurrentSemesterStore();
    final differenceStore = SemesterDifferenceStore();
    final previousSemester = await store.read();
    final previousDifference = await differenceStore.read();
    final previousSnapshot = prefs.getString(_storageKey);
    final previousStart = prefs.getString(SemesterRetention.currentStartKey);
    final previousArchive = prefs.getString(SemesterRetention.previousKey);
    final previousRoute = prefs.getString(_routeKey);
    final previousWidgetSnapshot = prefs.getString(
      'better_phenikaa_widget_snapshot_v1',
    );
    if (result.semester == null && !kIsWeb) {
      throw const FormatException('Không xác minh được dữ liệu học kỳ QLĐT.');
    }
    if (!kIsWeb && result.schedule.displayName.isEmpty) {
      throw const FormatException('QLDT_CANONICAL_NAME_MISSING');
    }
    if (!kIsWeb &&
        result.semester != null &&
        result.semester!.displayName.isEmpty) {
      throw const FormatException('QLDT_CANONICAL_NAME_MISSING');
    }
    try {
      SemesterDifference? difference;
      var publishedData = result.schedule;
      if (result.semester != null) {
        final now = DateTime.now();
        final startedAt =
            result.termStartedAt ??
            SemesterRetention.startOf(result.semester!, null);
        if (startedAt == null) {
          throw const FormatException('Không xác định được môn đầu học kỳ.');
        }
        var retained = SemesterRetention.readPrevious(prefs, now);
        if (previousSemester != null &&
            previousSemester.semesterId != result.semester!.semesterId) {
          final oldStart = SemesterRetention.startOf(
            previousSemester,
            previousStart,
          );
          if (oldStart != null) {
            final old = RetainedSemester(previousSemester, oldStart);
            if (old.activeAt(now)) retained = old;
          }
        }
        if (retained != null) {
          await prefs.setString(
            SemesterRetention.previousKey,
            retained.encode(),
          );
        } else {
          await prefs.remove(SemesterRetention.previousKey);
        }
        await prefs.setString(
          SemesterRetention.currentStartKey,
          startedAt.toIso8601String(),
        );
        difference = const SemesterChangeDetector().compare(
          previousSemester,
          result.semester!,
        );
        await store.save(result.semester!);
        await differenceStore.save(difference);
        publishedData = SemesterRetention.combine(result.semester!, retained);
        _scheduleSemesterExpiry(
          RetainedSemester(result.semester!, startedAt),
          retained,
        );
      }
      if (!await prefs.setString(_storageKey, publishedData.encode())) {
        throw StateError('Không thể lưu dữ liệu lịch trên thiết bị.');
      }
      if (result.registrationRoute != null &&
          !await prefs.setString(_routeKey, result.registrationRoute!)) {
        throw StateError('Không thể lưu đường dẫn đăng ký trên thiết bị.');
      }
      await WidgetPublisher.publish(publishedData, resetToToday: true);
      await DailySync.disable();
      try {
        await DailySync.recordAppSyncSuccess();
        await _refreshSyncStatus();
        _examNotice = await DailySync.examNotice();
      } on Object {
        // The successful semester snapshot is already stored.
      }
      return difference;
    } on Object {
      if (previousSemester == null) {
        await store.clear();
      } else {
        await store.save(previousSemester);
      }
      if (previousSnapshot == null) {
        await prefs.remove(_storageKey);
      } else {
        await prefs.setString(_storageKey, previousSnapshot);
      }
      if (previousStart == null) {
        await prefs.remove(SemesterRetention.currentStartKey);
      } else {
        await prefs.setString(SemesterRetention.currentStartKey, previousStart);
      }
      if (previousArchive == null) {
        await prefs.remove(SemesterRetention.previousKey);
      } else {
        await prefs.setString(SemesterRetention.previousKey, previousArchive);
      }
      if (previousRoute == null) {
        await prefs.remove(_routeKey);
      } else {
        await prefs.setString(_routeKey, previousRoute);
      }
      if (previousDifference == null) {
        await differenceStore.clear();
      } else {
        await differenceStore.save(previousDifference);
      }
      if (previousWidgetSnapshot == null) {
        await prefs.remove('better_phenikaa_widget_snapshot_v1');
      } else {
        await prefs.setString(
          'better_phenikaa_widget_snapshot_v1',
          previousWidgetSnapshot,
        );
      }
      try {
        final oldData = previousSnapshot == null
            ? previousSemester?.toImportedScheduleData()
            : ImportedScheduleData.decode(previousSnapshot);
        if (oldData != null) {
          await WidgetPublisher.publish(oldData, resetToToday: false);
        }
      } on Object {
        // The saved snapshot remains available for the next widget refresh.
      }
      if (previousSemester != null) {
        final restoredStart = SemesterRetention.startOf(
          previousSemester,
          previousStart,
        );
        if (restoredStart != null) {
          _scheduleSemesterExpiry(
            RetainedSemester(previousSemester, restoredStart),
            SemesterRetention.readPrevious(prefs, DateTime.now()),
          );
        }
      } else {
        _semesterExpiryTimer?.cancel();
      }
      rethrow;
    }
  }

  Future<void> _loginOrSync() async {
    if (!supportsLiveQldtLogin) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'GitHub Pages không thể đọc phiên đăng nhập QLĐT khác tên miền. Đăng nhập thật được bật trong APK Android bằng WebView.',
          ),
        ),
      );
      return;
    }

    setState(() {
      _syncing = true;
      _errorMessage = null;
      _panelOpen = false;
    });
    try {
      final imported = await openQldtLogin(context);
      if (imported != null) {
        final saveStarted = DateTime.now();
        SemesterDifference? difference;
        try {
          difference = await _save(imported);
          // The first-login mini-game is considered complete only after the
          // verified semester has been committed by the app. A chosen name
          // left by an interrupted login must not skip this mandatory step.
          await markQldtFirstLoginSetupComplete();
          await _repairStoredDisplayName();
          try {
            if (qldtDiagnosticsEnabled) {
              await QldtSyncDiagnostics.appendSave(saveStarted, 'OK');
            }
          } on Object {
            // Diagnostics must not change the saved schedule.
          }
        } on Object {
          try {
            if (qldtDiagnosticsEnabled) {
              await QldtSyncDiagnostics.appendSave(saveStarted, 'SAVE_FAILED');
            }
          } on Object {
            // The original save error remains authoritative.
          }
          rethrow;
        }
        if (mounted) {
          final prefs = await SharedPreferences.getInstance();
          final saved = prefs.getString(_storageKey);
          final accountDisplayName = await readQldtAccountDisplayName();
          final displayed = saved == null
              ? imported.schedule
              : ImportedScheduleData.decode(saved);
          if (!mounted) return;
          setState(() {
            _data = displayed;
            _accountDisplayName = accountDisplayName;
            _lastSuccessfulSync = displayed.syncedAt;
            _selectedDate = _initialDateFor(displayed);
            _page = _AppPage.timetable;
          });
          _syncStaleTimer?.cancel();
          _scheduleExamClock();
          if (difference != null) {
            await _refreshDifference();
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  AssistantText.of(
                    difference.initial
                        ? AssistantEvent.syncInitial
                        : difference.study.hasChanges &&
                              difference.exams.hasChanges
                        ? AssistantEvent.studyAndExamChanged
                        : difference.study.hasChanges
                        ? AssistantEvent.studyChanged
                        : difference.exams.hasChanges
                        ? AssistantEvent.examChanged
                        : AssistantEvent.syncSuccessNoChange,
                    _assistantPack,
                  ),
                ),
              ),
            );
          }
          try {
            await DailySync.syncReminders();
          } on Object {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Đã lưu lịch, nhưng chưa lên lịch nhắc thi. Hãy thử đồng bộ lại.',
                  ),
                ),
              );
            }
          }
        }
      }
    } on Object {
      if (mounted) {
        setState(
          () => _errorMessage = AssistantText.of(
            AssistantEvent.syncFailed,
            _assistantPack,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _syncing = false);
      }
    }
  }

  Future<void> _logout() async {
    _examClockTimer?.cancel();
    _syncStaleTimer?.cancel();
    if (!kIsWeb) {
      await _widgetSessionChannel.invokeMethod<void>('invalidate');
    }
    await DailySync.disable();
    await DailySync.clearReminders();
    await clearQldtSession();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
    await prefs.remove(_routeKey);
    await CurrentSemesterStore().clear();
    await SemesterDifferenceStore().clear();
    await WidgetPublisher.clear();
    await prefs.clear();
    if (!kIsWeb) {
      await _widgetSessionChannel.invokeMethod<void>('clear');
    }
    AppThemeController.instance.resetAfterLogout();
    if (mounted) {
      setState(() {
        _data = null;
        _panelOpen = false;
        _page = _AppPage.timetable;
        _errorMessage = null;
        _examNotice = null;
        _latestDifference = null;
        _unreadDifference = false;
        _lastSuccessfulSync = null;
        _assistantPack = AssistantPack.normal;
        _accountDisplayName = '';
      });
    }
  }

  DateTime _initialDateFor(ImportedScheduleData data) {
    final today = _dateOnly(DateTime.now());
    if (data.classes.any((record) => _sameDay(record.startAt, today))) {
      return today;
    }
    final future =
        data.classes.where((record) => !record.startAt.isBefore(today)).toList()
          ..sort((a, b) => a.startAt.compareTo(b.startAt));
    if (future.isNotEmpty) {
      return _dateOnly(future.first.startAt);
    }
    return data.classes.isNotEmpty
        ? _dateOnly(data.classes.last.startAt)
        : today;
  }

  void _openPage(_AppPage page) {
    _exitGestureTimer?.cancel();
    _exitGestureArmed = false;
    setState(() {
      _page = page;
      _panelOpen = false;
      if (page == _AppPage.exam) _examNotice = null;
    });
    if (page == _AppPage.exam) unawaited(_acknowledgeExamNotice());
  }

  void _closeNotificationCenter() => _openPage(_notificationReturnPage);

  void _handleSystemBack(bool didPop) {
    if (didPop) return;
    if (_panelOpen) {
      setState(() => _panelOpen = false);
      return;
    }
    if (_page == _AppPage.notifications) {
      _closeNotificationCenter();
      return;
    }
    if (_page != _AppPage.timetable) {
      _openPage(_AppPage.timetable);
      return;
    }
    if (_exitGestureArmed) {
      _exitGestureTimer?.cancel();
      unawaited(SystemNavigator.pop());
      return;
    }
    _exitGestureArmed = true;
    _exitGestureTimer?.cancel();
    _exitGestureTimer = Timer(const Duration(seconds: 2), () {
      _exitGestureArmed = false;
    });
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Vuốt thêm lần nữa để thoát ứng dụng.'),
          duration: Duration(seconds: 2),
        ),
      );
  }

  Future<void> _acknowledgeExamNotice() async {
    try {
      await DailySync.ackExamNotice();
    } on Object {
      // The exam page remains available if widget state cannot be refreshed.
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = appThemePalette;
    return PopScope(
      canPop: kIsWeb || defaultTargetPlatform != TargetPlatform.android,
      onPopInvokedWithResult: (didPop, _) => _handleSystemBack(didPop),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: AppThemeBackdrop(
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final desktop = constraints.maxWidth > 680;
                return Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: desktop ? 470 : constraints.maxWidth,
                      maxHeight: desktop ? 860 : constraints.maxHeight,
                    ),
                    child: Container(
                      margin: desktop
                          ? const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 16,
                            )
                          : EdgeInsets.zero,
                      decoration: BoxDecoration(
                        color: palette.id == AppThemeId.tienMonPremium
                            ? Colors.transparent
                            : palette.surface.withValues(
                                alpha: desktop ? .98 : .94,
                              ),
                        borderRadius: BorderRadius.circular(
                          desktop &&
                                  palette.geometry == AppThemeGeometry.rounded
                              ? 28
                              : 0,
                        ),
                        boxShadow: desktop
                            ? const <BoxShadow>[
                                BoxShadow(
                                  color: Color(0x140B2259),
                                  blurRadius: 36,
                                  offset: Offset(0, 14),
                                ),
                              ]
                            : null,
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 260),
                        layoutBuilder: (current, previous) =>
                            current ?? const SizedBox.shrink(),
                        child: _booting
                            ? const _SplashScreen()
                            : _data == null || _data!.displayName.isEmpty
                            ? _LoginScreen(
                                onLogin: _loginOrSync,
                                supportsLive: supportsLiveQldtLogin,
                              )
                            : _MainShell(
                                data: _data!,
                                accountDisplayName: _accountDisplayName,
                                page: _page,
                                selectedDate: _selectedDate,
                                showPastExams: _showPastExams,
                                panelOpen: _panelOpen,
                                syncing: _syncing,
                                errorMessage: _errorMessage,
                                examNotice: _examNotice,
                                unreadDifference: _unreadDifference,
                                hasActiveExamPeriod:
                                    ExamPeriod.hasActiveExamPeriod(
                                      _data!.exams,
                                      DateTime.now(),
                                    ),
                                syncStale: const SyncReminderPolicy()
                                    .shouldRemind(
                                      now: DateTime.now(),
                                      lastSuccessfulSync: _lastSuccessfulSync,
                                      lastReminder: null,
                                    ),
                                onSyncWarning: _showSyncWarning,
                                assistantPack: _assistantPack,
                                onAssistantPackChanged: (pack) async {
                                  await AssistantSelection.save(pack);
                                  if (mounted) {
                                    setState(() => _assistantPack = pack);
                                  }
                                },
                                onOpenDifferences: _onNotificationTap,
                                onCloseNotificationCenter:
                                    _closeNotificationCenter,
                                onOpenExamFromNotification: () =>
                                    _openPage(_AppPage.exam),
                                onShowDifferences: _showDifferences,
                                latestDifference: _latestDifference,
                                onTogglePanel: () =>
                                    setState(() => _panelOpen = !_panelOpen),
                                onOpenPage: _openPage,
                                onSync: _loginOrSync,
                                onLogout: _logout,
                                onDateChanged: (date) => setState(
                                  () => _selectedDate = _dateOnly(date),
                                ),
                                onExamTabChanged: (past) =>
                                    setState(() => _showPastExams = past),
                                onDismissError: () =>
                                    setState(() => _errorMessage = null),
                              ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final palette = appThemePalette;
    return _PhoneSurface(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          const _AppMark(size: 76),
          const SizedBox(height: 26),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                themedHeading('Better Phenikaa App', palette),
                maxLines: 1,
                style: TextStyle(
                  color: palette.textPrimary,
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  letterSpacing: themeLetterSpacing(palette),
                ),
              ),
            ),
          ),
          const SizedBox(height: 7),
          Text(
            'cooc.1.0 • Lịch học & Lịch thi',
            style: TextStyle(color: palette.textSecondary, fontSize: 15),
          ),
          const SizedBox(height: 120),
          SizedBox(
            width: 88,
            child: LinearProgressIndicator(
              minHeight: palette.geometry == AppThemeGeometry.pixel ? 6 : 4,
              borderRadius: BorderRadius.all(
                Radius.circular(
                  palette.geometry == AppThemeGeometry.rounded ? 10 : 0,
                ),
              ),
              backgroundColor: palette.cardAlt,
              color: palette.primary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Đang khởi động...',
            style: TextStyle(
              color: palette.textSecondary,
              fontSize: 12,
              shadows: palette.id == AppThemeId.tienMonPremium
                  ? tienMonTextShadows
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _LoginScreen extends StatelessWidget {
  const new({required this.onLogin, required this.supportsLive});

  final VoidCallback onLogin;
  final bool supportsLive;

  @override
  Widget build(BuildContext context) {
    final palette = appThemePalette;
    return _PhoneSurface(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(32, 58, 32, 30),
        child: Column(
          children: <Widget>[
            const Spacer(),
            const _AppMark(size: 62),
            const SizedBox(height: 22),
            Text(
              themedHeading('Chào mừng bạn!', palette),
              style: TextStyle(
                color: palette.textPrimary,
                fontSize: 28,
                fontWeight: FontWeight.w900,
                letterSpacing: themeLetterSpacing(palette),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Kết nối với QLĐT để xem lịch học và lịch thi của bạn',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: palette.textSecondary,
                height: 1.55,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 38),
            SizedBox(
              width: double.infinity,
              height: 62,
              child: FilledButton(
                onPressed: onLogin,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    const _MicrosoftMark(),
                    const SizedBox(width: 14),
                    Text(
                      supportsLive
                          ? 'Đăng nhập QLĐT\n(Microsoft)'
                          : 'Đăng nhập QLĐT thật\n(Android APK)',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 22),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(
                  Icons.lock_outline,
                  size: 17,
                  color: palette.textSecondary,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Dữ liệu chỉ lưu cục bộ trên thiết bị của bạn',
                    style: TextStyle(
                      color: palette.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const Spacer(flex: 2),
            Text(
              'Better Phenikaa App • ${AppThemeController.instance.theme.label}',
              style: TextStyle(
                color: palette.textSecondary,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MainShell extends StatefulWidget {
  const new({
    required this.data,
    required this.accountDisplayName,
    required this.page,
    required this.selectedDate,
    required this.showPastExams,
    required this.panelOpen,
    required this.syncing,
    required this.errorMessage,
    required this.examNotice,
    required this.unreadDifference,
    required this.hasActiveExamPeriod,
    required this.syncStale,
    required this.onSyncWarning,
    required this.assistantPack,
    required this.onAssistantPackChanged,
    required this.onOpenDifferences,
    required this.onCloseNotificationCenter,
    required this.onOpenExamFromNotification,
    required this.onShowDifferences,
    required this.latestDifference,
    required this.onTogglePanel,
    required this.onOpenPage,
    required this.onSync,
    required this.onLogout,
    required this.onDateChanged,
    required this.onExamTabChanged,
    required this.onDismissError,
  });

  final ImportedScheduleData data;
  final String accountDisplayName;
  final _AppPage page;
  final DateTime selectedDate;
  final bool showPastExams;
  final bool panelOpen;
  final bool syncing;
  final String? errorMessage;
  final String? examNotice;
  final bool unreadDifference;
  final bool hasActiveExamPeriod;
  final bool syncStale;
  final VoidCallback onSyncWarning;
  final AssistantPack assistantPack;
  final ValueChanged<AssistantPack> onAssistantPackChanged;
  final VoidCallback onOpenDifferences;
  final VoidCallback onCloseNotificationCenter;
  final VoidCallback onOpenExamFromNotification;
  final Future<void> Function() onShowDifferences;
  final SemesterDifference? latestDifference;
  final VoidCallback onTogglePanel;
  final ValueChanged<_AppPage> onOpenPage;
  final VoidCallback onSync;
  final VoidCallback onLogout;
  final ValueChanged<DateTime> onDateChanged;
  final ValueChanged<bool> onExamTabChanged;
  final VoidCallback onDismissError;

  @override
  State<_MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<_MainShell>
    with SingleTickerProviderStateMixin {
  static const Duration _pageFadeDuration = Duration(milliseconds: 240);

  late _AppPage _displayPage;
  late final AnimationController _pageFadeController = AnimationController(
    vsync: this,
    duration: _pageFadeDuration,
    value: 1,
  );
  late final Animation<double> _pageFade = CurvedAnimation(
    parent: _pageFadeController,
    curve: Curves.easeOutCubic,
  );

  @override
  void initState() {
    super.initState();
    _displayPage = widget.page;
  }

  @override
  void didUpdateWidget(covariant _MainShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.page == widget.page) return;

    // Main navigation keeps every page mounted in the IndexedStack. Switch
    // the active page immediately, then fade the new page in: slower than the
    // calendar panel, but quicker than the full Day <-> Week transition.
    setState(() => _displayPage = widget.page);
    _pageFadeController.forward(from: 0);
  }

  @override
  void dispose() {
    _pageFadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final accountDisplayName = widget.accountDisplayName;
    final page = widget.page;
    final selectedDate = widget.selectedDate;
    final showPastExams = widget.showPastExams;
    final panelOpen = widget.panelOpen;
    final syncing = widget.syncing;
    final errorMessage = widget.errorMessage;
    final examNotice = widget.examNotice;
    final unreadDifference = widget.unreadDifference;
    final hasActiveExamPeriod = widget.hasActiveExamPeriod;
    final syncStale = widget.syncStale;
    final onSyncWarning = widget.onSyncWarning;
    final assistantPack = widget.assistantPack;
    final onAssistantPackChanged = widget.onAssistantPackChanged;
    final onOpenDifferences = widget.onOpenDifferences;
    final onCloseNotificationCenter = widget.onCloseNotificationCenter;
    final onOpenExamFromNotification = widget.onOpenExamFromNotification;
    final onShowDifferences = widget.onShowDifferences;
    final latestDifference = widget.latestDifference;
    final onTogglePanel = widget.onTogglePanel;
    final onOpenPage = widget.onOpenPage;
    final onSync = widget.onSync;
    final onLogout = widget.onLogout;
    final onDateChanged = widget.onDateChanged;
    final onExamTabChanged = widget.onExamTabChanged;
    final onDismissError = widget.onDismissError;
    final palette = appThemePalette;
    final pageIndex = switch (_displayPage) {
      _AppPage.timetable => 0,
      _AppPage.exam => 1,
      _AppPage.account => 2,
      _AppPage.notifications => 3,
    };

    return _PhoneSurface(
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: FadeTransition(
              opacity: _pageFade,
              child: IndexedStack(
                index: pageIndex,
                sizing: StackFit.expand,
              children: <Widget>[
                TickerMode(
                  enabled: _displayPage == _AppPage.timetable,
                  child: RepaintBoundary(
                    child: _TimetableScreen(
                      data: data,
                      assistantPack: assistantPack,
                      selectedDate: selectedDate,
                      onDateChanged: onDateChanged,
                      unreadDifference: unreadDifference,
                      hasActiveExamPeriod: hasActiveExamPeriod,
                      onOpenDifferences: onOpenDifferences,
                    ),
                  ),
                ),
                TickerMode(
                  enabled: _displayPage == _AppPage.exam,
                  child: RepaintBoundary(
                    child: _ExamScreen(
                      data: data,
                      assistantPack: assistantPack,
                      showPast: showPastExams,
                      onTabChanged: onExamTabChanged,
                      unreadDifference: unreadDifference,
                      hasActiveExamPeriod: hasActiveExamPeriod,
                      onOpenDifferences: onOpenDifferences,
                    ),
                  ),
                ),
                TickerMode(
                  enabled: _displayPage == _AppPage.account,
                  child: RepaintBoundary(
                    child: _AccountScreen(
                      data: data,
                      accountDisplayName: accountDisplayName,
                      onLogout: onLogout,
                      onSync: onSync,
                      assistantPack: assistantPack,
                      onAssistantPackChanged: onAssistantPackChanged,
                    ),
                  ),
                ),
                TickerMode(
                  enabled: _displayPage == _AppPage.notifications,
                  child: RepaintBoundary(
                    child: _NotificationCenterScreen(
                      hasActiveExamPeriod: hasActiveExamPeriod,
                      onBack: onCloseNotificationCenter,
                      onOpenExam: onOpenExamFromNotification,
                      onDetails: onShowDifferences,
                      assistantPack: assistantPack,
                      difference: latestDifference,
                    ),
                  ),
                ),
                ],
              ),
            ),
          ),
          if (errorMessage != null)
            Positioned(
              left: 16,
              right: 16,
              top: 14,
              child: _ErrorBanner(
                message: errorMessage!,
                onDismiss: onDismissError,
              ),
            ),
          if (syncing)
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: LinearProgressIndicator(
                minHeight: 3,
                color: palette.primary,
              ),
            ),
          if (page != _AppPage.notifications && panelOpen)
            Positioned.fill(
              child: GestureDetector(
                onTap: onTogglePanel,
                child: Container(color: Colors.black.withValues(alpha: .48)),
              ),
            ),
          if (page != _AppPage.notifications && panelOpen)
            Positioned(
              right: 10,
              bottom: 78,
              child: _ControlPanel(
                page: page,
                hasActiveExamPeriod: hasActiveExamPeriod,
                onOpenPage: onOpenPage,
                onSync: onSync,
              ),
            ),
          if (page != _AppPage.notifications)
            Positioned(
              right: 22,
              bottom: 28,
              child: FloatingActionButton(
                heroTag: 'control-panel',
                onPressed: onTogglePanel,
                backgroundColor: palette.primary,
                foregroundColor: palette.id == AppThemeId.lol
                    ? const Color(0xFF06171D)
                    : Colors.white,
                elevation: palette.geometry == AppThemeGeometry.pixel ? 0 : 8,
                shape: themeButtonShape(palette),
                child: AnimatedRotation(
                  turns: panelOpen ? .125 : 0,
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 140),
                    child: Icon(
                      panelOpen ? Icons.close : Icons.grid_view_rounded,
                      key: ValueKey<bool>(panelOpen),
                    ),
                  ),
                ),
              ),
            ),
          if (page != _AppPage.notifications && syncStale)
            Positioned(
              left: 22,
              bottom: 28,
              child: FloatingActionButton(
                heroTag: 'sync-stale-warning',
                onPressed: onSyncWarning,
                tooltip: 'Đã lâu chưa đồng bộ',
                backgroundColor: palette.primary,
                foregroundColor: palette.id == AppThemeId.lol
                    ? const Color(0xFF06171D)
                    : Colors.white,
                elevation: palette.geometry == AppThemeGeometry.pixel ? 0 : 8,
                shape: themeButtonShape(palette),
                child: const Icon(Icons.warning_amber_rounded),
              ),
            ),
        ],
      ),
    );
  }
}

class _TimetableScreen extends StatefulWidget {
  const new({
    required this.data,
    required this.assistantPack,
    required this.selectedDate,
    required this.onDateChanged,
    required this.unreadDifference,
    required this.hasActiveExamPeriod,
    required this.onOpenDifferences,
  });

  final ImportedScheduleData data;
  final AssistantPack assistantPack;
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateChanged;
  final bool unreadDifference;
  final bool hasActiveExamPeriod;
  final VoidCallback onOpenDifferences;

  @override
  State<_TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends State<_TimetableScreen>
    with WidgetsBindingObserver {
  bool _weekly = false;
  int _modeSwitchSerial = 0;
  final ValueNotifier<bool> _weeklySelection = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _weeklyMode = ValueNotifier<bool>(false);
  final ValueNotifier<double> _modeOpacity = ValueNotifier<double>(1);
  DateTime _week = weekMonday(DateTime.now());

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _weeklySelection.dispose();
    _weeklyMode.dispose();
    _modeOpacity.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_weekly) {
      widget.onDateChanged(DateTime.now());
    }
  }

  Future<void> _changeTimetableMode(bool nextWeekly) async {
    if (_weekly == nextWeekly) return;
    _weekly = nextWeekly;
    final serial = ++_modeSwitchSerial;

    // Highlight responds immediately. The content itself fades out/in so the
    // heavy week/day raster never blocks the button feedback.
    _weeklySelection.value = nextWeekly;
    _modeOpacity.value = 0;
    await Future<void>.delayed(const Duration(milliseconds: 150));

    if (!mounted || serial != _modeSwitchSerial || _weekly != nextWeekly) {
      return;
    }

    if (!nextWeekly) {
      _week = weekMonday(DateTime.now());
      _weeklyMode.value = false;
      widget.onDateChanged(DateTime.now());
    } else {
      _weeklyMode.value = true;
    }

    await WidgetsBinding.instance.endOfFrame;
    if (!mounted || serial != _modeSwitchSerial || _weekly != nextWeekly) {
      return;
    }
    _modeOpacity.value = 1;
  }

  Future<void> _pickWeek() async {
    final palette = appThemePalette;
    final picked = await showGeneralDialog<DateTime>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Đóng lịch chọn tuần',
      barrierColor: Colors.black.withValues(alpha: .48),
      transitionDuration: const Duration(milliseconds: 190),
      transitionBuilder: (context, animation, secondaryAnimation, child) =>
          FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            ),
            child: child,
          ),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        final screenHeight = MediaQuery.sizeOf(dialogContext).height;
        final bottomReserve = _calendarBottomReserve(dialogContext);
        final sheetHeight = screenHeight * .62 < 440
            ? screenHeight * .62
            : 440.0;
        return Material(
          color: Colors.transparent,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: EdgeInsets.only(bottom: bottomReserve),
              child: Container(
                height: sheetHeight,
                decoration: BoxDecoration(
                  color: palette.surface,
                  border: Border(top: BorderSide(color: palette.border)),
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(
                      palette.geometry == AppThemeGeometry.rounded ? 30 : 0,
                    ),
                  ),
                ),
                child: Column(
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              'Chọn tuần',
                              style: TextStyle(
                                color: palette.textPrimary,
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () =>
                                Navigator.pop(dialogContext, DateTime.now()),
                            child: const Text('Tuần hiện tại'),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Theme(
                        data: buildBetterTheme(palette),
                        child: CalendarDatePicker(
                          initialDate: _week,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                          onDateChanged: (date) =>
                              Navigator.pop(dialogContext, date),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
    if (picked != null && mounted) {
      setState(() => _week = weekMonday(picked));
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.data.classes
        .where((record) => _sameDay(record.startAt, widget.selectedDate))
        .toList(growable: false);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (velocity.abs() < 180) {
          return;
        }
        if (!_weekly) {
          widget.onDateChanged(
            widget.selectedDate.add(Duration(days: velocity < 0 ? 1 : -1)),
          );
        }
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 26, 22, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _TopTitle(
              title: 'Lịch học',
              badge: null,
              unreadDifference: widget.unreadDifference,
              hasActiveExamPeriod: widget.hasActiveExamPeriod,
              onNotificationTap: widget.onOpenDifferences,
              onCalendarTap: () => _weekly
                  ? _pickWeek()
                  : _showCalendarPicker(
                      context,
                      widget.selectedDate,
                      widget.onDateChanged,
                    ),
            ),
            const SizedBox(height: 12),
            ValueListenableBuilder<bool>(
              valueListenable: _weeklySelection,
              builder: (context, weekly, _) => _TimetableModeSelector(
                weekly: weekly,
                onChanged: (nextWeekly) =>
                    unawaited(_changeTimetableMode(nextWeekly)),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ValueListenableBuilder<double>(
                valueListenable: _modeOpacity,
                builder: (context, opacity, _) => AnimatedOpacity(
                  opacity: opacity,
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeInOutCubic,
                  child: ValueListenableBuilder<bool>(
                    valueListenable: _weeklyMode,
                    builder: (context, weekly, _) => IndexedStack(
                      index: weekly ? 1 : 0,
                      sizing: StackFit.expand,
                      children: <Widget>[
                    TickerMode(
                      enabled: !weekly,
                      child: RepaintBoundary(
                        child: Column(
                          children: <Widget>[
                            _DateNavigator(
                              date: widget.selectedDate,
                              onTap: () => _showCalendarPicker(
                                context,
                                widget.selectedDate,
                                widget.onDateChanged,
                              ),
                              onPrevious: () => widget.onDateChanged(
                                widget.selectedDate.subtract(
                                  const Duration(days: 1),
                                ),
                              ),
                              onNext: () => widget.onDateChanged(
                                widget.selectedDate.add(
                                  const Duration(days: 1),
                                ),
                              ),
                            ),
                            const SizedBox(height: 18),
                            Expanded(
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 210),
                                switchInCurve: Curves.easeOutCubic,
                                switchOutCurve: Curves.easeOutCubic,
                                layoutBuilder: (current, previous) =>
                                    current ?? const SizedBox.shrink(),
                                transitionBuilder: (child, animation) {
                                  final slide = Tween<Offset>(
                                    begin: const Offset(.10, 0),
                                    end: Offset.zero,
                                  ).animate(animation);
                                  return SlideTransition(
                                    position: slide,
                                    child: child,
                                  );
                                },
                                child: KeyedSubtree(
                                  key: ValueKey<String>(
                                    '${widget.selectedDate.year}-${widget.selectedDate.month}-${widget.selectedDate.day}',
                                  ),
                                  child: items.isEmpty
                                      ? _EmptyState(
                                          icon:
                                              Icons.event_available_outlined,
                                          title:
                                              _sameDay(
                                                widget.selectedDate,
                                                DateTime.now(),
                                              )
                                              ? AssistantText.of(
                                                  AssistantEvent.studyTodayEmpty,
                                                  widget.assistantPack,
                                                )
                                              : 'Không có lịch học',
                                          message:
                                              'Vuốt sang ngày khác, bấm ngày hoặc biểu tượng lịch để chọn nhanh.',
                                        )
                                      : ListView.separated(
                                          padding: const EdgeInsets.only(
                                            bottom: 82,
                                          ),
                                          itemCount: items.length,
                                          separatorBuilder: (_, _) =>
                                              const SizedBox(height: 14),
                                          itemBuilder: (context, index) =>
                                              _ScheduleCard(
                                                item: items[index],
                                                accent: _accentFor(index),
                                              ),
                                        ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    TickerMode(
                      enabled: weekly,
                      child: RepaintBoundary(
                        child: WeekTimetable(
                          data: widget.data,
                          week: _week,
                          onWeekChanged: (value) =>
                              setState(() => _week = weekMonday(value)),
                          onPickWeek: _pickWeek,
                        ),
                      ),
                    ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExamScreen extends StatelessWidget {
  const new({
    required this.data,
    required this.assistantPack,
    required this.showPast,
    required this.onTabChanged,
    required this.unreadDifference,
    required this.hasActiveExamPeriod,
    required this.onOpenDifferences,
  });

  final ImportedScheduleData data;
  final AssistantPack assistantPack;
  final bool showPast;
  final ValueChanged<bool> onTabChanged;
  final bool unreadDifference;
  final bool hasActiveExamPeriod;
  final VoidCallback onOpenDifferences;

  @override
  Widget build(BuildContext context) {
    final referenceNow = DateTime.now();
    final exams = data.exams
        .where((record) {
          return showPast
              ? record.endAt.isBefore(referenceNow)
              : !record.endAt.isBefore(referenceNow);
        })
        .toList(growable: false);

    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 26, 22, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _TopTitle(
            title: 'Lịch thi',
            badge: null,
            unreadDifference: unreadDifference,
            hasActiveExamPeriod: hasActiveExamPeriod,
            onNotificationTap: onOpenDifferences,
          ),
          const SizedBox(height: 20),
          _SegmentTabs(showPast: showPast, onChanged: onTabChanged),
          const SizedBox(height: 18),
          Expanded(
            child: exams.isEmpty
                ? _EmptyState(
                    icon: Icons.assignment_turned_in_outlined,
                    title: showPast
                        ? 'Chưa có kỳ thi đã qua'
                        : AssistantText.of(
                            AssistantEvent.examEmpty,
                            assistantPack,
                          ),
                    message: 'Dữ liệu sẽ được cập nhật sau lần đồng bộ QLĐT tiếp theo.',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.only(bottom: 82),
                    itemCount: exams.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) =>
                        _ExamCard(item: exams[index]),
                  ),
          ),
        ],
      ),
    );
  }
}

class _NotificationCenterScreen extends StatelessWidget {
  const new({
    required this.hasActiveExamPeriod,
    required this.onBack,
    required this.onOpenExam,
    required this.onDetails,
    required this.assistantPack,
    required this.difference,
  });

  final bool hasActiveExamPeriod;
  final VoidCallback onBack;
  final VoidCallback onOpenExam;
  final Future<void> Function() onDetails;
  final AssistantPack assistantPack;
  final SemesterDifference? difference;

  @override
  Widget build(BuildContext context) {
    final palette = appThemePalette;
    final currentDifference = difference;
    final hasStudy =
        currentDifference?.study.hasChanges == true ||
        currentDifference?.addedSubjects.isNotEmpty == true ||
        currentDifference?.removedSubjects.isNotEmpty == true;
    final hasExam = currentDifference?.exams.hasChanges == true;
    final hasAnyChange = currentDifference?.hasChanges == true;
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 26, 22, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              IconButton(
                tooltip: 'Quay lại',
                onPressed: onBack,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                icon: Icon(Icons.arrow_back_rounded, color: palette.primary),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  themedHeading('Thông báo', palette),
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 25,
                    fontWeight: FontWeight.w900,
                    letterSpacing: themeLetterSpacing(palette),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 20),
              children: <Widget>[
                if (hasActiveExamPeriod)
                  _NotificationExamCard(
                    text: AssistantText.of(
                      AssistantEvent.examPeriodActive,
                      assistantPack,
                    ),
                    palette: palette,
                    onOpenExam: onOpenExam,
                  ),
                if (hasAnyChange) ...<Widget>[
                  if (hasActiveExamPeriod) const SizedBox(height: 18),
                  Text(
                    'Thay đổi lịch',
                    style: TextStyle(
                      color: palette.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (hasStudy)
                    _NotificationChangeCard(
                      icon: Icons.event_available_rounded,
                      title: 'Thay đổi môn học',
                      description: AssistantText.of(
                        AssistantEvent.studyChanged,
                        assistantPack,
                      ),
                      count:
                          (currentDifference?.study.added ?? 0) +
                          (currentDifference?.study.removed ?? 0) +
                          (currentDifference?.study.modified ?? 0) +
                          (currentDifference?.addedSubjects.length ?? 0) +
                          (currentDifference?.removedSubjects.length ?? 0),
                      palette: palette,
                    ),
                  if (hasStudy && hasExam) const SizedBox(height: 10),
                  if (hasExam)
                    _NotificationChangeCard(
                      icon: Icons.assignment_rounded,
                      title: 'Thay đổi lịch thi',
                      description: AssistantText.of(
                        AssistantEvent.examChanged,
                        assistantPack,
                      ),
                      count:
                          (currentDifference?.exams.added ?? 0) +
                          (currentDifference?.exams.removed ?? 0) +
                          (currentDifference?.exams.modified ?? 0),
                      palette: palette,
                    ),
                  const SizedBox(height: 14),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: () => unawaited(onDetails()),
                      icon: const Icon(Icons.open_in_new_rounded, size: 18),
                      label: const Text('Chi tiết'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: palette.primary,
                        side: BorderSide(color: palette.primary),
                        shape: themeButtonShape(palette),
                      ),
                    ),
                  ),
                ],
                if (!hasActiveExamPeriod && !hasAnyChange)
                  Padding(
                    padding: const EdgeInsets.only(top: 90),
                    child: _EmptyState(
                      icon: Icons.notifications_none_rounded,
                      title: AssistantText.of(
                        AssistantEvent.notificationEmpty,
                        assistantPack,
                      ),
                      message: AssistantText.of(
                        AssistantEvent.notificationEmptyDescription,
                        assistantPack,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationExamCard extends StatelessWidget {
  const new({
    required this.text,
    required this.palette,
    required this.onOpenExam,
  });

  final String text;
  final AppThemePalette palette;
  final VoidCallback onOpenExam;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: palette.cardAlt,
      borderRadius: BorderRadius.circular(
        palette.geometry == AppThemeGeometry.rounded ? 16 : 0,
      ),
      border: Border.all(color: palette.primary, width: 1.4),
    ),
    child: Row(
      children: <Widget>[
        Icon(Icons.school_rounded, color: palette.primary, size: 26),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: palette.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          tooltip: 'Mở lịch thi',
          onPressed: onOpenExam,
          constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          padding: EdgeInsets.zero,
          style: IconButton.styleFrom(
            backgroundColor: palette.primary,
            foregroundColor: _contrastForeground(palette.primary),
            shape: const CircleBorder(),
          ),
          icon: const Icon(Icons.arrow_forward_rounded),
        ),
      ],
    ),
  );
}

class _NotificationChangeCard extends StatelessWidget {
  const new({
    required this.icon,
    required this.title,
    required this.description,
    required this.count,
    required this.palette,
  });

  final IconData icon;
  final String title;
  final String description;
  final int count;
  final AppThemePalette palette;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: palette.surface,
      borderRadius: BorderRadius.circular(
        palette.geometry == AppThemeGeometry.rounded ? 16 : 0,
      ),
      border: Border.all(color: palette.border),
    ),
    child: Row(
      children: <Widget>[
        Icon(icon, color: palette.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: TextStyle(
                  color: palette.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(description, style: TextStyle(color: palette.textSecondary)),
            ],
          ),
        ),
        if (count > 0)
          Text(
            '$count',
            style: TextStyle(
              color: palette.primary,
              fontWeight: FontWeight.w900,
            ),
          ),
      ],
    ),
  );
}

class _AccountScreen extends StatelessWidget {
  static const bool _assistantTestPanelEnabled = bool.fromEnvironment(
    'ASSISTANT_TEST_PANEL',
  );
  const new({
    required this.data,
    required this.accountDisplayName,
    required this.onLogout,
    required this.onSync,
    required this.assistantPack,
    required this.onAssistantPackChanged,
  });

  final ImportedScheduleData data;
  final String accountDisplayName;
  final VoidCallback onLogout;
  final VoidCallback onSync;
  final AssistantPack assistantPack;
  final ValueChanged<AssistantPack> onAssistantPackChanged;
  static const _widgetPinChannel = MethodChannel('better_phenikaa/widget_pin');
  static const _assistantTestChannel = MethodChannel(
    'better_phenikaa/assistant_test',
  );

  Future<void> _showWidgetOptions(BuildContext context, String type) async {
    final name = type == 'overview' ? 'Widget 4×2' : 'Widget 1×4';
    final shouldPin = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(name),
        content: const Text('Đưa widget này ra màn hình chính?'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Đóng'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Đưa ra màn hình'),
          ),
        ],
      ),
    );
    if (shouldPin != true || !context.mounted) return;
    await _requestWidgetPin(context, type);
  }

  Future<void> _requestWidgetPin(BuildContext context, String type) async {
    try {
      final requested = await _widgetPinChannel.invokeMethod<bool>(
        'requestPin',
        type,
      );
      if (!context.mounted) return;
      if (requested != true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Màn hình chính không hỗ trợ thêm trực tiếp. Hãy nhấn giữ màn hình chính và chọn Widget.',
            ),
          ),
        );
      }
    } on PlatformException {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không mở được trình thêm widget.')),
      );
    }
  }

  static const _assistantUseCaseLabels = <String>[
    'Nhắc đã lâu chưa đồng bộ',
    'Đồng bộ xong, không có thay đổi',
    'Lịch học thay đổi',
    'Lịch thi thay đổi',
    'Lịch học và lịch thi cùng thay đổi',
    'Còn 7 ngày tới kỳ thi',
    'Còn 3 ngày tới kỳ thi',
    'Ngày mai thi',
    'Còn X ngày tới kỳ thi',
    'Đang trong kỳ thi',
    'Còn X ngày, có N môn thi',
    'Widget đồng bộ xong, có thay đổi',
    'Widget đồng bộ xong, không thay đổi',
    'Có thay đổi chưa đọc',
    'Chưa có lịch thi',
    'Hôm nay không có lịch học',
    'Đồng bộ thất bại',
    'Đồng bộ quá lâu / timeout',
  ];

  static (AssistantEvent, int, int) _assistantPreviewSpec(int useCase) =>
      switch (useCase) {
        1 => (AssistantEvent.syncStale, 0, 1),
        2 => (AssistantEvent.syncSuccessNoChange, 0, 1),
        3 => (AssistantEvent.studyChanged, 0, 1),
        4 => (AssistantEvent.examChanged, 0, 1),
        5 => (AssistantEvent.studyAndExamChanged, 0, 1),
        6 => (AssistantEvent.examInDays, 7, 1),
        7 => (AssistantEvent.examInDays, 3, 1),
        8 => (AssistantEvent.examTomorrow, 1, 1),
        9 => (AssistantEvent.examInDays, 5, 1),
        10 => (AssistantEvent.examPeriodActive, 0, 1),
        11 => (AssistantEvent.examCountdownMultiple, 5, 2),
        12 => (AssistantEvent.widgetSyncChanged, 0, 1),
        13 => (AssistantEvent.widgetSyncUnchanged, 0, 1),
        14 => (AssistantEvent.differenceUnread, 0, 1),
        15 => (AssistantEvent.examEmpty, 0, 1),
        16 => (AssistantEvent.studyTodayEmpty, 0, 1),
        17 => (AssistantEvent.syncFailed, 0, 1),
        18 => (AssistantEvent.syncTimeout, 0, 1),
        _ => throw RangeError.range(useCase, 1, 18, 'useCase'),
      };

  Future<void> _triggerAssistantUseCase(
    BuildContext context,
    int useCase,
  ) async {
    final (event, days, examCount) = _assistantPreviewSpec(useCase);

    if (<int>{1, 3, 4, 5, 6, 7, 8, 9, 11}.contains(useCase)) {
      try {
        final delivered = await _assistantTestChannel.invokeMethod<bool>(
          'trigger',
          useCase,
        );
        if (delivered == true || !context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Không thể đẩy thông báo. Hãy bật quyền thông báo cho ứng dụng.',
            ),
          ),
        );
      } on PlatformException catch (error) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không gọi được notification: ${error.code}')),
        );
      }
      return;
    }

    final message = AssistantText.of(
      event,
      assistantPack,
      days: days,
      examCount: examCount,
    );

    if (<int>{2, 12, 13}.contains(useCase)) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
      return;
    }

    if (!context.mounted) return;
    final palette = appThemePalette;
    final Widget? surface = switch (useCase) {
      10 => _NotificationExamCard(
        text: message,
        palette: palette,
        onOpenExam: () => Navigator.of(context).pop(),
      ),
      14 => _NotificationChangeCard(
        icon: Icons.notifications_active_rounded,
        title: 'Thay đổi lịch',
        description: message,
        count: 1,
        palette: palette,
      ),
      15 => _EmptyState(
        icon: Icons.assignment_turned_in_outlined,
        title: message,
        message: 'Dữ liệu sẽ được cập nhật sau lần đồng bộ QLĐT tiếp theo.',
      ),
      16 => _EmptyState(
        icon: Icons.event_available_outlined,
        title: message,
        message:
            'Vuốt sang ngày khác, bấm ngày hoặc biểu tượng lịch để chọn nhanh.',
      ),
      17 || 18 => _ErrorBanner(
        message: message,
        onDismiss: () => Navigator.of(context).pop(),
      ),
      _ => null,
    };
    if (surface == null) return;

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (routeContext) => Scaffold(
          appBar: AppBar(
            title: Text(
              'U$useCase · ${_assistantUseCaseLabels[useCase - 1]}',
            ),
          ),
          body: _PhoneSurface(
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Align(
                alignment: useCase == 17 || useCase == 18
                    ? Alignment.topCenter
                    : Alignment.center,
                child: surface,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = appThemePalette;
    final next = _nextForAccount(data);
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const _TopTitle(title: 'Tài khoản', badge: null),
                  const SizedBox(height: 26),
                  Row(
                    children: <Widget>[
                      CircleAvatar(
                        radius: 38,
                        backgroundColor: palette.primary,
                        child: Icon(
                          Icons.person_rounded,
                          color: palette.id == AppThemeId.lol
                              ? const Color(0xFF06171D)
                              : Colors.white,
                          size: 48,
                        ),
                      ),
                      const SizedBox(width: 18),
                      Expanded(
                        child: Text(
                          accountDisplayName.isEmpty
                              ? data.displayName
                              : accountDisplayName,
                          style: TextStyle(
                            color: palette.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            letterSpacing: themeLetterSpacing(palette),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  RepaintBoundary(child: _InfoPanel(data: data)), 
                  const SizedBox(height: 12),
                  const RepaintBoundary(child: AppThemeSettingButton()),
                  const SizedBox(height: 12),
                  Text(
                    'Model Trợ Lí',
                    style: TextStyle(
                      color: palette.textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  PopupMenuButton<AssistantPack>(
                    tooltip: 'Chọn Trợ lí',
                    onSelected: onAssistantPackChanged,
                    itemBuilder: (context) => AssistantPack.values
                        .map(
                          (pack) => PopupMenuItem(
                            value: pack,
                            child: Row(
                              children: <Widget>[
                                Expanded(
                                  child: Text(
                                    pack.label,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (pack == assistantPack)
                                  Icon(Icons.check, color: palette.primary),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 44),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: palette.primary),
                        borderRadius: BorderRadius.circular(
                          palette.geometry == AppThemeGeometry.rounded ? 12 : 0,
                        ),
                      ),
                      child: Row(
                        children: <Widget>[
                          Icon(
                            Icons.assistant_outlined,
                            color: palette.primary,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Trợ lí: ${assistantPack.label}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const Icon(Icons.arrow_drop_down),
                        ],
                      ),
                    ),
                  ),
                  if (_assistantTestPanelEnabled) ...<Widget>[
                    const SizedBox(height: 8),
                    Theme(
                      data: Theme.of(context).copyWith(
                        dividerColor: Colors.transparent,
                      ),
                      child: ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        childrenPadding: const EdgeInsets.only(bottom: 4),
                        title: Text(
                          'Kiểm tra 18 use case trợ lí',
                          style: TextStyle(
                            color: palette.textPrimary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        subtitle: Text(
                          'Bấm U để gọi đúng chức năng thật • U9: X=5 • U11: X=5, N=2',
                          style: TextStyle(
                            color: palette.textSecondary,
                            fontSize: 11.5,
                          ),
                        ),
                        children: <Widget>[
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: List<Widget>.generate(18, (index) {
                                final useCase = index + 1;
                                return SizedBox(
                                  width: 54,
                                  height: 40,
                                  child: OutlinedButton(
                                    onPressed: () => unawaited(
                                      _triggerAssistantUseCase(
                                        context,
                                        useCase,
                                      ),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      padding: EdgeInsets.zero,
                                      side: BorderSide(color: palette.border),
                                      shape: themeButtonShape(palette),
                                    ),
                                    child: Text(
                                      'U$useCase',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                );
                              }),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (next != null)
                    GestureDetector(
                      onTap: () =>
                          unawaited(_showWidgetOptions(context, 'small')),
                      onLongPress: () =>
                          unawaited(_requestWidgetPin(context, 'small')),
                      child: RepaintBoundary(
                        child: _WidgetPreview(item: next),
                      ),
                    ),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: () =>
                        unawaited(_showWidgetOptions(context, 'overview')),
                    onLongPress: () =>
                        unawaited(_requestWidgetPin(context, 'overview')),
                    child: RepaintBoundary(
                      child: _OverviewWidgetPreview(
                        data: data,
                        date: next?.startAt,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton.icon(
              onPressed: onSync,
              icon: const Icon(Icons.sync_rounded),
              label: const Text('Đồng bộ lại QLĐT'),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: onLogout,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFE55656),
                side: const BorderSide(color: Color(0xFFFF7777)),
                shape: themeButtonShape(palette),
              ),
              icon: const Icon(Icons.logout_rounded, size: 19),
              label: const Text(
                'Đăng xuất',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: 76),
        ],
      ),
    );
  }

  static ScheduleRecord? _nextForAccount(ImportedScheduleData data) {
    if (data.classes.isEmpty) return null;
    final reference = DateTime.now();
    final items =
        data.classes
            .where((record) => !record.endAt.isBefore(reference))
            .toList()
          ..sort((a, b) => a.startAt.compareTo(b.startAt));
    return items.isEmpty ? null : items.first;
  }
}

class _TopTitle extends StatelessWidget {
  const new({
    required this.title,
    this.badge,
    this.onCalendarTap,
    this.onNotificationTap,
    this.unreadDifference = false,
    this.hasActiveExamPeriod = false,
  });

  final String title;
  final String? badge;
  final VoidCallback? onCalendarTap;
  final VoidCallback? onNotificationTap;
  final bool unreadDifference;
  final bool hasActiveExamPeriod;

  @override
  Widget build(BuildContext context) {
    final palette = appThemePalette;
    final headingStyle = TextStyle(
      color: palette.textPrimary,
      fontSize: 25,
      fontWeight: FontWeight.w900,
      letterSpacing: themeLetterSpacing(palette),
      shadows: palette.id == AppThemeId.tienMonPremium
          ? tienMonTextShadows
          : null,
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Expanded(
          child: Row(
            children: <Widget>[
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    themedHeading(title, palette),
                    maxLines: 1,
                    softWrap: false,
                    style: headingStyle,
                  ),
                ),
              ),
              if (badge != null) ...<Widget>[
                const SizedBox(width: 9),
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: palette.cardAlt,
                      borderRadius: BorderRadius.circular(
                        palette.geometry == AppThemeGeometry.rounded ? 999 : 0,
                      ),
                      border: Border.all(color: palette.border),
                    ),
                    child: Text(
                      badge!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.primary,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 6),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (onNotificationTap != null)
              IconButton(
                tooltip: hasActiveExamPeriod
                    ? 'Đang trong kỳ thi'
                    : 'Thông báo thay đổi lịch',
                onPressed: onNotificationTap,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                icon: Stack(
                  clipBehavior: Clip.none,
                  children: <Widget>[
                    Icon(
                      Icons.notifications_none_rounded,
                      color: palette.primary,
                    ),
                    if (unreadDifference || hasActiveExamPeriod)
                      Positioned(
                        right: -2,
                        bottom: -2,
                        child: _ExamAlertDot(background: palette.surface),
                      ),
                  ],
                ),
              ),
            if (onCalendarTap == null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Icon(
                  Icons.calendar_month_outlined,
                  color: palette.primary,
                ),
              )
            else
              IconButton.filledTonal(
                tooltip: 'Chọn ngày',
                onPressed: onCalendarTap,
                style: IconButton.styleFrom(
                  foregroundColor: palette.primary,
                  backgroundColor: palette.id == AppThemeId.tienMonPremium
                      ? Colors.transparent
                      : palette.cardAlt,
                  side: palette.id == AppThemeId.tienMonPremium
                      ? const BorderSide(color: Color(0xCCFFD66B))
                      : null,
                  shape: themeButtonShape(palette),
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                icon: const Icon(Icons.calendar_month_outlined),
              ),
          ],
        ),
      ],
    );
  }
}

class _TimetableModeSelector extends StatelessWidget {
  const _TimetableModeSelector({required this.weekly, required this.onChanged});

  final bool weekly;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = appThemePalette;
    final premium = palette.id == AppThemeId.tienMonPremium;
    final radius = premium ? 20.0 : palette.radius;

    return Container(
      height: 46,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: premium ? Colors.transparent : palette.cardAlt,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: premium ? const Color(0xCCFFD66B) : palette.border,
          width: premium ? 1.15 : 1,
        ),
        boxShadow: premium
            ? <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withValues(alpha: .24),
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: CustomPaint(
        painter: _TimetableModeSelectorPainter(
          weekly: weekly,
          premium: premium,
          primary: palette.primary,
          radius: radius - 3,
        ),
        child: Row(
          children: <Widget>[
            for (final value in <bool>[false, true])
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(radius - 3),
                  onTap: () => onChanged(value),
                  child: Center(
                    child: Text(
                      value ? 'Theo tuần' : 'Theo ngày',
                      style: TextStyle(
                        color: premium
                            ? const Color(0xFFFFD66B)
                            : weekly == value
                            ? Colors.white
                            : palette.textPrimary,
                        fontWeight: FontWeight.w900,
                        shadows: premium ? tienMonTextShadows : null,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TimetableModeSelectorPainter extends CustomPainter {
  const _TimetableModeSelectorPainter({
    required this.weekly,
    required this.premium,
    required this.primary,
    required this.radius,
  });

  final bool weekly;
  final bool premium;
  final Color primary;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final half = size.width / 2;
    final rect = Rect.fromLTWH(weekly ? half : 0, 0, half, size.height);
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));

    final fill = Paint()
      ..color = premium ? const Color(0x22FFD66B) : primary;
    canvas.drawRRect(rrect, fill);

    if (premium) {
      final stroke = Paint()
        ..color = const Color(0xFFFFD66B)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1;
      canvas.drawRRect(rrect.deflate(.5), stroke);
    }
  }

  @override
  bool shouldRepaint(covariant _TimetableModeSelectorPainter oldDelegate) =>
      oldDelegate.weekly != weekly ||
      oldDelegate.premium != premium ||
      oldDelegate.primary != primary ||
      oldDelegate.radius != radius;
}

class _DateNavigator extends StatelessWidget {
  const new({
    required this.date,
    required this.onTap,
    required this.onPrevious,
    required this.onNext,
  });

  final DateTime date;
  final VoidCallback onTap;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final palette = appThemePalette;
    final premium = palette.id == AppThemeId.tienMonPremium;
    final row = Row(
      children: <Widget>[
        IconButton(
          onPressed: onPrevious,
          icon: Icon(
            Icons.chevron_left_rounded,
            color: palette.textSecondary,
            shadows: premium ? tienMonTextShadows : null,
          ),
        ),
        Expanded(
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(
              palette.geometry == AppThemeGeometry.rounded ? 18 : 0,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Flexible(
                    child: Text(
                      _dateLabel(date),
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontWeight: FontWeight.w800,
                        shadows: premium ? tienMonTextShadows : null,
                      ),
                    ),
                  ),
                  const SizedBox(width: 7),
                  Icon(
                    Icons.expand_more_rounded,
                    size: 18,
                    color: palette.textSecondary,
                    shadows: premium ? tienMonTextShadows : null,
                  ),
                ],
              ),
            ),
          ),
        ),
        IconButton(
          onPressed: onNext,
          icon: Icon(
            Icons.chevron_right_rounded,
            color: palette.textSecondary,
            shadows: premium ? tienMonTextShadows : null,
          ),
        ),
      ],
    );
    if (!premium) return row;
    return TienMonEdgeSurface(
      compact: true,
      scene: TienMonPremiumContract.appSceneFor(DateTime.now()),
      child: row,
    );
  }
}

double _calendarBottomReserve(BuildContext context) {
  final view = View.of(context);
  final viewBottom = view.padding.bottom / view.devicePixelRatio;
  final mediaBottom = MediaQuery.viewPaddingOf(context).bottom;
  final keyboardBottom = MediaQuery.viewInsetsOf(context).bottom;
  var systemBottom = viewBottom;
  if (mediaBottom > systemBottom) systemBottom = mediaBottom;
  if (keyboardBottom > systemBottom) systemBottom = keyboardBottom;

  // Some edge-to-edge Android builds report a consumed/zero navigation inset
  // to modal routes. Keep a visible physical reserve even in that case.
  final minimumReserve = MediaQuery.sizeOf(context).height * .12;
  final resolved = systemBottom + 18;
  return resolved > minimumReserve ? resolved : minimumReserve;
}

Future<void> _showCalendarPicker(
  BuildContext context,
  DateTime selectedDate,
  ValueChanged<DateTime> onDateChanged,
) async {
  var draft = _dateOnly(selectedDate);
  final palette = appThemePalette;
  final picked = await showGeneralDialog<DateTime>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Đóng lịch chọn ngày',
    barrierColor: Colors.black.withValues(alpha: .48),
    transitionDuration: const Duration(milliseconds: 190),
    transitionBuilder: (context, animation, secondaryAnimation, child) =>
        FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          ),
          child: child,
        ),
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      final screenHeight = MediaQuery.sizeOf(dialogContext).height;
      final bottomReserve = _calendarBottomReserve(dialogContext);
      final maxSheetHeight = screenHeight - bottomReserve - 24;
      final wantedHeight = screenHeight * .68;
      final sheetHeight = wantedHeight < maxSheetHeight
          ? wantedHeight
          : maxSheetHeight;

      return Material(
        color: Colors.transparent,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: EdgeInsets.only(bottom: bottomReserve),
            child: StatefulBuilder(
              builder: (dialogContext, setModalState) => Container(
                height: sheetHeight,
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 14),
                decoration: BoxDecoration(
                  color: palette.surface,
                  border: Border(top: BorderSide(color: palette.border)),
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(
                      palette.geometry == AppThemeGeometry.rounded ? 30 : 0,
                    ),
                  ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: palette.shadow,
                      blurRadius: 28,
                      offset: const Offset(0, -6),
                    ),
                  ],
                ),
                child: Column(
                  children: <Widget>[
                    Container(
                      width: 42,
                      height: 5,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: palette.textSecondary.withValues(alpha: .35),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            'Chọn ngày xem lịch',
                            style: TextStyle(
                              color: palette.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () => setModalState(
                            () => draft = _dateOnly(DateTime.now()),
                          ),
                          child: const Text('Hôm nay'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const ClampingScrollPhysics(),
                        child: Theme(
                          data: buildBetterTheme(palette),
                          child: CalendarDatePicker(
                            initialDate: draft,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2035, 12, 31),
                            onDateChanged: (value) => setModalState(
                              () => draft = _dateOnly(value),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton.icon(
                        onPressed: () =>
                            Navigator.of(dialogContext).pop(draft),
                        icon: const Icon(Icons.check_rounded),
                        label: Text('Xem ${_dateLabel(draft)}'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
  if (picked != null) onDateChanged(_dateOnly(picked));
}

class _ScheduleCard extends StatelessWidget {
  const new({required this.item, required this.accent});

  final ScheduleRecord item;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final palette = appThemePalette;
    final premium = palette.id == AppThemeId.tienMonPremium;
    final now = DateTime.now();
    final active = !now.isBefore(item.startAt) && now.isBefore(item.endAt);
    final barColor = premium
        ? const Color(0xFFFFD66B)
        : palette.id == AppThemeId.classic
        ? accent
        : palette.primary;
    final content = Row(
      children: <Widget>[
        Container(
          width: palette.geometry == AppThemeGeometry.pixel ? 6 : 4,
          color: barColor,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            _time(item.startAt),
            style: TextStyle(
              color: palette.primary,
              fontWeight: FontWeight.w900,
              fontSize: 17,
              shadows: premium ? tienMonTextShadows : null,
            ),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 14, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text(
                  item.subjectName,
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    shadows: premium ? tienMonTextShadows : null,
                  ),
                ),
                if (item.room.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 8),
                  _MetaLine(icon: Icons.location_on_outlined, text: item.room),
                ],
                const SizedBox(height: 5),
                _MetaLine(
                  icon: Icons.access_time_rounded,
                  text: '${_time(item.startAt)} - ${_time(item.endAt)}',
                ),
                if (item.periodStart != null &&
                    item.periodEnd != null) ...<Widget>[
                  const SizedBox(height: 5),
                  _MetaLine(
                    icon: Icons.menu_book_outlined,
                    text: 'Tiết ${item.periodStart} - ${item.periodEnd}',
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
    if (premium) {
      return ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 106),
        child: TienMonEdgeSurface(
          active: active,
          scene: TienMonPremiumContract.appSceneFor(now),
          child: content,
        ),
      );
    }
    return AppThemePanel(
      constraints: const BoxConstraints(minHeight: 106),
      child: content,
    );
  }
}

class _ExamCard extends StatelessWidget {
  const new({required this.item});

  final ScheduleRecord item;

  @override
  Widget build(BuildContext context) {
    final palette = appThemePalette;
    final premium = palette.id == AppThemeId.tienMonPremium;
    final countdown = ExamPeriod.countdown(item, DateTime.now());
    final content = Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: <Widget>[
          Container(
            width: 58,
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: premium ? Colors.transparent : palette.cardAlt,
              border: Border.all(
                color: premium ? const Color(0xFFFFD66B) : palette.border,
                width: premium ? 1.1 : 1,
              ),
              borderRadius: BorderRadius.circular(
                palette.geometry == AppThemeGeometry.rounded ? 10 : 0,
              ),
            ),
            child: Column(
              children: <Widget>[
                Text(
                  item.startAt.day.toString().padLeft(2, '0'),
                  style: TextStyle(
                    color: palette.primary,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    shadows: premium ? tienMonTextShadows : null,
                  ),
                ),
                Text(
                  'THG ${item.startAt.month}',
                  style: TextStyle(
                    color: palette.textSecondary,
                    fontSize: 10,
                    shadows: premium ? tienMonTextShadows : null,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  item.subjectName,
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontWeight: FontWeight.w900,
                    shadows: premium ? tienMonTextShadows : null,
                  ),
                ),
                if (item.examForm.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 4),
                  Text(
                    item.examForm,
                    style: TextStyle(
                      color: premium ? const Color(0xFFFFD66B) : palette.accent,
                      fontSize: 11,
                      shadows: premium ? tienMonTextShadows : null,
                    ),
                  ),
                ],
                if (countdown != null) ...<Widget>[
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: _ExamCountdownTag(countdown: countdown),
                  ),
                ],
                const SizedBox(height: 7),
                _MetaLine(
                  icon: Icons.access_time_rounded,
                  text: '${_time(item.startAt)} - ${_time(item.endAt)}',
                ),
                if (item.room.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 4),
                  _MetaLine(icon: Icons.location_on_outlined, text: item.room),
                ],
              ],
            ),
          ),
        ],
      ),
    );
    if (premium) {
      return TienMonEdgeSurface(
        scene: TienMonPremiumContract.appSceneFor(DateTime.now()),
        child: content,
      );
    }
    return AppThemePanel(child: content);
  }
}

class _ExamCountdownTag extends StatelessWidget {
  const new({required this.countdown});

  final ExamCountdown countdown;

  @override
  Widget build(BuildContext context) {
    final palette = appThemePalette;
    final (dark, light) = switch (countdown.band) {
      ExamCountdownBand.green => (
        const Color(0xFF155724),
        const Color(0xFF9CE5A8),
      ),
      ExamCountdownBand.blue => (
        const Color(0xFF0B4A91),
        const Color(0xFF9AD1FF),
      ),
      ExamCountdownBand.orange => (
        const Color(0xFF8D4100),
        const Color(0xFFFFC078),
      ),
      ExamCountdownBand.red => (
        const Color(0xFFAA1730),
        const Color(0xFFFFA3A9),
      ),
    };
    final background = Color.alphaBlend(
      (palette.card.computeLuminance() > .4 ? dark : light).withValues(
        alpha: .13,
      ),
      palette.card,
    );
    final foreground =
        _contrastRatio(dark, background) >= _contrastRatio(light, background)
        ? dark
        : light;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        border: Border.all(color: foreground.withValues(alpha: .65)),
        borderRadius: BorderRadius.circular(
          palette.geometry == AppThemeGeometry.rounded ? 999 : 0,
        ),
      ),
      child: Text(
        countdown.label,
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: foreground,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

double _contrastRatio(Color a, Color b) {
  final light = a.computeLuminance() > b.computeLuminance()
      ? a.computeLuminance()
      : b.computeLuminance();
  final dark = a.computeLuminance() < b.computeLuminance()
      ? a.computeLuminance()
      : b.computeLuminance();
  return (light + .05) / (dark + .05);
}

class _ExamAlertDot extends StatelessWidget {
  const new({required this.background});

  final Color background;

  @override
  Widget build(BuildContext context) {
    final color = background.computeLuminance() > .4
        ? const Color(0xFFB51C41)
        : const Color(0xFFFF7490);
    return Semantics(
      label: 'Đang trong kỳ thi',
      child: Container(
        key: const ValueKey<String>('exam-period-dot'),
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: background, width: 2),
        ),
      ),
    );
  }
}

class _SegmentTabs extends StatelessWidget {
  const new({required this.showPast, required this.onChanged});

  final bool showPast;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = appThemePalette;
    return Container(
      height: 43,
      decoration: BoxDecoration(
        color: palette.cardAlt,
        border: Border.all(color: palette.border),
        borderRadius: BorderRadius.circular(
          palette.geometry == AppThemeGeometry.rounded ? 11 : 0,
        ),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: _TabButton(
              label: 'Sắp tới',
              selected: !showPast,
              onTap: () => onChanged(false),
            ),
          ),
          Expanded(
            child: _TabButton(
              label: 'Đã qua',
              selected: showPast,
              onTap: () => onChanged(true),
            ),
          ),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const new({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = appThemePalette;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(
        palette.geometry == AppThemeGeometry.rounded ? 10 : 0,
      ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        alignment: Alignment.center,
        margin: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: selected ? palette.card : Colors.transparent,
          borderRadius: BorderRadius.circular(
            palette.geometry == AppThemeGeometry.rounded ? 9 : 0,
          ),
          border: selected
              ? Border.all(color: palette.primary.withValues(alpha: .45))
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? palette.primary : palette.textSecondary,
            fontWeight: selected ? FontWeight.w900 : FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _InfoPanel extends StatelessWidget {
  const new({required this.data});

  final ImportedScheduleData data;

  @override
  Widget build(BuildContext context) {
    final palette = appThemePalette;
    return AppThemePanel(
      width: double.infinity,
      elevated: false,
      alt: true,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Dữ liệu trên thiết bị',
            style: TextStyle(
              color: palette.textPrimary,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          _AccountInfoRow(
            label: 'Lịch học',
            value: '${data.classes.length} mục',
          ),
          const SizedBox(height: 8),
          _AccountInfoRow(label: 'Lịch thi', value: '${data.exams.length} mục'),
          const SizedBox(height: 8),
          _AccountInfoRow(
            label: 'Cập nhật lần cuối',
            value: '${_dateShort(data.syncedAt)} ${_time(data.syncedAt)}',
          ),
          const SizedBox(height: 8),
          const _AccountInfoRow(label: 'Nguồn', value: 'QLĐT Phenikaa'),
          const SizedBox(height: 14),
          Divider(color: palette.border, height: 1),
          const SizedBox(height: 12),
          Text(
            palette.id == AppThemeId.tienMonPremium
                ? 'Better Phenikaa vốn là ngoại môn tiểu giới do môn sinh '
                      'Phenikaa tự khai, tự vận hành ngoài mắt Thiên Đạo; '
                      'chưa từng thụ chính mạch sắc phong, mọi pháp chỉ nơi '
                      'đây đều không thể coi là ý chỉ của tông môn.'
                : 'Better Phenikaa là dự án độc lập do sinh viên phát triển, '
                      'không phải ứng dụng chính thức và không đại diện cho '
                      'Trường Đại học Phenikaa.',
            style: TextStyle(
              color: palette.textSecondary,
              fontSize: 11,
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountInfoRow extends StatelessWidget {
  const new({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final palette = appThemePalette;
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            label,
            style: TextStyle(color: palette.textSecondary, fontSize: 12),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: palette.textPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _WidgetPreview extends StatelessWidget {
  const new({required this.item});

  final ScheduleRecord item;

  @override
  Widget build(BuildContext context) {
    final palette = appThemePalette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Widget 1×4',
          style: TextStyle(
            color: palette.textPrimary,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        ClipPath(
          clipper: palette.geometry == AppThemeGeometry.valorant
              ? const _WidgetValorantClipper()
              : palette.geometry == AppThemeGeometry.lol
              ? const _WidgetLolClipper()
              : null,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: <Color>[palette.widgetStart, palette.widgetEnd],
              ),
              borderRadius: BorderRadius.circular(
                palette.geometry == AppThemeGeometry.rounded ? 18 : 0,
              ),
              border: Border.all(color: palette.border.withValues(alpha: .8)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  item.subjectName,
                  style: TextStyle(
                    color: palette.widgetText,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 7),
                Row(
                  children: <Widget>[
                    Icon(
                      Icons.location_on_outlined,
                      color: palette.widgetSubtext,
                      size: 15,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      item.room,
                      style: TextStyle(
                        color: palette.widgetSubtext,
                        fontSize: 12,
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      Icons.access_time_rounded,
                      color: palette.widgetSubtext,
                      size: 15,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '${_time(item.startAt)} - ${_time(item.endAt)}',
                      style: TextStyle(
                        color: palette.widgetSubtext,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _OverviewWidgetPreview extends StatelessWidget {
  const new({required this.data, this.date});

  final ImportedScheduleData data;
  final DateTime? date;

  @override
  Widget build(BuildContext context) {
    final palette = appThemePalette;
    final selected = date ?? DateTime.now();
    final subjects =
        data.classes
            .where(
              (item) =>
                  item.startAt.year == selected.year &&
                  item.startAt.month == selected.month &&
                  item.startAt.day == selected.day,
            )
            .toList()
          ..sort((a, b) => a.startAt.compareTo(b.startAt));
    final visible = subjects.take(4).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Widget 4×2',
          style: TextStyle(
            color: palette.textPrimary,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        ClipPath(
          clipper: palette.geometry == AppThemeGeometry.valorant
              ? const _WidgetValorantClipper()
              : palette.geometry == AppThemeGeometry.lol
              ? const _WidgetLolClipper()
              : null,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: <Color>[palette.widgetStart, palette.widgetEnd],
              ),
              borderRadius: BorderRadius.circular(
                palette.geometry == AppThemeGeometry.rounded ? 18 : 0,
              ),
              border: Border.all(color: palette.border.withValues(alpha: .8)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Icon(
                      Icons.school_outlined,
                      size: 18,
                      color: palette.widgetText,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Ngày ${selected.day}/${selected.month} · ${subjects.length} môn học',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: palette.widgetText,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    for (final icon in <IconData>[
                      Icons.calendar_month_outlined,
                      Icons.sync_rounded,
                      Icons.notifications_none_rounded,
                    ]) ...<Widget>[
                      const SizedBox(width: 5),
                      Icon(icon, size: 15, color: palette.widgetText),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 66,
                  child: visible.isEmpty
                      ? Center(
                          child: Text(
                            'Không có lịch học',
                            style: TextStyle(color: palette.widgetText),
                          ),
                        )
                      : Row(
                          children: <Widget>[
                            for (var index = 0; index < 4; index++) ...<Widget>[
                              if (index > 0) const SizedBox(width: 4),
                              Expanded(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: palette.card.withValues(alpha: .22),
                                    border: Border.all(
                                      color: palette.widgetText.withValues(
                                        alpha: .3,
                                      ),
                                    ),
                                    borderRadius: BorderRadius.circular(
                                      palette.geometry ==
                                              AppThemeGeometry.rounded
                                          ? 8
                                          : 0,
                                    ),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(4),
                                    child: index >= visible.length
                                        ? const SizedBox.expand()
                                        : Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: <Widget>[
                                              Text(
                                                _time(visible[index].startAt),
                                                maxLines: 1,
                                                style: TextStyle(
                                                  color: palette.widgetText,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                              const SizedBox(height: 3),
                                              Expanded(
                                                child: Text(
                                                  visible[index].subjectName,
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    color: palette.widgetText,
                                                    fontSize: 9,
                                                    height: 1.1,
                                                  ),
                                                ),
                                              ),
                                              Text(
                                                visible[index].room,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  color: palette.widgetSubtext,
                                                  fontSize: 9,
                                                ),
                                              ),
                                            ],
                                          ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: <Widget>[
                    Icon(
                      Icons.chevron_left,
                      size: 15,
                      color: palette.widgetText,
                    ),
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: <Widget>[
                          for (var index = 0; index < visible.length; index++)
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: index == 0
                                    ? palette.primary
                                    : palette.widgetSubtext,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      size: 15,
                      color: palette.widgetText,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _WidgetValorantClipper extends CustomClipper<Path> {
  const new();
  @override
  Path getClip(Size size) => Path()
    ..moveTo(12, 0)
    ..lineTo(size.width, 0)
    ..lineTo(size.width, size.height - 12)
    ..lineTo(size.width - 12, size.height)
    ..lineTo(0, size.height)
    ..lineTo(0, 12)
    ..close();
  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _WidgetLolClipper extends CustomClipper<Path> {
  const new();
  @override
  Path getClip(Size size) => Path()
    ..moveTo(10, 0)
    ..lineTo(size.width - 10, 0)
    ..lineTo(size.width, 10)
    ..lineTo(size.width, size.height - 10)
    ..lineTo(size.width - 10, size.height)
    ..lineTo(10, size.height)
    ..lineTo(0, size.height - 10)
    ..lineTo(0, 10)
    ..close();
  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _ControlPanel extends StatelessWidget {
  const new({
    required this.page,
    required this.hasActiveExamPeriod,
    required this.onOpenPage,
    required this.onSync,
  });

  final _AppPage page;
  final bool hasActiveExamPeriod;
  final ValueChanged<_AppPage> onOpenPage;
  final VoidCallback onSync;

  @override
  Widget build(BuildContext context) {
    final palette = appThemePalette;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      builder: (context, progress, child) {
        return SizedBox(
          width: 300,
          height: 344,
          child: Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              _ArcPanelAction(
                progress: progress,
                start: 0,
                right: 4,
                bottom: 254,
                originOffset: const Offset(20, 78),
                child: _PanelAction(
                  label: 'Lịch học',
                  icon: Icons.event_available_rounded,
                  color: palette.primary,
                  selected: page == _AppPage.timetable,
                  onTap: () => onOpenPage(_AppPage.timetable),
                ),
              ),
              _ArcPanelAction(
                progress: progress,
                start: .08,
                right: 42,
                bottom: 196,
                originOffset: const Offset(34, 62),
                child: _PanelAction(
                  label: 'Lịch thi',
                  icon: Icons.assignment_rounded,
                  color: _panelSecondaryColor(palette),
                  selected: page == _AppPage.exam,
                  showAlertDot: hasActiveExamPeriod,
                  onTap: () => onOpenPage(_AppPage.exam),
                ),
              ),
              _ArcPanelAction(
                progress: progress,
                start: .16,
                right: 72,
                bottom: 138,
                originOffset: const Offset(46, 46),
                child: _PanelAction(
                  label: 'Đồng bộ',
                  icon: Icons.sync_rounded,
                  color: const Color(0xFFFFA51E),
                  selected: false,
                  onTap: onSync,
                ),
              ),
              _ArcPanelAction(
                progress: progress,
                start: .24,
                right: 92,
                bottom: 80,
                originOffset: const Offset(54, 30),
                child: _PanelAction(
                  label: 'Tài khoản',
                  icon: Icons.person_rounded,
                  color: palette.primary,
                  selected: page == _AppPage.account,
                  onTap: () => onOpenPage(_AppPage.account),
                ),
              ),
              _ArcPanelAction(
                progress: progress,
                start: .32,
                right: 100,
                bottom: 20,
                originOffset: const Offset(58, 20),
                child: _PanelAction(
                  label: 'Giao diện',
                  icon: Icons.palette_outlined,
                  color: _panelTertiaryColor(palette),
                  selected: false,
                  onTap: () => showAppThemePicker(context),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ArcPanelAction extends StatelessWidget {
  const new({
    required this.progress,
    required this.start,
    required this.right,
    required this.bottom,
    required this.originOffset,
    required this.child,
  });

  final double progress;
  final double start;
  final double right;
  final double bottom;
  final Offset originOffset;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = ((progress - start) / (1 - start)).clamp(0.0, 1.0);
    final curved = Curves.easeOutBack.transform(t);
    return Positioned(
      right: right,
      bottom: bottom,
      child: IgnorePointer(
        ignoring: t < .55,
        child: Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset.lerp(originOffset, Offset.zero, curved)!,
            child: Transform.scale(
              alignment: Alignment.centerRight,
              scale: .72 + (.28 * curved),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

class _PanelAction extends StatelessWidget {
  const new({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
    this.showAlertDot = false,
  });

  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final bool showAlertDot;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = appThemePalette;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: AppThemePanel(
          elevated: true,
          padding: const EdgeInsets.fromLTRB(18, 5, 5, 5),
          child: SizedBox(
            height: 40,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  label,
                  style: TextStyle(
                    color: selected ? palette.primary : palette.textPrimary,
                    fontWeight: FontWeight.w800,
                    letterSpacing: themeLetterSpacing(palette),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 40,
                  height: 40,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: <Widget>[
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: color,
                        child: Icon(
                          icon,
                          color: _contrastForeground(color),
                          size: 20,
                        ),
                      ),
                      if (showAlertDot)
                        Positioned(
                          right: -3,
                          bottom: -3,
                          child: _ExamAlertDot(background: palette.surface),
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

Color _panelSecondaryColor(AppThemePalette palette) => switch (palette.id) {
  AppThemeId.classic => const Color(0xFF6A7CEB),
  AppThemeId.lol => const Color(0xFFC89B3C),
  AppThemeId.valorant => const Color(0xFF56D6C7),
  AppThemeId.minecraft => const Color(0xFF42A5F5),
  AppThemeId.facebook => const Color(0xFF42B72A),
  AppThemeId.shopee => const Color(0xFF0EA5E9),
  AppThemeId.tiktok => const Color(0xFF25F4EE),
  AppThemeId.ben10 => const Color(0xFF00AEEF),
  AppThemeId.youtube => const Color(0xFF3EA6FF),
  AppThemeId.steam => const Color(0xFFA4D007),
  AppThemeId.tienMonPremium => const Color(0xFF74D8B1),
  AppThemeId.custom => palette.primary,
};

Color _panelTertiaryColor(AppThemePalette palette) => switch (palette.id) {
  AppThemeId.classic => const Color(0xFF8B5CF6),
  AppThemeId.lol => const Color(0xFF7E72C6),
  AppThemeId.valorant => const Color(0xFFC084FC),
  AppThemeId.minecraft => const Color(0xFFFFCA28),
  AppThemeId.facebook => const Color(0xFFA033FF),
  AppThemeId.shopee => const Color(0xFF8B5CF6),
  AppThemeId.tiktok => const Color(0xFFB06CFF),
  AppThemeId.ben10 => const Color(0xFFC5FF35),
  AppThemeId.youtube => const Color(0xFF8B5CF6),
  AppThemeId.steam => const Color(0xFF66C0F4),
  AppThemeId.tienMonPremium => const Color(0xFFFFD66B),
  AppThemeId.custom => palette.accent,
};

Color _contrastForeground(Color background) =>
    background.computeLuminance() > .48
    ? const Color(0xFF101418)
    : Colors.white;

class _MetaLine extends StatelessWidget {
  const new({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final palette = appThemePalette;
    return Row(
      children: <Widget>[
        Icon(
          icon,
          size: 15,
          color: palette.textSecondary,
          shadows: palette.id == AppThemeId.tienMonPremium
              ? tienMonTextShadows
              : null,
        ),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: palette.textSecondary, fontSize: 12),
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const new({required this.icon, required this.title, required this.message});

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final palette = appThemePalette;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 52, color: palette.primary.withValues(alpha: .6)),
            const SizedBox(height: 14),
            Text(
              title,
              style: TextStyle(
                color: palette.textPrimary,
                fontWeight: FontWeight.w900,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: palette.textSecondary,
                height: 1.45,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const new({required this.message, required this.onDismiss});

  final String message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 5,
      borderRadius: BorderRadius.circular(12),
      color: const Color(0xFFFFF0F0),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
        child: Row(
          children: <Widget>[
            const Icon(Icons.error_outline, color: Color(0xFFC63C3C), size: 20),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Color(0xFF8B2F2F), fontSize: 12),
              ),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: onDismiss,
              icon: const Icon(Icons.close, size: 18),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhoneSurface extends StatelessWidget {
  const new({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = appThemePalette;
    return ColoredBox(
      color: palette.id == AppThemeId.tienMonPremium
          ? Colors.transparent
          : palette.surface.withValues(alpha: palette.dark ? .94 : .985),
      child: SizedBox.expand(child: child),
    );
  }
}

class _AppMark extends StatelessWidget {
  const new({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    final palette = appThemePalette;
    final square = palette.geometry != AppThemeGeometry.rounded;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: palette.card.withValues(alpha: .35),
        borderRadius: BorderRadius.circular(square ? 0 : size * .2),
        border: Border.all(
          color: palette.primary,
          width: palette.geometry == AppThemeGeometry.pixel
              ? size * .07
              : size * .08,
        ),
        boxShadow: palette.geometry == AppThemeGeometry.pixel
            ? <BoxShadow>[
                BoxShadow(
                  color: palette.shadow,
                  offset: Offset(size * .06, size * .06),
                ),
              ]
            : null,
      ),
      child: Icon(
        AppThemeController.instance.theme.icon,
        size: size * .58,
        color: palette.primary,
      ),
    );
  }
}

class _MicrosoftMark extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    return const SizedBox.square(
      dimension: 25,
      child: Wrap(
        spacing: 2,
        runSpacing: 2,
        children: <Widget>[
          _MsTile(Color(0xFFF25022)),
          _MsTile(Color(0xFF7FBA00)),
          _MsTile(Color(0xFF00A4EF)),
          _MsTile(Color(0xFFFFB900)),
        ],
      ),
    );
  }
}

class _MsTile extends StatelessWidget {
  const new(this.color);

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(dimension: 11.5, child: ColoredBox(color: color));
  }
}

Color _accentFor(int index) {
  const accents = <Color>[
    Color(0xFF4A89FF),
    Color(0xFF32C489),
    Color(0xFFFF941A),
    Color(0xFF8154D9),
  ];
  return accents[index % accents.length];
}

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String _time(DateTime value) =>
    '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

String _dateShort(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';

String _dateLabel(DateTime value) {
  const weekdays = <String>[
    'Thứ Hai',
    'Thứ Ba',
    'Thứ Tư',
    'Thứ Năm',
    'Thứ Sáu',
    'Thứ Bảy',
    'Chủ Nhật',
  ];
  return '${weekdays[value.weekday - 1]}, ${value.day} tháng ${value.month}';
}
