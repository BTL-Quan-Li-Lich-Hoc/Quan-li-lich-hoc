import 'dart:convert';

import 'package:better_phenikaa_schedule/features/app_update/update_manifest.dart';
import 'package:better_phenikaa_schedule/features/app_update/update_http_stub.dart'
    if (dart.library.io) 'update_http_io.dart'
    as transport;

final class UpdateRepository {
  UpdateRepository({
    UpdateManifestVerifier? verifier,
    String manifestUrl = updateManifestUrl,
    String publicKeyBase64 = updatePublicKeyBase64,
  }) : _verifier = verifier ?? const UpdateManifestVerifier(),
       _manifestUrl = manifestUrl,
       _publicKeyBase64 = publicKeyBase64;
  final UpdateManifestVerifier _verifier;
  final String _manifestUrl;
  final String _publicKeyBase64;

  Future<UpdateManifest> fetch() async {
    final uri = Uri.tryParse(_manifestUrl);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        _publicKeyBase64.isEmpty) {
      throw const FormatException('Update channel is not configured');
    }
    // Both immutable small files can be downloaded concurrently; the
    // existing signature verification still covers the exact manifest bytes.
    final replies = await Future.wait<List<int>>(<Future<List<int>>>[
      transport.fetchUpdateBytes(uri, 8192),
      transport.fetchUpdateBytes(Uri.parse('${uri.toString()}.sig'), 256),
    ]);
    final bytes = replies[0];
    final signature = replies[1];
    return _verifier.verify(
      bytes,
      ascii.decode(signature),
      publicKeyBase64: _publicKeyBase64,
    );
  }
}
