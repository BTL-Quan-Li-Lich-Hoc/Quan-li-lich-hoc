# Tích hợp ngày 10

## Phạm vi

- Flutter: lịch học theo Ngày/Tuần và danh sách lịch thi.
- Trạng thái: loading, empty, error và thao tác tải lại.
- Dữ liệu: đọc qua repository contract; cache local dùng được khi offline.
- Android: hai home widget native, một widget buổi học và một widget tổng quan ngày.
- Widget chỉ đọc snapshot đã publish vào SharedPreferences bằng `home_widget`; không gọi QLĐT, HTTP hoặc WebView.

## Luồng dữ liệu

```text
LocalScheduleStore (cache)
        |
        +--> ScheduleRepository --> ScheduleCoordinator --> Lịch Ngày/Tuần
        |
        +--> ExamRepository -------------------------------> Lịch thi
        |
        +--> WidgetService --> HomeWidget SharedPreferences
                                  |
                                  +--> ScheduleWidgetProvider
                                  +--> OverviewWidgetProvider
```

## Hai Android widget

- `ScheduleWidgetProvider`: đọc `widgetTimeline`, hiển thị lớp hiện tại/sắp tới.
- `OverviewWidgetProvider`: đọc `widgetOverviewTimeline`, hiển thị tối đa bốn lớp trong ngày.
- Kotlin chỉ đọc SharedPreferences qua `HomeWidgetProvider`; không có QLĐT client, credential hay request mạng.

## Android scaffold

Flutter 3.47.2 sinh Android scaffold trong `tool/bootstrap.sh`. Mã Kotlin/XML nằm tại `platform/android_widget/` và được cài vào scaffold bởi `tool/install_android_widgets.sh`.

## Kiểm thử

- Parser và chuẩn hóa dữ liệu lịch.
- ScheduleCoordinator và giao diện.
- Cache local: ghi/đọc lịch học, lịch thi và snapshot.
- WidgetSnapshotSelector: chọn lớp hiện tại/sắp tới.
- GitHub Actions: format, analyze, Flutter tests, APK debug và release.

## Giới hạn

- QLĐT intake hiện có raw JSON boundary và parser; chưa có repository đăng nhập/session QLĐT thực tế được nối vào app.
- Không tự chèn dữ liệu lịch giả vào cache.
- Cần cài APK lên thiết bị Android và thêm cả hai widget từ launcher để xác minh giao diện thực tế.

## CI trên nhánh tích hợp

Workflow `.github/workflows/day10-integration.yml` chạy trên nhánh `feature/btl-integration-day10`: chuẩn hóa Dart, phân tích mã nguồn, chạy Flutter tests, build APK debug/release và lưu APK release thành artifact `lich-hoc-apk-ngay-10`.
