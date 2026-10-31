# Android home widgets

Hai Android widget dùng `home_widget` để nhận snapshot local do Flutter publish.

- `ScheduleWidgetProvider`: một lớp hiện tại/sắp tới.
- `OverviewWidgetProvider`: tối đa bốn lớp trong ngày.
- Dữ liệu đầu vào: `widgetTimeline` và `widgetOverviewTimeline`.
- Kotlin chỉ đọc SharedPreferences qua `HomeWidgetProvider`; không gọi QLĐT, HTTP hoặc WebView.

Mã Kotlin/XML nằm trong `platform/android_widget/` và được cài vào Android scaffold bởi `tool/install_android_widgets.sh`.
