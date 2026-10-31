import 'dart:async';

import 'package:better_phenikaa_schedule/features/app_update/henshin_vfx.dart';
import 'package:better_phenikaa_schedule/features/app_update/card_link_vfx.dart';
import 'package:better_phenikaa_schedule/features/app_update/update_controller.dart';
import 'package:better_phenikaa_schedule/features/app_update/update_name_match.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class UpdateFlowSheet extends StatefulWidget {
  const UpdateFlowSheet({
    required this.controller,
    required this.displayName,
    super.key,
  });

  final UpdateController controller;
  final String displayName;

  @override
  State<UpdateFlowSheet> createState() => _UpdateFlowSheetState();
}

class _UpdateFlowSheetState extends State<UpdateFlowSheet>
    with SingleTickerProviderStateMixin {
  final TextEditingController _manualName = TextEditingController();
  late final AnimationController _holdCharge = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  )..addStatusListener(_onHoldStatus);

  bool _holding = false;
  bool _manualSummary = false;
  bool _nfcVisible = false;
  bool _acceptedNfc = false;
  int _nfcSuccessToken = 0;
  int _nfcErrorToken = 0;
  int _manualSuccessToken = 0;
  Timer? _vfxVisibilityTimer;
  Timer? _manualResetTimer;
  Timer? _manualAuthorizeTimer;
  late UpdatePhase _lastPhase;

  bool get _nameMatches =>
      normalizeUpdateAccountName(widget.displayName).isNotEmpty &&
      normalizeUpdateAccountName(_manualName.text) ==
          normalizeUpdateAccountName(widget.displayName);

  bool get _canHold => widget.controller.notice != null && _nameMatches;

  bool get _realManualAvailable {
    final phase = widget.controller.phase;
    return phase == UpdatePhase.available ||
        phase == UpdatePhase.cancelled ||
        phase == UpdatePhase.failed ||
        phase == UpdatePhase.notAvailable;
  }

  @override
  void initState() {
    super.initState();
    _lastPhase = widget.controller.phase;
    widget.controller.addListener(_onUpdateState);
  }

  void _onUpdateState() {
    final phase = widget.controller.phase;
    if ((phase == UpdatePhase.authorized) &&
        (_lastPhase == UpdatePhase.waitingForCard ||
            _lastPhase == UpdatePhase.wrongCard)) {
      _acceptedNfc = true;
      _nfcVisible = true;
      _nfcSuccessToken++;
      unawaited(HapticFeedback.lightImpact());
      _hideNfcAfterBurst();
    } else if (phase == UpdatePhase.wrongCard &&
        _lastPhase != UpdatePhase.wrongCard) {
      _nfcVisible = true;
      _nfcErrorToken++;
    } else if (phase == UpdatePhase.waitingForCard) {
      _nfcVisible = true;
      _acceptedNfc = false;
      _vfxVisibilityTimer?.cancel();
    } else if ((phase == UpdatePhase.cancelled ||
            phase == UpdatePhase.failed ||
            phase == UpdatePhase.installed) &&
        !_acceptedNfc) {
      _nfcVisible = false;
    }
    _lastPhase = phase;
    if (mounted) setState(() {});
  }

  void _hideNfcAfterBurst() {
    _vfxVisibilityTimer?.cancel();
    _vfxVisibilityTimer = Timer(const Duration(milliseconds: 1600), () {
      if (mounted) setState(() => _nfcVisible = false);
    });
  }

  void _startNfc() {
    _vfxVisibilityTimer?.cancel();
    setState(() {
      _nfcVisible = true;
      _acceptedNfc = false;
    });
    unawaited(widget.controller.startCard());
  }

  void _beginHold(PointerDownEvent event) {
    if (_holding || !_canHold || !_realManualAvailable) return;
    _manualResetTimer?.cancel();
    setState(() => _holding = true);
    _holdCharge.forward(from: 0);
  }

  void _endHold(PointerEvent event) {
    if (!_holding) return;
    _holding = false;
    if (_holdCharge.isCompleted) return;
    _holdCharge.stop();
    _holdCharge.value = 0;
    if (mounted) setState(() {});
  }

  void _onHoldStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || !_holding || !_canHold) {
      return;
    }
    _holding = false;
    _manualSuccessToken++;
    unawaited(HapticFeedback.lightImpact());
    // The normal updater remains the only authorization path; VFX completes
    // before the existing verified-name action, cancellation on dispose.
    _manualAuthorizeTimer?.cancel();
    _manualAuthorizeTimer = Timer(const Duration(milliseconds: 1100), () {
      if (mounted && _nameMatches && _holdCharge.isCompleted &&
          _realManualAvailable && widget.controller.notice != null) {
        unawaited(widget.controller.startManualAfterHold());
      }
    });
    if (mounted) setState(() {});
    _manualResetTimer?.cancel();
    _manualResetTimer = Timer(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      _holdCharge.reset();
      setState(() {});
    });
  }

  @override
  void dispose() {
    _vfxVisibilityTimer?.cancel();
    _manualResetTimer?.cancel();
    _manualAuthorizeTimer?.cancel();
    widget.controller.removeListener(_onUpdateState);
    _holdCharge.removeStatusListener(_onHoldStatus);
    _holdCharge.dispose();
    _manualName.dispose();
    if (widget.controller.phase == UpdatePhase.waitingForCard ||
        widget.controller.phase == UpdatePhase.wrongCard) {
      unawaited(widget.controller.cancel());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    builder: (context, _) {
      final controller = widget.controller;
      final notice = controller.notice;
      final phase = controller.phase;
      final progress = controller.total > 0
          ? (controller.downloaded / controller.total).clamp(0.0, 1.0)
          : null;
      final keyboard = MediaQuery.viewInsetsOf(context).bottom;
      final screenHeight = MediaQuery.sizeOf(context).height;
      final realNfcActive = phase == UpdatePhase.waitingForCard ||
          phase == UpdatePhase.wrongCard;
      return AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: EdgeInsets.only(bottom: keyboard),
        child: SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: (screenHeight - keyboard - 32)
                  .clamp(160.0, screenHeight),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Flexible(
                  fit: FlexFit.loose,
                  child: SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.fromLTRB(22, 22, 22, 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Text(
                          'Cập nhật Better Phenikaa',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          notice == null
                              ? (phase == UpdatePhase.checking
                                    ? 'Đang kiểm tra bản cập nhật…'
                                    : 'Chưa có bản cập nhật.')
                              : '${notice.versionName} · ${notice.notes}',
                        ),
                        const SizedBox(height: 16),
                        if (const bool.fromEnvironment('BPA_FAKE_UPDATE_TEST')) ...[
                          Text(
                            'Bản thử nghiệm kiểm tra Latest qua chữ ký thật. '
                            'Không có APK mới để tải hoặc cài đặt.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 12),
                        ],
                        if (_nfcVisible || realNfcActive) ...[
                          HenshinVfx(
                            progress: 0,
                            successToken: _nfcSuccessToken,
                            failureToken: _nfcErrorToken,
                          ),
                          Center(
                            child: Text(
                              _acceptedNfc
                                  ? 'Đã nhận thẻ'
                                  : phase == UpdatePhase.wrongCard
                                      ? 'Không đúng thẻ'
                                      : 'Đưa thẻ NFC lại gần điện thoại',
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        if (!const bool.fromEnvironment('BPA_FAKE_UPDATE_TEST') &&
                            _realManualAvailable) ...[
                          FilledButton.icon(
                            onPressed: notice == null ? null : _startNfc,
                            icon: const Icon(Icons.nfc_rounded),
                            label: const Text('Cập nhật bằng thẻ'),
                          ),
                          const SizedBox(height: 8),
                          OutlinedButton(
                            onPressed: notice == null
                                ? null
                                : () => setState(() {
                                      _manualSummary = true;
                                    }),
                            child: const Text('Cập nhật thủ công'),
                          ),
                          if (_manualSummary) ...[
                            const SizedBox(height: 12),
                            Text(
                              'Nhập đúng họ tên trong Tài khoản rồi giữ 2 giây để cập nhật ${notice?.versionName ?? "bản mới"}.',
                            ),
                            const SizedBox(height: 8),
                            TextField(
                                controller: _manualName,
                                onChanged: (_) => setState(() {}),
                                decoration: const InputDecoration(
                                  labelText: 'Họ và tên',
                                ),
                              ),
                            AnimatedBuilder(
                              animation: _holdCharge,
                              builder: (context, _) => Column(
                                children: <Widget>[
                                  HenshinVfx(
                                    progress: _holdCharge.value,
                                    successToken: _manualSuccessToken,
                                    failureToken: 0,
                                    manual: true,
                                    height: 190,
                                  ),
                                  Text(
                                    _holdCharge.isCompleted
                                        ? 'Đã xác nhận thao tác'
                                        : 'Giữ đủ 2 giây · ${(_holdCharge.value * 100).floor()}%',
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                        if (notice == null && phase == UpdatePhase.notAvailable)
                          TextButton(
                            onPressed: controller.checkQuietly,
                            child: const Text('Kiểm tra lại'),
                          ),
                        if (phase == UpdatePhase.downloading) ...[
                          const Text('Đang tải bản cập nhật'),
                          const SizedBox(height: 8),
                          LinearProgressIndicator(value: progress),
                          Text(
                            controller.total > 0
                                ? '${(100 * (progress ?? 0)).toStringAsFixed(0)}% · '
                                    '${controller.downloaded ~/ 1024} / ${controller.total ~/ 1024} KB'
                                : '',
                          ),
                        ],
                        if (phase == UpdatePhase.verifying)
                          const Text('Đang xác minh'),
                        if (phase == UpdatePhase.readyForInstaller)
                          const Text('Đang chuẩn bị cài đặt'),
                        if (phase == UpdatePhase.installerLaunched)
                          const Text('Tiếp tục trên màn hình cài đặt của Android.'),
                        if (phase == UpdatePhase.installed)
                          const Text('Đã cài bản cập nhật.'),
                        if (phase == UpdatePhase.permissionRequired) ...[
                          const Text(
                            'Android cần cho phép Better Phenikaa yêu cầu cài đặt. '
                            'Bạn có thể từ chối và tiếp tục dùng app bình thường.',
                          ),
                          const SizedBox(height: 8),
                          FilledButton(
                            onPressed: controller.openInstallSettings,
                            child: const Text('Mở cài đặt Android'),
                          ),
                        ],
                        if (controller.error != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            controller.error!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        if (phase != UpdatePhase.installerLaunched)
                          TextButton(
                            onPressed: () {
                              if (!controller.isRunningInBackground) {
                                unawaited(controller.cancel());
                              }
                              Navigator.of(context).pop();
                            },
                            child: const Text('Đóng'),
                          ),
                      ],
                    ),
                  ),
                ),
                if (_manualSummary && _realManualAvailable)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 8, 22, 12),
                    child: Listener(
                      behavior: HitTestBehavior.opaque,
                      onPointerDown: _beginHold,
                      onPointerUp: _endHold,
                      onPointerCancel: _endHold,
                      child: SizedBox(
                        width: double.infinity,
                        child: AnimatedBuilder(
                          animation: _holdCharge,
                          builder: (context, _) => FilledButton.tonal(
                            onPressed: _canHold ? () {} : null,
                            child: Text(
                              _holdCharge.isCompleted
                                  ? 'Đã kích hoạt'
                                  : _holding
                                      ? 'Đang giữ · ${(_holdCharge.value * 100).floor()}%'
                                      : 'Giữ để tiếp tục · 2 giây',
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class CardBindingSheet extends StatefulWidget {
  const CardBindingSheet({required this.controller, required this.displayName, super.key});
  final UpdateController controller;
  final String displayName;

  @override
  State<CardBindingSheet> createState() => _CardBindingSheetState();
}

class _CardBindingSheetState extends State<CardBindingSheet> {
  bool _loading = true;
  bool _scanning = false;
  bool _accepted = false;
  bool _presented = false;
  bool _deleting = false;
  bool _deleteDone = false;
  bool _deleteBusy = false;
  bool _deleteHolding = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onCardState);
    unawaited(_startBinding());
  }

  void _onCardState() {
    if (!mounted) return;
    if (_scanning && widget.controller.hasBoundCard) {
      _scanning = false;
      _accepted = true;
    }
    setState(() {});
  }

  Future<void> _startBinding() async {
    await widget.controller.refreshCardBinding();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _deleting = widget.controller.hasBoundCard;
      _deleteDone = false;
      _accepted = false;
      _presented = widget.controller.hasBoundCard;
      _scanning = !widget.controller.hasBoundCard;
    });
    if (_scanning) await widget.controller.startBindingCard();
  }

  Future<bool> _deleteCard() async {
    if (_deleteBusy || !widget.controller.hasBoundCard) return false;
    _deleteBusy = true;
    final removed = await widget.controller.removeBoundCard();
    _deleteBusy = false;
    return removed;
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onCardState);
    unawaited(widget.controller.stopBindingCard());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final animating = (_accepted && !_presented) ||
        (_deleting && !controller.hasBoundCard && !_deleteDone);
    return PopScope(
      canPop: !animating,
      child: SafeArea(
        child: SingleChildScrollView(
          physics: _deleteHolding ? const NeverScrollableScrollPhysics() : null,
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text('Thẻ cập nhật', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              if (_loading) ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: const SizedBox(
                  height: 520,
                  child: ColoredBox(color: Color(0xFF050913)),
                ),
              )
              else CardLinkVfx(
                displayName: widget.displayName,
                deleting: _deleting,
                status: _deleting ? 'bound' : _accepted ? 'accepted' : _presented ? 'bound' : 'waiting',
                onDeleteRequested: controller.isRunningInBackground ? null : _deleteCard,
                onHoldingChanged: (holding) {
                  if (mounted) setState(() => _deleteHolding = holding);
                },
                onComplete: () {
                  if (!mounted) return;
                  setState(() {
                    if (_deleting) {
                      _deleteDone = true;
                    } else {
                      _presented = true;
                      _deleting = true;
                    }
                  });
                },
              ),
              if (controller.error != null) ...[
                const SizedBox(height: 12),
                Text(controller.error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
              if (_deleteDone || (!_loading && !_deleting && !controller.hasBoundCard && !controller.bindingCard)) ...[
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _startBinding,
                  icon: const Icon(Icons.nfc_rounded),
                  label: Text(_deleteDone ? 'Liên kết thẻ mới' : 'Quét lại thẻ'),
                ),
              ],
              TextButton(
                onPressed: animating ? null : () => Navigator.of(context).pop(),
                child: const Text('Đóng'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
