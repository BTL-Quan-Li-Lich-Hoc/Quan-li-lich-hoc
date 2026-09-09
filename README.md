# Better Phenikaa Schedule

Bài tập lớn nhóm 1 — ứng dụng **thời khóa biểu & lịch thi** cho sinh viên Phenikaa University.

## Nhóm

| STT | Họ và tên | MSSV | Vai trò chính |
|---:|---|---|---|
| 1 | Đăng Văn Nam Khánh | 24100041 | QLĐT intake / session / parser |
| 2 | Trần Đỗ Quốc Huy | 21011607 | Timetable + exam UI |
| 3 | Trần Văn Dương | 24100043 | Local DB + sync |
| 4 | Nguyễn Minh Đạo | 24100222 | Lead + widget + settings |

## Mục tiêu kỹ thuật

- Flutter/Dart là stack chính.
- Đăng nhập qua luồng QLĐT/Microsoft chính thức; không tự thu mật khẩu.
- Dữ liệu lịch học/lịch thi lưu local để xem offline.
- Không dùng Firebase/backend/cloud database cho dữ liệu sinh viên.
- UI không truy vấn SQL trực tiếp; mọi truy cập dữ liệu đi qua repository contract.
- Widget chỉ đọc `WidgetSnapshot` đã được app ghi local.
- Đồng bộ lỗi phải giữ nguyên dữ liệu cũ đang dùng được.

## Stack đã chuẩn hóa

- Flutter 3.47.2 / Dart 3.13
- Riverpod + GoRouter
- Drift/SQLite
- Dio + CookieJar + InAppWebView + HTML parser
- Secure Storage + SharedPreferences
- Home Widget
- Freezed/JSON codegen
- Mocktail
- Very Good Analysis + Riverpod Lint
- Dev Container + GitHub Actions

## Bắt đầu nhanh

### Codespaces / Dev Container — khuyến nghị

1. Tạo Codespace trực tiếp trên **feature branch của mình**.
2. Chọn Dev Container `Better Phenikaa Schedule`.
3. Container tự cài Flutter 3.47.2, Dart, Android SDK, tắt telemetry, cấu hình Git safe-directory, tạo platform Android/Web nếu thiếu và chạy `flutter pub get`.
4. Sau khi terminal mở, chỉ cần chạy:

```bash
bash tool/setup.sh
```

`tool/setup.sh` sẽ tự bootstrap, format, analyze và test. Không cần tự cài Flutter/Dart/JDK hay sửa Git `safe.directory` thủ công.

Trong quá trình code, dùng:

```bash
bash tool/quality.sh
```

Lệnh này tự format code rồi chạy analyze + test.

### Máy local

Yêu cầu Flutter 3.47.2, Dart 3.13, JDK 17 và Android SDK. Sau đó chạy:

```bash
bash tool/setup.sh
```

## Nhánh làm việc

- `main`: bản ổn định.
- `develop`: nhánh tích hợp.
- `feature/qldt-intake-khanh`
- `feature/timetable-exam-huy`
- `feature/local-data-sync-duong`
- `feature/widget-settings-dao`

Không push tính năng trực tiếp vào `main`. Feature branch mở PR vào `develop`; chỉ merge `develop` vào `main` khi quality gate xanh.

## Contract freeze

Các contract trong `lib/core/contracts/` là điểm nối giữa 4 phần việc. Thay đổi model/repository contract cần Lead và thành viên đang tiêu thụ contract đó review trước khi merge.

## Lệnh chuẩn

```bash
bash tool/setup.sh
bash tool/quality.sh
dart run build_runner build --delete-conflicting-outputs
flutter run
flutter build apk --debug
```

## Quy tắc dữ liệu nhạy cảm

Tuyệt đối không commit mật khẩu, cookie/session thật, token, HTML chứa dữ liệu sinh viên, file DB thật, keystore hoặc ảnh chụp chứa thông tin tài khoản. Xem `SECURITY.md`.

Tài liệu chi tiết: `docs/ARCHITECTURE.md`, `docs/WORKFLOW.md`, `LEADER_FIRST_RUN.md`.
