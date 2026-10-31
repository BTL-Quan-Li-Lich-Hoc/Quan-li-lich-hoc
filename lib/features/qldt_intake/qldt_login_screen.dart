import 'package:better_phenikaa_schedule/features/qldt_intake/qldt_webview.dart';
import 'package:flutter/material.dart';

/// Opens the real university portal in a WebView.
/// Importing authenticated data into the local store is NOT connected yet.
class QldtLoginScreen extends StatelessWidget {
  const QldtLoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const QldtWebViewPage(
      portalUrl: 'https://qldt.phenikaa-uni.edu.vn/',
    );
  }
}
