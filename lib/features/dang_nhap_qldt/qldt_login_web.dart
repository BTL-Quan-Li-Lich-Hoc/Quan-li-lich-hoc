// This file is selected only for Flutter Web and talks to the local Chrome
// bridge through browser DOM events; the mobile implementation never imports it.
// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:convert';
import 'dart:html' as html;

import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/qldt_login_result.dart';
import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/qldt_models.dart';
import 'package:flutter/material.dart';

const bool supportsLiveQldtLogin = true;

Future<void> clearQldtSession() async {}

Future<String> readCachedQldtDisplayName() async => '';

Future<String> readQldtAccountDisplayName() async => '';

Future<bool> isQldtFirstLoginSetupComplete() async => true;

Future<void> markQldtFirstLoginSetupComplete() async {}

Future<QldtLoginResult?> openQldtLogin(BuildContext context) {
  return showDialog<QldtLoginResult>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _WebQldtBridgeDialog(),
  );
}

class _WebQldtBridgeDialog extends StatefulWidget {
  const new();

  @override
  State<_WebQldtBridgeDialog> createState() => _WebQldtBridgeDialogState();
}

class _WebQldtBridgeDialogState extends State<_WebQldtBridgeDialog> {
  static const _startEvent = 'better-phenikaa-start-qldt-login';
  static const _cancelEvent = 'better-phenikaa-cancel-qldt-login';
  static const _resultEvent = 'better-phenikaa-qldt-result';
  static const _errorEvent = 'better-phenikaa-qldt-error';
  static const _bridgeReadyEvent = 'better-phenikaa-bridge-ready';

  bool _started = false;
  bool _syncing = false;
  bool _failed = false;
  String _status = 'Đang chuẩn bị kết nối QLĐT...';

  bool get _bridgeReady =>
      html.document.documentElement?.dataset['betterPhenikaaBridge'] == 'ready';

  @override
  void initState() {
    super.initState();
    html.window.addEventListener(_resultEvent, _onResult);
    html.window.addEventListener(_errorEvent, _onError);
    html.window.addEventListener(_bridgeReadyEvent, _onBridgeReady);
    WidgetsBinding.instance.addPostFrameCallback((_) => _startAutoLogin());
  }

  @override
  void dispose() {
    html.window.removeEventListener(_resultEvent, _onResult);
    html.window.removeEventListener(_errorEvent, _onError);
    html.window.removeEventListener(_bridgeReadyEvent, _onBridgeReady);
    super.dispose();
  }

  void _onBridgeReady(html.Event _) {
    if (!_started) {
      _startAutoLogin();
    }
  }

  void _startAutoLogin() {
    if (!mounted || _syncing) {
      return;
    }
    if (!_bridgeReady) {
      setState(() {
        _failed = true;
        _status = 'Chưa phát hiện Better Phenikaa Web Bridge. Hãy bật extension rồi tải lại trang.';
      });
      return;
    }

    final now = DateTime.now();
    final academicStartYear = now.month >= 8 ? now.year : now.year - 1;
    final start = DateTime(academicStartYear, 8);
    final end = DateTime(academicStartYear + 1, 7, 31);
    final payload = jsonEncode(<String, String>{
      'start': _formatDate(start),
      'end': _formatDate(end),
    });

    setState(() {
      _started = true;
      _syncing = true;
      _failed = false;
      _status = 'QLĐT đang được mở. Hãy đăng nhập Microsoft; sau khi lấy xong lịch, tab QLĐT sẽ tự đóng và app đăng nhập tự động.';
    });
    html.window.dispatchEvent(html.CustomEvent(_startEvent, detail: payload));
  }

  void _cancel() {
    html.window.dispatchEvent(html.CustomEvent(_cancelEvent));
    Navigator.of(context).pop();
  }

  void _onResult(html.Event event) {
    if (event is! html.CustomEvent) {
      return;
    }
    try {
      final raw = event.detail?.toString() ?? '';
      final response = jsonDecode(raw) as Map<String, dynamic>;
      final envelope = response['envelope'] as String? ?? '';
      if (envelope.isEmpty) {
        throw const FormatException('Web bridge returned an empty envelope.');
      }
      final data = const QldtParser().parseLiveEnvelope(envelope);
      if (mounted) {
        Navigator.of(context).pop(QldtLoginResult(schedule: data));
      }
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _syncing = false;
          _failed = true;
          _status = 'Không đọc được dữ liệu QLĐT: $error';
        });
      }
    }
  }

  void _onError(html.Event event) {
    if (event is! html.CustomEvent || !mounted) {
      return;
    }
    var message = 'Không thể kết nối QLĐT.';
    try {
      final raw = event.detail?.toString() ?? '';
      final response = jsonDecode(raw) as Map<String, dynamic>;
      message = response['message'] as String? ?? message;
    } on Object {
      // Keep the safe fallback message.
    }
    setState(() {
      _syncing = false;
      _failed = true;
      _status = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bridgeReady = _bridgeReady;
    return AlertDialog(
      title: const Row(
        children: <Widget>[
          Icon(Icons.verified_user_outlined, color: Color(0xFF1747B5)),
          SizedBox(width: 10),
          Expanded(child: Text('Đăng nhập QLĐT')),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: bridgeReady
                    ? const Color(0xFFEAF8F1)
                    : const Color(0xFFFFF5E7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: <Widget>[
                  Icon(
                    bridgeReady
                        ? Icons.check_circle_outline_rounded
                        : Icons.extension_off_outlined,
                    color: bridgeReady
                        ? const Color(0xFF16875B)
                        : const Color(0xFFB36B00),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      bridgeReady
                          ? 'Web Bridge đã bật · tự động đồng bộ sau đăng nhập'
                          : 'Chưa phát hiện Web Bridge',
                      style: const TextStyle(fontSize: 13, height: 1.35),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (_syncing) const LinearProgressIndicator(minHeight: 3),
            if (_syncing) const SizedBox(height: 14),
            Text(
              _status,
              style: TextStyle(
                color: _failed
                    ? const Color(0xFFB42318)
                    : const Color(0xFF4F628B),
                fontSize: 13,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(onPressed: _cancel, child: Text(_failed ? 'Đóng' : 'Hủy')),
        if (_failed)
          FilledButton.icon(
            onPressed: _startAutoLogin,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Thử lại'),
          ),
      ],
    );
  }
}

String _formatDate(DateTime value) {
  final day = value.day.toString().padLeft(2, '0');
  final month = value.month.toString().padLeft(2, '0');
  return '$day/$month/${value.year}';
}
