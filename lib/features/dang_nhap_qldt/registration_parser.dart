import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/semester_data.dart';
import 'package:html/parser.dart' as html_parser;

final class QldtRegistrationParser {
  const new();

  RegisteredSemester parse({
    required String html,
    required String selectedSemesterValue,
    required String selectedPlanValue,
  }) {
    final document = html_parser.parse(html);
    final dropdown = document.querySelector('#dropSearch_HocKy');
    final plans = document.querySelector('#dropSearch_KeHoach');
    final results = document.querySelector('#zoneKetQuaDangKy');
    if (dropdown == null || plans == null || results == null) {
      throw const FormatException('TraCuu chưa tải đủ dữ liệu đăng ký.');
    }

    final semesters = <_SemesterOption>[];
    for (final option in dropdown.querySelectorAll('option')) {
      final value = option.attributes['value']?.trim() ?? '';
      final name = option.text.trim();
      final match = RegExp(r'^(\d{4})_(\d{4})_(\d+)$').firstMatch(name);
      if (value.isEmpty || match == null) {
        continue;
      }
      final startYear = int.parse(match.group(1)!);
      final endYear = int.parse(match.group(2)!);
      if (endYear != startYear + 1) {
        continue;
      }
      semesters.add(
        _SemesterOption(
          value: value,
          name: name,
          startYear: startYear,
          term: int.parse(match.group(3)!),
        ),
      );
    }
    if (semesters.isEmpty) {
      throw const FormatException('TraCuu không trả danh sách học kỳ hợp lệ.');
    }
    semesters.sort((a, b) {
      final year = b.startYear.compareTo(a.startYear);
      return year != 0 ? year : b.term.compareTo(a.term);
    });
    final latest = semesters.first;
    if (selectedSemesterValue.trim() != latest.value) {
      throw const FormatException(
        'TraCuu chưa hiển thị kết quả của học kỳ mới nhất.',
      );
    }
    final matchingPlans = plans.querySelectorAll('option').where((option) {
      final label = option.text.trim();
      return label.startsWith('${latest.name},') || label == latest.name;
    });
    if (selectedPlanValue.trim().isEmpty ||
        !matchingPlans.any(
          (option) =>
              option.attributes['value']?.trim() == selectedPlanValue.trim(),
        )) {
      throw const FormatException(
        'TraCuu chưa chọn kế hoạch của học kỳ mới nhất.',
      );
    }

    final subjectItems = results.querySelectorAll('.subject-item');
    if (subjectItems.isEmpty) {
      throw const FormatException('TraCuu chưa trả danh sách môn đăng ký.');
    }
    final subjectNames = <String>[];
    final classSections = <String, List<RegisteredClassSection>>{};
    for (final item in subjectItems) {
      final heading = item.querySelector('h4')?.text.trim() ?? '';
      final name = subjectDisplayName(heading);
      if (name.isEmpty) {
        throw const FormatException('TraCuu có môn học không có tên.');
      }
      subjectNames.add(name);
      final sections = <RegisteredClassSection>[];
      for (final section in item.querySelectorAll('.classroom-section-item')) {
        final className =
            section.querySelector('.btnChiTietLopHocPhan')?.text.trim() ?? '';
        if (className.isEmpty) {
          throw FormatException('TraCuu thiếu tên lớp của môn $name.');
        }
        final dateRange = RegExp(
          r'(\d{2}/\d{2}/\d{4})\s*-\s*(\d{2}/\d{2}/\d{4})',
        ).firstMatch(section.querySelector('.classroom-day')?.text ?? '');
        if (dateRange == null) {
          throw FormatException(
            'TraCuu thiếu khoảng ngày học của lớp $className.',
          );
        }
        final start = _parseDate(dateRange.group(1)!);
        final end = _parseDate(dateRange.group(2)!);
        if (start == null || end == null || end.isBefore(start)) {
          throw FormatException(
            'TraCuu có khoảng ngày học không hợp lệ: $className.',
          );
        }
        sections.add(
          RegisteredClassSection(name: className, startsOn: start, endsOn: end),
        );
      }
      classSections[name] = sections;
    }

    return RegisteredSemester(
      id: latest.name,
      name: latest.name,
      subjectNames: subjectNames,
      classSections: classSections,
    );
  }

  DateTime? _parseDate(String text) {
    final parts = text.split('/').map(int.tryParse).toList();
    if (parts.length != 3 || parts.any((part) => part == null)) return null;
    final date = DateTime(parts[2]!, parts[1]!, parts[0]!);
    return date.year == parts[2] &&
            date.month == parts[1] &&
            date.day == parts[0]
        ? date
        : null;
  }
}

final class _SemesterOption {
  const new({
    required this.value,
    required this.name,
    required this.startYear,
    required this.term,
  });

  final String value;
  final String name;
  final int startYear;
  final int term;
}
