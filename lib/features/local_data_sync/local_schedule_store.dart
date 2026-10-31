import 'dart:async';

import 'package:better_phenikaa_schedule/core/contracts/models.dart';
import 'package:better_phenikaa_schedule/core/contracts/repositories.dart';
import 'package:better_phenikaa_schedule/features/local_data_sync/local_codec.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalScheduleStore
    implements ScheduleRepository, ExamRepository, WidgetSnapshotRepository {
  LocalScheduleStore._(this._prefs, this._current);
  static const cacheKey = 'btl_schedule_cache_v1';
  static const snapshotKey = 'btl_widget_snapshot_v1';
  final SharedPreferences _prefs;
  QldtImportPayload? _current;
  final StreamController<void> _changed = StreamController<void>.broadcast();

  static Future<LocalScheduleStore> open() async {
    final prefs = await SharedPreferences.getInstance();
    QldtImportPayload? payload;
    final text = prefs.getString(cacheKey);
    if (text != null) {
      try {
        payload = LocalCacheCodec.decode(text);
      } on FormatException {
        /* Keep UI usable even with damaged cached JSON. */
      } on TypeError {
        /* Same. */
      }
    }
    return LocalScheduleStore._(prefs, payload);
  }

  QldtImportPayload? get current => _current;

  Future<void> replaceImport(QldtImportPayload payload) async {
    final encoded = LocalCacheCodec.encode(payload);
    LocalCacheCodec.decode(
      encoded,
    ); // Validate before touching persisted state.
    final ok = await _prefs.setString(cacheKey, encoded);
    if (!ok)
      throw StateError('Không ghi được cache; dữ liệu trước đó giữ nguyên');
    _current = payload;
    _changed.add(null);
  }

  @override
  Future<void> replaceFromImport(QldtImportPayload payload) =>
      replaceImport(payload);

  @override
  Stream<List<ClassDto>> watchRange({
    required DateTime from,
    required DateTime to,
  }) async* {
    List<ClassDto> result() =>
        (_current?.classes ?? const <ClassDto>[])
            .where((c) => !c.startAt.isBefore(from) && c.startAt.isBefore(to))
            .toList()
          ..sort((a, b) => a.startAt.compareTo(b.startAt));
    yield result();
    yield* _changed.stream.map((_) => result());
  }

  @override
  Stream<List<ExamDto>> watchAll() async* {
    List<ExamDto> result() =>
        List<ExamDto>.of(_current?.exams ?? const <ExamDto>[])
          ..sort((a, b) => a.startAt.compareTo(b.startAt));
    yield result();
    yield* _changed.stream.map((_) => result());
  }

  @override
  Future<void> clearAll() async {
    final ok = await _prefs.remove(cacheKey);
    if (!ok) throw StateError('Cannot clear schedule cache');
    _current = null;
    _changed.add(null);
  }

  @override
  Future<WidgetSnapshot?> read() async {
    final raw = _prefs.getString(snapshotKey);
    if (raw == null) return null;
    final segments = raw.split('\u001f');
    if (segments.length != 4) return null;
    final start = DateTime.tryParse(segments[2]);
    final end = DateTime.tryParse(segments[3]);
    if (start == null || end == null) return null;
    return WidgetSnapshot(
      subjectName: segments[0],
      room: segments[1],
      startAt: start,
      endAt: end,
    );
  }

  @override
  Future<void> write(WidgetSnapshot? snapshot) async {
    if (snapshot == null) {
      await clear();
      return;
    }
    final ok = await _prefs.setString(
      snapshotKey,
      [
        snapshot.subjectName,
        snapshot.room,
        snapshot.startAt.toIso8601String(),
        snapshot.endAt.toIso8601String(),
      ].join('\u001f'),
    );
    if (!ok) throw StateError('Cannot store widget snapshot');
  }

  @override
  Future<void> clear() async {
    await _prefs.remove(snapshotKey);
  }

  Future<void> dispose() => _changed.close();
}
