# Local data sync

Phần cache local hiện tại dùng `LocalScheduleStore` và `LocalCacheCodec`.

## Trách nhiệm

- Lưu/đọc `QldtImportPayload` dạng JSON trong SharedPreferences.
- Cung cấp `ScheduleRepository` cho lịch học.
- Cung cấp `ExamRepository` cho lịch thi.
- Lưu/đọc `WidgetSnapshot` local.
- Giữ dữ liệu cache cũ nếu chưa có payload mới hợp lệ.

## Ranh giới

- Không đặt UI trong thư mục này.
- Không gọi QLĐT hoặc WebView từ local store.
- Parser trả `QldtImportPayload`; store chỉ nhận payload qua repository contract.
- Android widget không đọc trực tiếp cache codec; Flutter publish snapshot/timeline qua `home_widget`.

## Giới hạn hiện tại

Đây là JSON cache dùng SharedPreferences, chưa phải Drift/SQLite database và chưa có live QLĐT sync được nối vào app.
