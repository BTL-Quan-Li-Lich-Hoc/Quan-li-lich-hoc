import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/qldt_models.dart';
import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/semester_data.dart';

final class QldtLoginResult {
  const new({
    required this.schedule,
    this.semester,
    this.registrationRoute,
    this.termStartedAt,
  });

  final ImportedScheduleData schedule;
  final CurrentSemester? semester;
  final String? registrationRoute;
  final DateTime? termStartedAt;
}
