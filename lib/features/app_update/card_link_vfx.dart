import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// Local presentation only. Card UIDs and updater data never enter this view.
class CardLinkVfx extends StatefulWidget {
  const CardLinkVfx({
    required this.displayName,
    required this.status,
    required this.onComplete,
    this.deleting = false,
    this.onDeleteRequested,
    this.onHoldingChanged,
    super.key,
  });

  final String displayName;
  final String status;
  final bool deleting;
  final VoidCallback onComplete;
  final Future<bool> Function()? onDeleteRequested;
  final ValueChanged<bool>? onHoldingChanged;

  @override
  State<CardLinkVfx> createState() => _CardLinkVfxState();
}

class _CardLinkVfxState extends State<CardLinkVfx>
    with SingleTickerProviderStateMixin {
  late final Future<String> _html = rootBundle.loadString(
    'assets/card_vfx/link.html',
  );
  InAppWebViewController? _web;
  bool _ready = false;
  bool _visible = false;
  bool _holding = false;
  bool _busy = false;
  bool _finished = false;
  int _lastHoldFrame = 0;
  late final AnimationController _hold = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  )..addListener(_sendHoldFrame)
   ..addStatusListener(_holdStatus);

  void _sendHoldFrame() {
    if (!_ready || !widget.deleting || !_holding) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastHoldFrame < 30 && _hold.value < 1) return;
    _lastHoldFrame = now;
    unawaited(_web?.evaluateJavascript(
      source: 'window.paSetHold(${_hold.value});',
    ));
  }

  void _beginHold(PointerDownEvent event) {
    if (!widget.deleting || widget.onDeleteRequested == null ||
        !_ready || _busy || _finished || _holding || event.buttons != 1) return;
    _holding = true;
    widget.onHoldingChanged?.call(true);
    _hold.forward(from: 0);
  }

  void _cancelHold() {
    if (!_holding) return;
    _holding = false;
    widget.onHoldingChanged?.call(false);
    _hold.reset();
    unawaited(_web?.evaluateJavascript(source: 'window.paSetHold(0);'));
  }

  void _holdStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || !_holding || _busy) return;
    _holding = false;
    widget.onHoldingChanged?.call(false);
    unawaited(_confirmDelete());
  }

  Future<void> _confirmDelete() async {
    if (_busy || !mounted) return;
    setState(() => _busy = true);
    final removed = await widget.onDeleteRequested?.call() ?? false;
    if (!mounted) return;
    if (removed) {
      await _web?.evaluateJavascript(source: 'window.paStartDelete();');
    } else {
      _hold.reset();
      await _web?.evaluateJavascript(source: 'window.paSetHold(0);');
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _hold.dispose();
    super.dispose();
  }

  Future<void> _present() async {
    if (!_ready || !mounted) return;
    await _web?.evaluateJavascript(
      source: 'window.paSetState(${jsonEncode(widget.status)},'
          '${jsonEncode(widget.displayName)});',
    );
  }

  @override
  void didUpdateWidget(covariant CardLinkVfx oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.deleting != widget.deleting) {
      unawaited(_switchMode());
      return;
    }
    if (oldWidget.status != widget.status ||
        oldWidget.displayName != widget.displayName) {
      _present();
    }
  }

  Future<void> _switchMode() async {
    _holding = false;
    _busy = false;
    _finished = false;
    _hold.reset();
    if (!_ready || !mounted) return;
    await _web?.evaluateJavascript(
      source: '${widget.deleting && !_visible ? 'window.paCardPose={yaw:540,y:0};' : ''}'
          'window.paSetMode(${widget.deleting},'
          '${jsonEncode(widget.status)},${jsonEncode(widget.displayName)});',
    );
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 520,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: FutureBuilder<String>(
        future: _html,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const ColoredBox(color: Color(0xFF050913));
          }
          return Stack(
            children: <Widget>[
            const Positioned.fill(child: ColoredBox(color: Color(0xFF050913))),
            Positioned.fill(child: InAppWebView(
            initialData: InAppWebViewInitialData(data: snapshot.data!),
            initialSettings: InAppWebViewSettings(
              javaScriptEnabled: true,
              transparentBackground: true,
              textZoom: 100,
              underPageBackgroundColor: const Color(0xFF050913),
              forceDark: ForceDark.OFF,
              algorithmicDarkeningAllowed: false,
              hardwareAcceleration: true,
              // Render with the Flutter scene during sheet movement and teardown.
              useHybridComposition: false,
              disableHorizontalScroll: true,
              disableVerticalScroll: true,
            ),
            onWebViewCreated: (controller) {
              _web = controller;
              controller.addJavaScriptHandler(
                handlerName: 'vfxComplete',
                callback: (_) {
                  if (mounted) {
                    setState(() => _finished = true);
                    widget.onComplete();
                  }
                  return null;
                },
              );
            },
            onLoadStop: (_, _) async {
              _ready = true;
              await _switchMode();
              await Future<void>.delayed(const Duration(milliseconds: 80));
              if (mounted) setState(() => _visible = true);
            },
          )),
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedOpacity(
                opacity: _visible ? 0 : 1,
                duration: const Duration(milliseconds: 160),
                child: const ColoredBox(color: Color(0xFF050913)),
              ),
            ),
          ),
          if (widget.deleting && !_finished)
            Positioned(
              left: 0, right: 0, bottom: 16,
              child: Center(
                child: Semantics(
                  button: true,
                  label: 'Giữ 2 giây để xóa liên kết thẻ',
                  child: Listener(
                    behavior: HitTestBehavior.opaque,
                    onPointerDown: _beginHold,
                    onPointerUp: (_) => _cancelHold(),
                    onPointerCancel: (_) => _cancelHold(),
                    onPointerMove: (event) {
                      if ((event.localPosition - const Offset(38, 38)).distance > 58) {
                        _cancelHold();
                      }
                    },
                    child: AnimatedBuilder(
                      animation: _hold,
                      builder: (_, _) => SizedBox(
                        width: 76, height: 76,
                        child: Stack(
                          alignment: Alignment.center,
                          children: <Widget>[
                            Container(
                              width: 64, height: 64,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(0xFF321B29),
                              ),
                              alignment: Alignment.center,
                              child: Text('Xóa', style: TextStyle(
                                color: _ready && widget.onDeleteRequested != null
                                    ? const Color(0xFFFFC4D0) : const Color(0xFF877080),
                                fontSize: 14,
                              )),
                            ),
                            SizedBox(
                              width: 70, height: 70,
                              child: CircularProgressIndicator(
                                value: _hold.value,
                                strokeWidth: 3,
                                backgroundColor: const Color(0xFF593246),
                                color: const Color(0xFFFC71D6),
                              ),
                            ),
                          ],
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
    ),
  );
}
