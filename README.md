# Better Phenikaa Schedule

Bài tập lớn nhóm 1 — ứng dụng Flutter theo dõi **lịch học và lịch thi** cho sinh viên Phenikaa.

## Nhóm và phạm vi

| STT | Họ và tên | MSSV | Phần việc |
|---:|---|---|---|
| 1 | Đăng Văn Nam Khánh | 24100041 | QLĐT intake, kiểm tra dữ liệu đầu vào |
| 2 | Trần Đỗ Quốc Huy | 21011607 | Parser và logic lịch học/lịch thi |
| 3 | Trần Văn Dương | 24100043 | Cache local và repository dữ liệu |
| 4 | Nguyễn Minh Đạo | 24100222 | UI Flutter, Android home widgets và tích hợp |

## Chức năng trong nhánh tích hợp ngày 10

- Lịch học theo chế độ Ngày/Tuần.
- Danh sách lịch thi.
- Trạng thái loading, empty, error và tải lại.
- Đọc dữ liệu qua repository contracts.
- Cache lịch học/lịch thi dạng JSON trong SharedPreferences để đọc offline.
- Hai Android home widgets native:
  - Lịch học nhanh: lớp hiện tại hoặc sắp tới.
  - Tổng quan lịch học: tối đa bốn lớp trong ngày.
- Widget chỉ đọc snapshot local được Flutter publish qua `home_widget`; Kotlin không gọi QLĐT, HTTP hoặc WebView.

**Giới hạn hiện tại:** nhánh tích hợp có raw JSON boundary và parser, nhưng chưa nối luồng đăng nhập/session QLĐT thực tế vào app. Cache rỗng sẽ hiển thị empty state; không tự tạo lịch mẫu giả.

## Stack đang dùng

- Flutter 3.47.2 / Dart 3.13
- Riverpod + GoRouter
- SharedPreferences: cache JSON local và widget settings
- `home_widget` + Kotlin/XML: Android App Widgets
- `intl`: định dạng ngày/giờ
- Very Good Analysis + Riverpod Lint
- GitHub Actions

Các dependency chưa được dùng trong nhánh tích hợp đã được loại khỏi `pubspec.yaml` để tránh kéo plugin Android không cần thiết vào APK.

## Bắt đầu bằng Codespaces

1. Mở repository và tạo Codespace trên nhánh được phân công.
2. Dev Container tự chuẩn bị Flutter 3.47.2, Dart và JDK 17.
3. Khi terminal sẵn sàng, chạy:

```bash
bash tool/bootstrap.sh
```

Lệnh này:
- tạo Android/Web scaffold nếu còn thiếu;
- cài hai Android widget Kotlin/XML từ `platform/android_widget/`;
- chạy `flutter pub get`.

Sau khi code, chạy:

```bash
bash tool/quality.sh
```

Lệnh trên format Dart, analyze và chạy Flutter tests.

## Chạy và build

```bash
flutter run
flutter build apk --debug
flutter build apk --release
```

GitHub Actions trên `feature/btl-integration-day10` chạy format, analyze, tests, build debug/release và lưu APK release thành artifact nếu build thành công.

## Nhánh làm việc

- `main`: bản ổn định.
- `develop`: nhánh tích hợp.
- `feature/qldt-intake-khanh`
- `feature/timetable-exam-huy`
- `feature/local-data-sync-duong`
- `feature/widget-settings-dao`
- `feature/btl-integration-day10`: nhánh tích hợp cuối ngày 10.

Không push trực tiếp tính năng vào `main`. Feature branch mở PR vào `develop`; chỉ đưa `develop` lên `main` sau khi quality gate và kiểm thử thiết bị đạt.

## Contract và dữ liệu

- Model/repository trong `lib/core/contracts/` là điểm nối giữa các module.
- UI không truy cập SharedPreferences trực tiếp.
- Parser không ghi cache trực tiếp; dữ liệu đi qua `QldtImportPayload` và repository.
- Widget không giữ mật khẩu, cookie/session hoặc gọi QLĐT.
- Không commit dữ liệu sinh viên thật, token, cookie, mật khẩu, keystore hoặc database cá nhân.

Tài liệu: `docs/INTEGRATION_DAY10.md`, `docs/ARCHITECTURE.md`, `docs/WORKFLOW.md`, `LEADER_FIRST_RUN.md`.
