# Widget & settings — Đạo

Branch: `feature/widget-settings-dao`
Target PR: `develop`

Phạm vi BTL đã rút gọn:
- Android widget nhỏ: lớp hiện tại/sắp tới, điều hướng ngày.
- Android widget tổng quan: tối đa 4 lớp hiện tại/sắp tới trong ngày.
- Cả hai chỉ đọc snapshot local do app publish.
- Settings cơ bản và cleanup khi logout.
- Không Theme Engine, không Tiên Môn Premium, không assistant/panel.

Các class chính:
- `WidgetSnapshotSelector`: chọn lớp hiện tại/sắp tới cho widget nhỏ.
- `WidgetTimeline`: dữ liệu theo ngày cho widget nhỏ.
- `OverviewWidgetTimeline`: toàn bộ lớp theo ngày cho widget tổng quan.
- `WidgetService`: orchestration giữa repository, snapshot và Android widget.
- `WidgetPlatformBridge`: publish đồng thời dữ liệu cho hai widget.
- `ScheduleWidgetProvider`: Android widget nhỏ.
- `OverviewWidgetProvider`: Android widget tổng quan.

Quy tắc:
- Widget không gọi QLĐT/network trực tiếp.
- Sync lỗi không xóa snapshot cũ.
- Native Android nằm ở `platform/android_widget/`; `tool/bootstrap.sh` chép overlay vào Android scaffold.
