import 'dart:async';
import 'dart:convert';

import 'package:better_phenikaa_schedule/features/app_update/update_manifest.dart';
import 'package:better_phenikaa_schedule/features/app_update/update_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum UpdatePhase {
  idle,
  checking,
  available,
  notAvailable,
  waitingForCard,
  wrongCard,
  authorized,
  downloading,
  verifying,
  permissionRequired,
  readyForInstaller,
  installerLaunched,
  installed,
  cancelled,
  failed,
}

final class UpdateNotice {
  const UpdateNotice(
    this.versionCode,
    this.versionName,
    this.notes,
    this.publishedAt,
  );
  final int versionCode;
  final String versionName;
  final String notes;
  final DateTime publishedAt;

  Map<String, Object> toJson() => {
    'versionCode': versionCode,
    'versionName': versionName,
    'notes': notes,
    'publishedAt': publishedAt.toIso8601String(),
  };

  static UpdateNotice? fromJson(Object? raw) {
    if (raw is! Map<String, dynamic>) return null;
    final version = raw['versionCode'];
    final name = raw['versionName'];
    final notes = raw['notes'];
    final date = raw['publishedAt'];
    if (version is! int ||
        name is! String ||
        notes is! String ||
        date is! String)
      return null;
    final parsed = DateTime.tryParse(date);
    return parsed == null ? null : UpdateNotice(version, name, notes, parsed);
  }
}

final class UpdateController extends ChangeNotifier {
  UpdateController({UpdateRepository? repository})
    : _repository = repository ?? UpdateRepository() {
    _channel.setMethodCallHandler(_onNativeEvent);
  }

  static const _noticeKey = 'app_update_notice_v1';
  static const _channel = MethodChannel('better_phenikaa/update');
  final UpdateRepository _repository;
  UpdatePhase phase = UpdatePhase.idle;
  UpdateNotice? notice;
  String? error;
  int downloaded = 0;
  int total = 0;
  bool hasBoundCard = false;
  bool bindingCard = false;
  bool _job = false;
  bool _awaitingPermission = false;
  bool get isRunningInBackground =>
      phase == UpdatePhase.authorized ||
      phase == UpdatePhase.downloading ||
      phase == UpdatePhase.verifying ||
      phase == UpdatePhase.readyForInstaller ||
      phase == UpdatePhase.installerLaunched;
  int _generation = 0;
  // Prevent a slower cache restore from overwriting a newer live check.
  int _checkRevision = 0;

  Future<int> _installedVersion() async =>
      await _channel.invokeMethod<int>('versionCode') ?? 0;

  Future<void> restore() async {
    final revision = _checkRevision;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_noticeKey);
      final cached = raw == null
          ? null
          : UpdateNotice.fromJson(jsonDecode(raw));
      final installed = await _installedVersion();
      final installStatus = await _channel.invokeMethod<String>('installStatus');
      // The launch check may start while native cache restoration is pending.
      // Its state is authoritative and must not be replaced by stale cache.
      if (revision != _checkRevision) return;
      if (cached != null && cached.versionCode > installed) {
        notice = cached;
        phase = UpdatePhase.available;
      } else {
        await prefs.remove(_noticeKey);
      }
      if (installStatus == 'installed') {
        phase = UpdatePhase.installed;
      }
      notifyListeners();
    } on Object {
      // A bad cache or unavailable native bridge cannot affect schedule data.
    }
  }

  Future<void> refreshCardBinding() async {
    try {
      hasBoundCard = await _channel.invokeMethod<bool>('hasBoundCard') ?? false;
      notifyListeners();
    } on Object {
      // NFC status does not affect schedule or update metadata.
    }
  }

  Future<void> startBindingCard() async {
    if (_job || bindingCard || hasBoundCard) return;
    bindingCard = true;
    error = null;
    notifyListeners();
    try {
      await _channel.invokeMethod<void>('startBindCard');
    } on PlatformException catch (e) {
      bindingCard = false;
      if (e.code == 'already_bound') await refreshCardBinding();
      error = e.code == 'nfc_unavailable'
          ? 'Hãy bật NFC để quét thẻ.'
          : 'Không bật được đầu đọc NFC. Hãy giữ màn hình này mở và thử lại.';
      notifyListeners();
    }
  }

  Future<bool> removeBoundCard() async {
    if (_job || isRunningInBackground) return false;
    try {
      await _channel.invokeMethod<void>('removeBoundCard');
      bindingCard = false;
      hasBoundCard = false;
      error = null;
      notifyListeners();
      return true;
    } on PlatformException catch (e) {
      error = e.message ?? 'Không xóa được liên kết thẻ. Hãy thử lại.';
      notifyListeners();
      return false;
    }
  }

  Future<void> stopBindingCard() async {
    bindingCard = false;
    notifyListeners();
    // The sheet also closes after a successful binding. Keep reader mode until
    // then so a card still touching the phone does not open another app.
    await _channel.invokeMethod<void>('stopCard');
  }

  /// Version metadata is checked only from the Account update action.
  Future<void> checkQuietly({Duration? timeBudget}) async {
    if (_job ||
        isRunningInBackground ||
        bindingCard ||
        phase == UpdatePhase.checking ||
        phase == UpdatePhase.waitingForCard ||
        phase == UpdatePhase.wrongCard ||
        phase == UpdatePhase.permissionRequired)
      return;
    _checkRevision++;
    final startedAt = DateTime.now();
    final before = phase;
    if (notice == null) phase = UpdatePhase.checking;
    try {
      final manifest = timeBudget == null
          ? await _repository.fetch()
          : await _repository.fetch().timeout(timeBudget);
      final installed = await _installedVersion();
      final prefs = await SharedPreferences.getInstance();
      if (timeBudget != null &&
          DateTime.now().difference(startedAt) >= timeBudget) {
        throw TimeoutException('Startup latest check budget exhausted');
      }
      if (manifest.appliesTo(installed)) {
        notice = UpdateNotice(
          manifest.versionCode,
          manifest.versionName,
          manifest.notes,
          manifest.publishedAt,
        );
        await prefs.setString(_noticeKey, jsonEncode(notice!.toJson()));
        phase = UpdatePhase.available;
      } else {
        notice = null;
        await prefs.remove(_noticeKey);
        phase = UpdatePhase.notAvailable;
      }
      notifyListeners();
    } on Object {
      // Invalid/offline metadata does not clear a prior, signed notice.
      if (phase == UpdatePhase.checking) {
        phase = notice == null
            ? UpdatePhase.notAvailable
            : UpdatePhase.available;
        notifyListeners();
      } else {
        phase = before;
      }
    }
  }

  Future<void> startCard() async {
    if (_job ||
        isRunningInBackground ||
        notice == null ||
        phase == UpdatePhase.waitingForCard ||
        phase == UpdatePhase.wrongCard ||
        phase == UpdatePhase.downloading)
      return;
    phase = UpdatePhase.waitingForCard;
    error = null;
    notifyListeners();
    try {
      await _channel.invokeMethod<void>('startCard');
    } on PlatformException catch (e) {
      phase = UpdatePhase.failed;
      error = e.code == 'nfc_unavailable'
          ? 'Hãy bật NFC để quét thẻ.'
          : e.code == 'reader_unavailable'
          ? 'Không bật được đầu đọc NFC. Hãy giữ màn hình cập nhật mở và thử lại.'
          : 'Không mở được đầu đọc NFC.';
      notifyListeners();
    }
  }

  Future<void> startManualAfterHold() async {
    if (_job ||
        notice == null ||
        phase == UpdatePhase.waitingForCard ||
        phase == UpdatePhase.downloading)
      return;
    await _authorized();
  }

  Future<void> _onNativeEvent(MethodCall call) async {
    if (call.method != 'event' || call.arguments is! Map) return;
    final event = Map<Object?, Object?>.from(call.arguments as Map);
    switch (event['type']) {
      case 'cardBound':
        bindingCard = false;
        hasBoundCard = true;
        notifyListeners();
        break;
      case 'wrongCard':
        if (phase == UpdatePhase.waitingForCard ||
            phase == UpdatePhase.wrongCard) {
          phase = UpdatePhase.wrongCard;
          notifyListeners();
        }
        break;
      case 'cardAccepted':
        if (phase == UpdatePhase.waitingForCard ||
            phase == UpdatePhase.wrongCard) {
          await _authorized();
        }
        break;
      case 'cardError':
        bindingCard = false;
        phase = UpdatePhase.failed;
        error = 'Không lưu hoặc đọc được thẻ. Hãy thử lại.';
        notifyListeners();
        break;
      case 'downloading':
        downloaded = (event['bytes'] as num?)?.toInt() ?? 0;
        total = (event['total'] as num?)?.toInt() ?? 0;
        phase = UpdatePhase.downloading;
        notifyListeners();
        break;
      case 'verifying':
        phase = UpdatePhase.verifying;
        notifyListeners();
        break;
      case 'preparing':
        phase = UpdatePhase.readyForInstaller;
        notifyListeners();
        break;
      case 'installerLaunched':
        phase = UpdatePhase.installerLaunched;
        notifyListeners();
        break;
      case 'updateFailed':
        phase = UpdatePhase.failed;
        error = 'Không thể tải hoặc xác minh bản cập nhật. Hãy thử lại.';
        notifyListeners();
        break;
      case 'cancelled':
        phase = UpdatePhase.cancelled;
        notifyListeners();
        break;
    }
  }

  Future<void> _authorized() async {
    if (_job) return;
    _job = true;
    final generation = _generation;
    phase = UpdatePhase.authorized;
    error = null;
    notifyListeners();
    try {
      // Re-fetch and re-verify the exact signed bytes after user authorization.
      final manifest = await _repository.fetch();
      if (generation != _generation) return;
      final installed = await _installedVersion();
      if (generation != _generation) return;
      if (!manifest.appliesTo(installed) ||
          manifest.versionCode != notice?.versionCode) {
        throw const FormatException('No applicable signed update');
      }
      final canInstall = await _channel.invokeMethod<bool>('canInstall');
      if (generation != _generation) return;
      if (canInstall != true) {
        phase = UpdatePhase.permissionRequired;
        _awaitingPermission = true;
        notifyListeners();
        return;
      }
      await _download(manifest);
    } on PlatformException catch (e) {
      if (generation != _generation) return;
      phase = e.code == 'permission_required'
          ? UpdatePhase.permissionRequired
          : UpdatePhase.failed;
      error = e.code == 'permission_required'
          ? null
          : 'Không thể tải hoặc xác minh bản cập nhật.';
      notifyListeners();
    } on Object {
      if (generation != _generation) return;
      phase = UpdatePhase.failed;
      error = 'Không xác minh được thông tin cập nhật. Hãy thử lại.';
      notifyListeners();
    } finally {
      _job = false;
      try {
        await _channel.invokeMethod<void>('stopCard');
      } on Object {
        // NFC cleanup must not mask an update result.
      }
    }
  }

  Future<void> _download(UpdateManifest manifest) async {
    phase = UpdatePhase.downloading;
    downloaded = 0;
    total = manifest.apkSize;
    notifyListeners();
    await _channel.invokeMethod<void>('downloadAndInstall', {
      'url': manifest.apkUrl.toString(),
      'sha256': manifest.apkSha256,
      'size': manifest.apkSize,
      'versionCode': manifest.versionCode,
    });
    // The Android foreground service continues after this sheet closes.
    // It emits installerLaunched only when the verified package is committed.
  }

  Future<void> openInstallSettings() async {
    if (phase == UpdatePhase.permissionRequired && _awaitingPermission) {
      await _channel.invokeMethod<void>('installSettings');
    }
  }

  Future<void> onResumed() async {
    if (phase == UpdatePhase.installerLaunched) {
      final installed = await _installedVersion();
      final status = await _channel.invokeMethod<String>('installStatus');
      if (installed >= (notice?.versionCode ?? 0)) {
        phase = UpdatePhase.installed;
      } else if (status == 'failed') {
        phase = UpdatePhase.failed;
        error = 'Android chưa cài đặt bản cập nhật. Bạn có thể thử lại.';
      }
      notifyListeners();
    }
    if (!_awaitingPermission) return;
    _awaitingPermission = false;
    if (await _channel.invokeMethod<bool>('canInstall') == true) {
      await _authorized();
    } else {
      phase = UpdatePhase.cancelled;
      notifyListeners();
    }
  }

  Future<void> cancel() async {
    _generation++;
    bindingCard = false;
    _awaitingPermission = false;
    await _channel.invokeMethod<void>('cancel');
    phase = UpdatePhase.cancelled;
    notifyListeners();
  }

  @override
  void dispose() {
    unawaited(_channel.invokeMethod<void>('stopCard'));
    _channel.setMethodCallHandler(null);
    super.dispose();
  }
}
