import 'dart:convert';

import 'package:cryptography/cryptography.dart';

const updateManifestUrl = String.fromEnvironment('UPDATE_MANIFEST_URL');
const updatePublicKeyBase64 = String.fromEnvironment(
  'UPDATE_PUBLIC_KEY_BASE64',
);
const updatePackageName = 'vn.edu.phenikaa.better_phenikaa_schedule';

final class UpdateManifest {
  const UpdateManifest({
    required this.versionCode,
    required this.versionName,
    required this.minimumVersionCode,
    required this.apkUrl,
    required this.apkSha256,
    required this.apkSize,
    required this.publishedAt,
    required this.notes,
  });

  final int versionCode;
  final String versionName;
  final int minimumVersionCode;
  final Uri apkUrl;
  final String apkSha256;
  final int apkSize;
  final DateTime publishedAt;
  final String notes;

  bool appliesTo(int installed) =>
      versionCode > installed && installed >= minimumVersionCode;

  static UpdateManifest parseVerified(List<int> bytes) {
    final raw = jsonDecode(utf8.decode(bytes, allowMalformed: false));
    if (raw is! Map<String, dynamic> ||
        raw['schema'] != 1 ||
        raw['packageName'] != updatePackageName) {
      throw const FormatException('Invalid update manifest');
    }
    const fields = <String>{
      'schema',
      'packageName',
      'versionCode',
      'versionName',
      'minimumVersionCode',
      'apkUrl',
      'apkSha256',
      'apkSize',
      'publishedAt',
      'notes',
    };
    if (raw.keys.toSet().difference(fields).isNotEmpty ||
        fields.difference(raw.keys.toSet()).isNotEmpty) {
      throw const FormatException('Unexpected update manifest fields');
    }
    final version = raw['versionCode'];
    final minVersion = raw['minimumVersionCode'];
    final size = raw['apkSize'];
    final name = raw['versionName'];
    final url = Uri.tryParse(
      raw['apkUrl'] is String ? raw['apkUrl'] as String : '',
    );
    final hash = raw['apkSha256'];
    final notes = raw['notes'];
    final timestamp = raw['publishedAt'];
    if (version is! int ||
        version < 1 ||
        minVersion is! int ||
        minVersion < 1 ||
        minVersion >= version ||
        size is! int ||
        size < 1 ||
        size > 300000000 ||
        name is! String ||
        !RegExp(r'^cooc\.\d+\.\d+$').hasMatch(name) ||
        url == null ||
        url.scheme != 'https' ||
        url.host.isEmpty ||
        url.userInfo.isNotEmpty ||
        url.fragment.isNotEmpty ||
        hash is! String ||
        !RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(hash) ||
        notes is! String ||
        notes.length > 500 ||
        timestamp is! String) {
      throw const FormatException('Invalid update manifest fields');
    }
    final published = DateTime.tryParse(timestamp);
    if (published == null || !published.isUtc) {
      throw const FormatException('Invalid publication time');
    }
    return UpdateManifest(
      versionCode: version,
      versionName: name,
      minimumVersionCode: minVersion,
      apkUrl: url,
      apkSha256: hash.toLowerCase(),
      apkSize: size,
      publishedAt: published,
      notes: notes,
    );
  }
}

/// Signature is Ed25519 over the exact raw UTF-8 bytes of latest.json.
/// latest.json.sig contains only base64 of the 64-byte detached signature.
final class UpdateManifestVerifier {
  const UpdateManifestVerifier();

  Future<UpdateManifest> verify(
    List<int> bytes,
    String signatureBase64, {
    String publicKeyBase64 = updatePublicKeyBase64,
  }) async {
    final key = base64.decode(publicKeyBase64);
    final signatureBytes = base64.decode(signatureBase64.trim());
    if (key.length != 32 || signatureBytes.length != 64) {
      throw const FormatException('Invalid update signing material');
    }
    final publicKey = SimplePublicKey(key, type: KeyPairType.ed25519);
    final valid = await Ed25519().verify(
      bytes,
      signature: Signature(signatureBytes, publicKey: publicKey),
    );
    if (!valid) throw const FormatException('Invalid update signature');
    return UpdateManifest.parseVerified(bytes);
  }
}
