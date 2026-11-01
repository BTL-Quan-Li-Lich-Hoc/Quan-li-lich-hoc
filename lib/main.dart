import 'dart:async';

import 'package:better_phenikaa_schedule/app/app.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _LoginCreditOverlay(child: BetterPhenikaaScheduleApp()));
}

class _LoginCreditOverlay extends StatefulWidget {
  const new({required this.child});

  final Widget child;

  @override
  State<_LoginCreditOverlay> createState() => _LoginCreditOverlayState();
}

class _LoginCreditOverlayState extends State<_LoginCreditOverlay> {
  static const _snapshotKey = 'better_phenikaa_snapshot_v1';

  Timer? _watchTimer;
  bool _showCredit = false;

  @override
  void initState() {
    super.initState();
    unawaited(_startWatching());
  }

  Future<void> _startWatching() async {
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted) {
      return;
    }
    await _refreshCreditVisibility();
    _watchTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => unawaited(_refreshCreditVisibility()),
    );
  }

  Future<void> _refreshCreditVisibility() async {
    final prefs = await SharedPreferences.getInstance();
    final snapshot = prefs.getString(_snapshotKey);
    final shouldShow = snapshot == null || snapshot.isEmpty;
    if (mounted && shouldShow != _showCredit) {
      setState(() => _showCredit = shouldShow);
    }
  }

  @override
  void dispose() {
    _watchTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight;
        final width = constraints.maxWidth;
        return Directionality(
          textDirection: TextDirection.ltr,
          child: Stack(
            children: <Widget>[
              Positioned.fill(child: widget.child),
              if (_showCredit)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: height * .012,
                  child: IgnorePointer(
                    child: Text(
                      'DevbyCooc',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: const Color(0xFF9AA5BD),
                        fontSize: height * .009,
                        fontWeight: FontWeight.w600,
                        letterSpacing: width * .0005,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
