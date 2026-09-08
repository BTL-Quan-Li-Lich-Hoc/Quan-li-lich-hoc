# Feature ownership

Mỗi thành viên phát triển trong vùng feature của mình, giao tiếp qua `lib/core/contracts/`.

## 1. qldt_intake — Đăng Văn Nam Khánh

- QLĐT/Microsoft authenticated flow.
- Cookie/session lifecycle.
- Parse timetable/exam HTML/DOM thành `QldtImportPayload`.
- Không thu hoặc lưu password.

## 2. timetable + exam — Trần Đỗ Quốc Huy

- Timeline lịch học/lịch thi.
- Chuyển ngày/tuần, chi tiết môn, empty/error/loading state.
- Dùng repository/mock; không query Drift/SQL trực tiếp.

## 3. local_data_sync — Trần Văn Dương

- Drift schema, DAO, migration.
- Repository implementation.
- Offline cache và replace transaction sau sync thành công.
- Sync lỗi phải giữ dữ liệu cũ.

## 4. widget + settings — Nguyễn Minh Đạo

- Home-screen widget nhỏ, ưu tiên 1x4/2x2 tùy launcher.
- Nội dung tối giản: môn, phòng, thời gian start → end.
- Widget chỉ đọc `WidgetSnapshot`; không tự gọi QLĐT.
- Settings, logout cleanup, loading/empty/error và tối ưu pin/RAM.

Tạo thư mục con khi bắt đầu feature, ví dụ `lib/features/qldt_intake/`.
