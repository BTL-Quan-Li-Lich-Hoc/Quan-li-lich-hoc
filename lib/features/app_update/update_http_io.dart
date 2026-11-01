import 'dart:io';

Future<List<int>> fetchUpdateBytes(Uri uri, int limit) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
  try {
    final request = await client
        .getUrl(uri)
        .timeout(const Duration(seconds: 8));
    request.followRedirects = false;
    final response = await request.close().timeout(const Duration(seconds: 8));
    if (response.statusCode != HttpStatus.ok ||
        response.contentLength > limit) {
      throw const HttpException('Invalid update response');
    }
    final bytes = <int>[];
    await for (final chunk in response.timeout(const Duration(seconds: 12))) {
      bytes.addAll(chunk);
      if (bytes.length > limit)
        throw const FormatException('Update metadata too large');
    }
    return bytes;
  } finally {
    client.close(force: true);
  }
}
