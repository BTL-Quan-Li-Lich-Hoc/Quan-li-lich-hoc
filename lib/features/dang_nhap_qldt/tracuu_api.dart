import 'dart:convert';

import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/semester_data.dart';

final class TracuuApi {
  const new();

  String scriptForAttempt(int attempt) =>
      _script.replaceAll('__ATTEMPT__', '$attempt');

  String get _script => r'''
    (function () {
      const attempt = __ATTEMPT__;
      const bridge = window.flutter_inappwebview;
      const system = window.edu && edu.system;
      if (!bridge || typeof bridge.callHandler !== 'function') return 'BRIDGE_MISSING';
      const send = (handler, value) => bridge.callHandler(handler, attempt, value);
      let done = false;
      const fail = (code, diagnostic) => {
        if (done) return;
        done = true;
        if (diagnostic) {
          bridge.callHandler('betterPhenikaaRegistrationError', attempt,
            code, JSON.stringify(diagnostic));
        } else {
          send('betterPhenikaaRegistrationError', code);
        }
      };
      const stage = value => send('betterPhenikaaRegistrationStage', value);
      const id = value => {
        const text = String(value == null ? '' : value).trim();
        return /^[A-Za-z0-9_-]{1,64}$/.test(text) ? text : '[redacted]';
      };
      const label = value => {
        if (value == null) return null;
        const text = String(value).trim();
        if (/token|cookie|authorization|session|bearer|password|mat.?khau/i.test(text))
          return '[redacted]';
        return text.slice(0, 160)
          .replace(/[\w.+-]+@[\w.-]+\.[A-Za-z]{2,}/g, '[email]')
          .replace(/(?:\+?\d[\d\s.-]{6,}\d)/g, '[number]');
      };
      try { stage('scriptStart'); } catch (_) { return 'BRIDGE_EXCEPTION'; }
      if (!bridge || !system || !system.userId || system.iM == null ||
          typeof system.makeRequest !== 'function') {
        fail('SESSION_EXPIRED');
        return 'SESSION_EXPIRED';
      }
      const call = (action, func, data, next) => {
        const payload = Object.assign({action, func, iM: system.iM,
          strQLSV_NguoiHoc_Id: system.userId}, data);
        try {
          system.makeRequest({
            success: response => {
              if (done) return;
              if (func === 'pkg_dangkyhoc_thongtin.LayThoiGianDangKyCaNhan') {
                stage('semesterResponse');
              }
              if (!response || response.Success !== true || !Array.isArray(response.Data)) {
                fail('INVALID_RESPONSE');
                return;
              }
              try { next(response); } catch (_) { fail('INVALID_RESPONSE'); }
            },
            error: () => fail('NETWORK_ERROR'),
            type: 'POST', action, contentType: true, data: payload, fakedb: []
          }, false, false, false, null);
        } catch (_) { fail('REQUEST_ERROR'); }
      };
      stage('semesterRequest');
      call('DKH_ThongTin_MH/DSA4FSkuKAYoIC8FIC8mCjgCIA8pIC8P',
        'pkg_dangkyhoc_thongtin.LayThoiGianDangKyCaNhan',
        {strDaoTao_ThoiGianDaoTao_Id: null}, semesters => {
          const choices = semesters.Data.map(row => {
            const match = /^(\d{4})_(\d{4})_(\d+)$/.exec(row.THOIGIAN);
            return match && Number(match[2]) === Number(match[1]) + 1 && row.ID
              ? {id: row.ID, name: row.THOIGIAN, year: Number(match[1]), term: Number(match[3])}
              : null;
          }).filter(Boolean).sort((a, b) => b.year - a.year || b.term - a.term);
          if (!choices.length) { fail('NO_SEMESTER'); return; }
          const latest = choices[0];
          stage('semesterPlan');
          call('DKH_ThongTin_MH/DSA4BRIKJAkuICIpBSAvJgo4AiAPKSAv',
            'pkg_dangkyhoc_thongtin.LayDSKeHoachDangKyCaNhan',
            {strDaoTao_ThoiGianDaoTao_Id: latest.id}, plans => {
              const rows = plans.Data;
              const dropdown = document.querySelector('#dropSearch_KeHoach');
              const diagnostic = {
                version: 1,
                latestSemesterId: id(latest.id),
                latestSemesterName: label(latest.name),
                recordCount: rows.length,
                distinctIdCount: new Set(rows.map(row => String(row && row.ID || '').trim())
                  .filter(Boolean)).size,
                records: rows.slice(0, 200).map((row, index) => ({
                  index,
                  ID: id(row && row.ID),
                  DAOTAO_THOIGIANDAOTAO_ID: id(row && row.DAOTAO_THOIGIANDAOTAO_ID),
                  MAKEHOACH: label(row && row.MAKEHOACH),
                  TENKEHOACH: label(row && row.TENKEHOACH),
                  TRANGTHAI_ID: id(row && row.TRANGTHAI_ID),
                  HIEULUC: row && typeof row.HIEULUC === 'boolean' ? row.HIEULUC : null,
                  otherKeys: row && typeof row === 'object'
                    ? Object.keys(row).filter(key => ![
                      'ID', 'DAOTAO_THOIGIANDAOTAO_ID', 'MAKEHOACH',
                      'TENKEHOACH', 'TRANGTHAI_ID', 'HIEULUC'
                    ].includes(key)).slice(0, 100) : []
                })),
                dropdown: dropdown ? {
                  selectedId: id(dropdown.value),
                  options: [...dropdown.options].slice(0, 200).map((option, index) => ({
                    index, ID: id(option.value), label: label(option.text),
                    selected: option.selected
                  }))
                } : null
              };
              const matchingPlans = rows.filter(row => row && row.ID &&
                (String(row.MAKEHOACH || '').trim() === latest.name ||
                  String(row.MAKEHOACH || '').trim().startsWith(latest.name + ',')));
              const planIds = [...new Set(matchingPlans
                .map(row => String(row.ID || '').trim())
                .filter(Boolean))];
              const planSemesterIds = [...new Set(matchingPlans
                .map(row => String(row.DAOTAO_THOIGIANDAOTAO_ID || '').trim())
                .filter(Boolean))];
              diagnostic.matchingRecordIndexes = rows.flatMap((row, index) =>
                matchingPlans.includes(row) ? [index] : []);
              diagnostic.computedPlanIdCount = planIds.length;
              diagnostic.computedPlanIds = planIds.slice(0, 200).map(id);
              if (planIds.length !== 1 || planSemesterIds.length !== 1) {
                fail('PLAN_AMBIGUOUS', diagnostic); return;
              }
              stage('subjects');
              call('DKH_Chung_MH/DSA4CiQ1EDQgBSAvJgo4DS4xCS4iESkgLwPP',
                'pkg_dangkyhoc_chung.LayKetQuaDangKyLopHocPhan',
                {strDaoTao_ChuongTrinh_Id: '',
                  strDangKy_KeHoachDangKy_Id: planIds[0],
                  strNguoiThucHien_Id: system.userId,
                  strDaoTao_ThoiGianDaoTao_Id: latest.id}, registrations => {
                  stage('verification');
                  done = true;
                  send('betterPhenikaaRegistrationResult',
                    JSON.stringify({semesters, plans, registrations, userId: system.userId}));
                });
            });
        });
      return 'REG_SCRIPT_SUBMITTED';
    })();
  ''';

  RegisteredSemester parse(String raw) {
    final payload = jsonDecode(raw) as Map<String, dynamic>;
    final semesters = _data(payload['semesters']);
    final candidates = <(String, String, int, int)>[];
    for (final item in semesters) {
      final name = _string(item['THOIGIAN']);
      final match = RegExp(r'^(\d{4})_(\d{4})_(\d+)$').firstMatch(name);
      if (match == null ||
          int.parse(match[2]!) != int.parse(match[1]!) + 1 ||
          _string(item['ID']).isEmpty) {
        continue;
      }
      candidates.add((
        _string(item['ID']),
        name,
        int.parse(match[1]!),
        int.parse(match[3]!),
      ));
    }
    if (candidates.isEmpty) {
      throw const FormatException('TraCuu không trả học kỳ hợp lệ.');
    }
    candidates.sort((a, b) {
      final year = b.$3.compareTo(a.$3);
      return year != 0 ? year : b.$4.compareTo(a.$4);
    });
    final latest = candidates.first;
    final plans = _data(payload['plans']).where((row) {
      final code = _string(row['MAKEHOACH']);
      return code == latest.$2 || code.startsWith('${latest.$2},');
    }).toList();
    final planIds = plans
        .map((row) => _string(row['ID']))
        .where((id) => id.isNotEmpty)
        .toSet();
    final planSemesterIds = plans
        .map((row) => _string(row['DAOTAO_THOIGIANDAOTAO_ID']))
        .where((id) => id.isNotEmpty)
        .toSet();
    if (planIds.length != 1 || planSemesterIds.length != 1) {
      throw const FormatException('Không xác định được một kế hoạch đăng ký.');
    }
    final planId = planIds.single;
    final planSemesterId = planSemesterIds.single;
    final rows = _data(payload['registrations']);
    final subjects = <String, String>{};
    final sections = <String, Map<String, RegisteredClassSection>>{};
    for (final row in rows) {
      final rowSemesterId = _string(row['DAOTAO_THOIGIANDAOTAO_ID']);
      if (_string(row['DANGKY_KEHOACHDANGKY_ID']) != planId ||
          (rowSemesterId != latest.$1 && rowSemesterId != planSemesterId)) {
        throw const FormatException(
          'TraCuu trả lớp khác học kỳ hoặc kế hoạch.',
        );
      }
      final subjectId = _string(row['DAOTAO_HOCPHAN_ID']);
      final name = subjectDisplayName(_string(row['DAOTAO_HOCPHAN_TEN']));
      final classId = _string(row['DANGKY_LOPHOCPHAN_ID']);
      final className = _string(row['DANGKY_LOPHOCPHAN_TEN']);
      final start = _date(row['NGAYBATDAU']);
      final end = _date(row['NGAYKETTHUC']);
      if (subjectId.isEmpty ||
          name.isEmpty ||
          classId.isEmpty ||
          className.isEmpty ||
          start == null ||
          end == null ||
          end.isBefore(start)) {
        throw const FormatException(
          'TraCuu trả môn hoặc lớp thiếu trường bắt buộc.',
        );
      }
      final previous = subjects[subjectId];
      if (previous != null &&
          normalizeSubjectName(previous) != normalizeSubjectName(name)) {
        throw const FormatException(
          'TraCuu trả ID môn với nhiều tên khác nhau.',
        );
      }
      subjects[subjectId] = name;
      final byClass = sections.putIfAbsent(subjectId, () => {});
      final existing = byClass[classId];
      final section = RegisteredClassSection(
        name: className,
        startsOn: start,
        endsOn: end,
      );
      if (existing != null &&
          (existing.name != className ||
              existing.startsOn != start ||
              existing.endsOn != end)) {
        throw const FormatException('TraCuu trả ID lớp với dữ liệu khác nhau.');
      }
      byClass[classId] = section;
    }
    return RegisteredSemester(
      id: latest.$2,
      name: latest.$2,
      subjectNames: subjects.values.toList(),
      classSections: {
        for (final entry in subjects.entries)
          entry.value: sections[entry.key]!.values.toList(),
      },
      confirmedEmpty: rows.isEmpty,
    );
  }

  String displayNameFromVerifiedResult(String raw) {
    final payload = jsonDecode(raw) as Map<String, dynamic>;
    final rows = _data(payload['registrations']);
    for (final row in rows) {
      final family = _string(row['QLSV_NGUOIHOC_HODEM']);
      final given = _string(row['QLSV_NGUOIHOC_TEN']);
      if (family.isNotEmpty && given.isNotEmpty) {
        return '$family $given';
      }

      for (final key in const <String>[
        'QLSV_NGUOIHOC_HOTEN',
        'HOTEN',
        'HO_TEN',
        'HOVATEN',
        'FULLNAME',
      ]) {
        final full = _string(row[key]);
        if (full.isNotEmpty) return full;
      }

      if (family.isNotEmpty) return family;
      if (given.isNotEmpty) return given;
    }
    return '';
  }

  /// Persist only verified routing identifiers, never credentials or responses.
  String routeForVerifiedResult(String raw) {
    final payload = jsonDecode(raw) as Map<String, dynamic>;
    final userId = _string(payload['userId']);
    final semesters = _data(payload['semesters']);
    final plans = _data(payload['plans']);
    final registration = parse(raw);
    final latest = semesters
        .where((row) => _string(row['THOIGIAN']) == registration.id)
        .map((row) => _string(row['ID']))
        .toSet();
    final matching = plans
        .where((row) {
          final name = _string(row['MAKEHOACH']);
          return name == registration.name ||
              name.startsWith('${registration.name},');
        })
        .map((row) => _string(row['ID']))
        .where((id) => id.isNotEmpty)
        .toSet();
    if (userId.isEmpty || latest.length != 1 || matching.length != 1) {
      throw const FormatException('Không xác minh được đường dẫn đăng ký.');
    }
    return jsonEncode(<String, String>{
      'userId': userId,
      'semesterId': latest.single,
      'semesterName': registration.name,
      'planId': matching.single,
    });
  }

  List<Map<String, dynamic>> _data(Object? value) {
    if (value is! Map || value['Success'] != true || value['Data'] is! List) {
      throw const FormatException('TraCuu chưa trả Data hợp lệ.');
    }
    return (value['Data'] as List).map((row) {
      if (row is! Map) {
        throw const FormatException('TraCuu có dòng không hợp lệ.');
      }
      return Map<String, dynamic>.from(row);
    }).toList();
  }

  String _string(Object? value) => value?.toString().trim() ?? '';

  DateTime? _date(Object? value) {
    final match = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$')
        .firstMatch(_string(value));
    if (match == null) return null;
    final day = int.parse(match[1]!);
    final month = int.parse(match[2]!);
    final year = int.parse(match[3]!);
    final date = DateTime(year, month, day);
    return date.day == day && date.month == month && date.year == year
        ? date
        : null;
  }
}
