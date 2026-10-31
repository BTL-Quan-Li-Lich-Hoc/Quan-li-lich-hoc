import 'dart:convert';

import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/qldt_models.dart';
import 'package:better_phenikaa_schedule/features/dong_bo_hang_ngay/daily_sync.dart';
import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

/// Publishes the small, stable and local-only contract consumed by RemoteViews.
abstract final class WidgetPublisher {
  static const _storageKey = 'better_phenikaa_widget_snapshot_v1';
  static const _provider = 'ScheduleWidgetProvider';
  static const _qualifiedProvider =
      'vn.edu.phenikaa.better_phenikaa_schedule.ScheduleWidgetProvider';

  static Future<void> publish(
    ImportedScheduleData data, {
    required bool resetToToday,
  }) async {
    if (!_isSupported) return;
    final classes = data.classes.toList()
      ..sort((left, right) => left.startAt.compareTo(right.startAt));
    final snapshot = jsonEncode(<String, Object?>{
      'schemaVersion': 1,
      'generatedAt': data.syncedAt.toIso8601String(),
      'classes': classes
          .map(
            (item) => <String, Object?>{
              'id': item.id,
              'subjectName': item.subjectName,
              'room': item.room,
              'startAt': item.startAt.toIso8601String(),
              'endAt': item.endAt.toIso8601String(),
            },
          )
          .toList(growable: false),
      'exams':
          (data.exams.toList()
                ..sort((left, right) => left.startAt.compareTo(right.startAt)))
              .map(
                (item) => <String, Object?>{
                  'id': item.id,
                  'subjectName': item.subjectName,
                  'room': item.room,
                  'examForm': item.examForm,
                  'className': item.className,
                  'startAt': item.startAt.toIso8601String(),
                  'endAt': item.endAt.toIso8601String(),
                },
              )
              .toList(growable: false),
    });
    await HomeWidget.saveWidgetData<String>(_storageKey, snapshot);
    if (resetToToday) {
      await DailySync.refreshWidgetToday();
    } else {
      await _refresh();
    }
  }

  static Future<void> clear() async {
    if (!_isSupported) return;
    await HomeWidget.saveWidgetData<String>(_storageKey, null);
    await _refresh();
  }

  static Future<void> _refresh() => HomeWidget.updateWidget(
    name: _provider,
    qualifiedAndroidName: _qualifiedProvider,
  );

  static bool get _isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
}
