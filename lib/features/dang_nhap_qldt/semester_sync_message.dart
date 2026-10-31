import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/semester_changes.dart';

abstract final class SemesterSyncMessage {
  static String from(SemesterDifference difference) {
    if (difference.initial) {
      return 'Đã lưu dữ liệu học kỳ đầu tiên.';
    }
    if (!difference.hasChanges) {
      return 'Đồng bộ xong. Không có thay đổi lịch học hoặc lịch thi.';
    }
    return 'Đồng bộ xong: ${difference.addedSubjects.length} môn thêm, '
        '${difference.removedSubjects.length} môn hủy; '
        'lịch học ${difference.study.added} thêm, '
        '${difference.study.removed} hủy, ${difference.study.modified} đổi; '
        'lịch thi ${difference.exams.added} thêm, '
        '${difference.exams.removed} hủy, ${difference.exams.modified} đổi.';
  }
}
