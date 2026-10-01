import 'package:flutter/material.dart';

class QldtLoginScreen extends StatelessWidget {
  const QldtLoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Đăng nhập QLĐT')),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Icon(Icons.verified_user_outlined, size: 48),
                const SizedBox(height: 16),
                Text(
                  'Khung QLĐT intake',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                const Text(
                  'TV1 triển khai session, WebView và parser tại feature này. '
                  'Kết quả duy nhất đi ra ngoài là QldtImportPayload.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
