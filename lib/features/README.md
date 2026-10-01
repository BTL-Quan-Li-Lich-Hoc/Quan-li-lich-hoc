# Feature ownership

Source được chia thành 4 mảng độc lập, giao tiếp qua `lib/core/contracts/`.

## 1. qldt_intake — Đăng Văn Nam Khánh

- Login/session QLĐT.
- Parser TraCuu, lịch học, lịch thi.
- Output: `QldtImportPayload`.
- Không ghi DB trực tiếp.

## 2. timetable + exam — Trần Đỗ Quốc Huy

- UI lịch học và lịch thi.
- Ngày/tuần, loading/empty/error.
- Chỉ dùng repository contract.

## 3. local_data_sync — Trần Văn Dương

- Drift/SQLite.
- Repository implementation.
- Offline cache + transaction replace sau sync thành công.
- Sync lỗi giữ dữ liệu cũ.

## 4. widget + account/settings — Nguyễn Minh Đạo

- Hai Android home widget.
- Widget chỉ đọc snapshot local.
- Settings/account cơ bản và integration.
- Code widget thật ở `feature/widget-settings-dao`, không đặt trên `main`.

## Base BTL không mang từ DemoF3

- Theme Engine và custom theme.
- Tiên Môn Premium/background động.
- Assistant personality/panel U1-U18.
- iOS port và debug harness.
- Các feature trang trí/experimental không phục vụ quản lý lịch học.
