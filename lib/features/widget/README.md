# Widget feature

Phần widget của Đạo chỉ đọc dữ liệu local qua repository contract, không gọi QLĐT hay network trực tiếp.

Các lớp chính:

- `WidgetSnapshotSelector`: chọn lớp hiện tại/sắp tới và dựng timeline snapshot theo ngày.
- `WidgetService`: đọc `ScheduleRepository`, ghi `WidgetSnapshotRepository`, giữ snapshot cũ khi refresh lỗi.
- `WidgetPlatformBridge` / `HomeWidgetPlatformBridge`: publish snapshot local sang Android Home Widget.
- `WidgetController`: state loading/ready/empty/error và điều hướng ngày trong app.
- `WidgetSettings`, `WidgetSettingsStore`, `WidgetSettingsController`: cấu hình hiển thị và auto refresh.
- `ScheduleWidgetProvider` (Android): render widget 4×1, chuyển ngày bằng nút trước/sau, chạm ngày để về hôm nay.

Native Android được giữ dưới `platform/android_widget/` và được `tool/bootstrap.sh` chép vào Android scaffold khi setup.
