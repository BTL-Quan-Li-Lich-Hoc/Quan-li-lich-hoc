import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// Browser-only login. No password/cookie is extracted into app logs.
/// An authenticated schedule API is not wired until its real contract is known.
class QldtWebViewPage extends StatefulWidget {
  const QldtWebViewPage({required this.portalUrl, super.key});
  final String portalUrl;

  static bool isAllowed(String input) {
    final uri = Uri.tryParse(input);
    if (uri == null || uri.scheme != 'https') return false;
    final host = uri.host.toLowerCase();
    return host == 'phenikaa-uni.edu.vn' || host.endsWith('.phenikaa-uni.edu.vn');
  }

  @override
  State<QldtWebViewPage> createState() => _QldtWebViewPageState();
}

class _QldtWebViewPageState extends State<QldtWebViewPage> {
  String status = 'Đang mở cổng QLĐT';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('QLĐT — WebView')),
      body: Column(children: <Widget>[
        Padding(padding: const EdgeInsets.all(12), child: Text(status)),
        Expanded(child: InAppWebView(
          initialUrlRequest: URLRequest(url: WebUri(widget.portalUrl)),
          onLoadStop: (controller, url) {
            if (mounted) setState(() => status = 'Trang đã tải; đăng nhập trực tiếp trên website.');
          },
          onReceivedError: (controller, request, error) {
            if (request.isForMainFrame == true && mounted) {
              setState(() => status = 'Không tải được trang. Kiểm tra mạng và URL.');
            }
          },
        )),
      ]),
    );
  }
}
