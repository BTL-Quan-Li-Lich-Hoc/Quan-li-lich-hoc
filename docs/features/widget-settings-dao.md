# Widget & settings — Đạo

Branch: `feature/widget-settings-dao`
Target PR: `develop`

Phạm vi chính:
- Android home widget 4×1.
- Hiển thị lớp hiện tại/sắp tới.
- Điều hướng ngày trực tiếp trên widget bằng nút trước/sau; chạm ngày để về hôm nay.
- Tích hợp dữ liệu local qua `WidgetSnapshot` và timeline snapshot được app dựng sẵn.
- Settings, loading/empty/error và tối ưu cập nhật widget.

Các class chính:
- `WidgetSnapshotSelector`: chọn lớp hiện tại/sắp tới, dựng timeline theo ngày.
- `WidgetTimeline`, `WidgetTimelineEntry`, `WidgetViewState`: model riêng của feature widget.
- `WidgetService`: orchestration giữa schedule repository, snapshot repository và Android widget.
- `WidgetController`: state + điều hướng ngày phía Flutter.
- `WidgetPlatformBridge`, `HomeWidgetPlatformBridge`: bridge Flutter → Android Home Widget.
- `WidgetSettings`, `WidgetSettingsStore`, `WidgetSettingsController`: cấu hình widget.
- `ScheduleWidgetProvider`: Android `AppWidgetProvider`, render 4×1 và xử lý chuyển ngày.

Quy tắc:
- Widget chỉ đọc snapshot local đã được app ghi; không gọi QLĐT/network trực tiếp.
- Khi refresh lỗi, không xóa snapshot/timeline đang dùng được.
- Logout gọi `WidgetService.clear()` để xóa snapshot và dữ liệu widget.
- Native Android nằm ở `platform/android_widget/`; `tool/bootstrap.sh` tự chép overlay vào Android scaffold.
- Chạy `bash tool/quality.sh` trước khi đưa PR ra khỏi Draft.
