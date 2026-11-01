import 'dart:convert';
import 'dart:io';

final class QldtNativeSession {
  const QldtNativeSession({
    required this.tokenJwt,
    required this.userId,
    required this.iM,
    required this.appId,
    required this.functionId,
    required this.cookie,
    required this.displayName,
  });

  factory QldtNativeSession.fromJson(Map<String, dynamic> json) {
    return QldtNativeSession(
      tokenJwt: (json['tokenJWT'] ?? '').toString(),
      userId: (json['userId'] ?? '').toString(),
      iM: (json['iM'] ?? '').toString(),
      appId: (json['appId'] ?? '').toString(),
      functionId: (json['strChucNangId'] ?? '').toString(),
      cookie: (json['cookie'] ?? '').toString(),
      displayName: (json['name'] ?? '').toString(),
    );
  }

  final String tokenJwt;
  final String userId;
  final String iM;
  final String appId;
  final String functionId;
  final String cookie;
  final String displayName;

  bool get isValid =>
      tokenJwt.isNotEmpty &&
      userId.isNotEmpty &&
      iM.isNotEmpty &&
      appId.isNotEmpty &&
      functionId.isNotEmpty;
}

final class QldtNativeRegistration {
  const QldtNativeRegistration({required this.raw, required this.semesterName});

  final String raw;
  final String semesterName;
}

final class QldtNativeTransport {
  const QldtNativeTransport();

  static const _root = 'https://qldtbeta.phenikaa-uni.edu.vn';

  Future<QldtNativeRegistration> fetchRegistration(
    QldtNativeSession session,
  ) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 4);
    try {
      final semesters = await _post(
        client: client,
        session: session,
        action: 'DKH_ThongTin_MH/DSA4FSkuKAYoIC8FIC8mCjgCIA8pIC8P',
        func: 'pkg_dangkyhoc_thongtin.LayThoiGianDangKyCaNhan',
        extra: <String, dynamic>{'strDaoTao_ThoiGianDaoTao_Id': null},
      );

      final candidates = <({String id, String name, int year, int term})>[];
      for (final row in _rows(semesters)) {
        final name = (row['THOIGIAN'] ?? '').toString();
        final id = (row['ID'] ?? '').toString().trim();
        final match = RegExp(r'^(\d{4})_(\d{4})_(\d+)$').firstMatch(name);
        if (match == null || id.isEmpty) continue;
        final firstYear = int.parse(match[1]!);
        final secondYear = int.parse(match[2]!);
        final term = int.parse(match[3]!);
        if (secondYear != firstYear + 1) continue;
        candidates.add((id: id, name: name, year: firstYear, term: term));
      }
      if (candidates.isEmpty) {
        throw const FormatException('NO_SEMESTER');
      }
      candidates.sort((a, b) {
        final year = b.year.compareTo(a.year);
        return year != 0 ? year : b.term.compareTo(a.term);
      });
      final latest = candidates.first;

      final plans = await _post(
        client: client,
        session: session,
        action: 'DKH_ThongTin_MH/DSA4BRIKJAkuICIpBSAvJgo4AiAPKSAv',
        func: 'pkg_dangkyhoc_thongtin.LayDSKeHoachDangKyCaNhan',
        extra: <String, dynamic>{'strDaoTao_ThoiGianDaoTao_Id': latest.id},
      );

      final matching = _rows(plans).where((row) {
        final code = (row['MAKEHOACH'] ?? '').toString().trim();
        return code == latest.name || code.startsWith('${latest.name},');
      }).toList();
      final planIds = matching
          .map((row) => (row['ID'] ?? '').toString().trim())
          .where((id) => id.isNotEmpty)
          .toSet();
      final planSemesterIds = matching
          .map(
            (row) => (row['DAOTAO_THOIGIANDAOTAO_ID'] ?? '').toString().trim(),
          )
          .where((id) => id.isNotEmpty)
          .toSet();
      if (planIds.length != 1 || planSemesterIds.length != 1) {
        throw const FormatException('PLAN_AMBIGUOUS');
      }

      final registrations = await _post(
        client: client,
        session: session,
        action: 'DKH_Chung_MH/DSA4CiQ1EDQgBSAvJgo4DS4xCS4iESkgLwPP',
        func: 'pkg_dangkyhoc_chung.LayKetQuaDangKyLopHocPhan',
        extra: <String, dynamic>{
          'strDaoTao_ChuongTrinh_Id': '',
          'strDangKy_KeHoachDangKy_Id': planIds.single,
          'strNguoiThucHien_Id': session.userId,
          'strDaoTao_ThoiGianDaoTao_Id': latest.id,
        },
      );

      return QldtNativeRegistration(
        raw: jsonEncode(<String, dynamic>{
          'semesters': semesters,
          'plans': plans,
          'registrations': registrations,
          'userId': session.userId,
        }),
        semesterName: latest.name,
      );
    } finally {
      client.close(force: true);
    }
  }

  Future<String> fetchStudentDisplayName(
    QldtNativeSession session,
  ) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 4);
    try {
      final response = await _post(
        client: client,
        session: session,
        action: 'SV_ThongTin_MH/DSA4FSkuLyYVKC8CKTQuLyYVMygvKQkuIgPP',
        func: 'pkg_congthongtin_hssv_thongtin.LayThongTinChuongTrinhHoc',
        extra: const <String, dynamic>{},
      );
      for (final row in _rows(response)) {
        final family = _cleanName(
          row['QLSV_NGUOIHOC_HODEM'] ?? row['HODEM'] ?? row['HO'],
        );
        final given = _cleanName(
          row['QLSV_NGUOIHOC_TEN'] ?? row['TEN'],
        );

        // Prefer the structured Vietnamese name fields. QLĐT can expose
        // full-name fields in display order, which may move the given name
        // to the front (for example "Minh Nguyễn Đạo"). Building from
        // HỌ ĐỆM + TÊN preserves the canonical student-name order.
        if (family.isNotEmpty && given.isNotEmpty) {
          final combined = _cleanName('$family $given');
          if (combined.isNotEmpty) return combined;
        }

        final full = _cleanName(
          row['QLSV_NGUOIHOC_HOTEN'] ??
              row['HOTEN'] ??
              row['HOVATEN'] ??
              row['FULLNAME'],
        );
        if (full.isNotEmpty) return full;

        // If QLĐT only supplied one structured component, keep it as the
        // final fallback rather than attempting to reorder an unknown name.
        if (family.isNotEmpty) return family;
        if (given.isNotEmpty) return given;
      }
      return '';
    } finally {
      client.close(force: true);
    }
  }

  Future<String> fetchScheduleEnvelope({
    required QldtNativeSession session,
    required DateTime start,
    required DateTime end,
  }) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 4);
    try {
      final response = await _post(
        client: client,
        session: session,
        action: 'SV_ThongTin_MH/DSA4BRINKCIpAiAPKSAv',
        func: 'pkg_congthongtin_hssv_thongtin.LayDSLichCaNhan',
        extra: <String, dynamic>{
          'strNgayBatDau': _formatDate(start),
          'strNgayKetThuc': _formatDate(end),
        },
      );
      return jsonEncode(<String, dynamic>{
        'name': session.displayName,
        'response': response,
      });
    } finally {
      client.close(force: true);
    }
  }

  Future<Map<String, dynamic>> _post({
    required HttpClient client,
    required QldtNativeSession session,
    required String action,
    required String func,
    required Map<String, dynamic> extra,
  }) async {
    final data = <String, dynamic>{
      'action': action,
      'func': func,
      'iM': session.iM,
      'strQLSV_NguoiHoc_Id': session.userId,
      ...extra,
    };
    data.putIfAbsent('strChucNang_Id', () => session.functionId);
    data.putIfAbsent('strNguoiThucHien_Id', () => session.userId);
    data.putIfAbsent('strVaiTroDangNhap_Id', () => session.appId);
    data.putIfAbsent('strChucNangHeThong_Id', () => session.functionId);

    final slash = action.indexOf('/');
    final actionKey = action.substring(slash + 1);
    final apiPrefix = action.substring(0, action.indexOf('_'));
    final apiPath = switch (apiPrefix) {
      'DKH' => '/dangkyhocapi3/api',
      'SV' => '/sinhvienapi3/api',
      _ => throw UnsupportedError('Unsupported QLĐT API prefix: $apiPrefix'),
    };

    final uri = Uri.parse('$_root$apiPath/$action');
    final request = await client
        .postUrl(uri)
        .timeout(const Duration(seconds: 5));
    request.headers.set(
      HttpHeaders.authorizationHeader,
      'Bearer ${session.tokenJwt}',
    );
    request.headers.set(
      HttpHeaders.acceptHeader,
      'application/json, text/javascript, */*; q=0.01',
    );
    request.headers.set(
      HttpHeaders.contentTypeHeader,
      'application/x-www-form-urlencoded; charset=UTF-8',
    );
    if (session.cookie.isNotEmpty) {
      request.headers.set(HttpHeaders.cookieHeader, session.cookie);
    }

    final body = Uri(
      queryParameters: <String, String>{
        'A': _encode(jsonEncode(data), actionKey),
      },
    ).query;
    request.write(body);

    final response = await request.close().timeout(const Duration(seconds: 5));
    final text = await utf8.decoder
        .bind(response)
        .join()
        .timeout(const Duration(seconds: 5));
    if (response.statusCode != HttpStatus.ok) {
      throw HttpException('HTTP ${response.statusCode}', uri: uri);
    }

    final envelope = jsonDecode(text) as Map<String, dynamic>;
    if (envelope['Success'] != true) {
      throw StateError('QLĐT Success != true');
    }
    final outer = envelope['Data'];
    if (outer is Map && outer['B'] is String) {
      envelope['Data'] = jsonDecode(_decode(outer['B'] as String, session.iM));
    }
    if (envelope['Data'] is! List) {
      throw const FormatException('QLĐT Data không phải danh sách.');
    }
    return envelope;
  }

  List<Map<String, dynamic>> _rows(Map<String, dynamic> envelope) {
    final raw = envelope['Data'];
    if (raw is! List) return const <Map<String, dynamic>>[];
    return raw
        .whereType<Map>()
        .map((row) => row.cast<String, dynamic>())
        .toList();
  }

  String _encode(String plaintext, String key) {
    final chars = <int>[];
    for (var i = 0; i < plaintext.length; i++) {
      chars.add(plaintext.codeUnitAt(i) ^ key.codeUnitAt(i % key.length));
    }
    return base64Encode(utf8.encode(String.fromCharCodes(chars)));
  }

  String _decode(String encoded, String key) {
    final cipherText = utf8.decode(base64Decode(encoded));
    final chars = <int>[];
    for (var i = 0; i < cipherText.length; i++) {
      chars.add(cipherText.codeUnitAt(i) ^ key.codeUnitAt(i % key.length));
    }
    return String.fromCharCodes(chars);
  }

  static String _cleanName(Object? value) {
    final text = value?.toString().replaceAll(RegExp(r'\s+'), ' ').trim() ?? '';
    if (text.length < 2 || text.length > 120 || text.contains('@')) return '';
    return text;
  }

  static String _formatDate(DateTime value) {
    String two(int number) => number.toString().padLeft(2, '0');
    return '${two(value.day)}/${two(value.month)}/${value.year}';
  }
}
