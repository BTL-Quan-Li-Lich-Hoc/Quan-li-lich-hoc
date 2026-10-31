import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/semester_changes.dart';
import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/semester_data.dart';

final class SemesterSyncCoordinator {
  const new({
    required this.store,
    this.detector = const SemesterChangeDetector(),
  });

  final CurrentSemesterStore store;
  final SemesterChangeDetector detector;

  Future<SemesterDifference> sync(
    Future<CurrentSemester> Function() fetchParseAndValidate,
  ) async {
    final previous = await store.read();
    final candidate = await fetchParseAndValidate();
    final difference = detector.compare(previous, candidate);
    await store.save(candidate);
    return difference;
  }
}
