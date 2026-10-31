# Architecture

## Nguyên tắc

Kiến trúc feature-first + contract-first. UI, parser, local cache và Android widget giao tiếp qua model/repository contract; không đọc trực tiếp cấu trúc nội bộ của nhau.

```text
lib/
  app/
    schedule_coordinator.dart
  core/contracts/
    models.dart
    repositories.dart
  features/
    qldt_intake/       # raw JSON boundary và parser đầu vào
    timetable/         # parser, query và UI lịch học
    exam/              # UI lịch thi
    local_data_sync/   # LocalScheduleStore + JSON cache
    widget/            # snapshot selector + publisher
platform/android_widget/
  app/src/main/
    kotlin/            # AppWidgetProvider
    res/               # Manifest, widget info và RemoteViews layout
```

## Luồng dữ liệu trong nhánh tích hợp

```text
LocalScheduleStore (SharedPreferences JSON cache)
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

QLĐT raw JSON boundary và parser tạo/chuẩn hóa `QldtImportPayload`. Khi có QLĐT repository thực tế, payload được ghi qua repository contract; parser không ghi cache trực tiếp.

## Local cache

- `LocalScheduleStore` hiện lưu payload JSON trong SharedPreferences.
- Store triển khai `ScheduleRepository`, `ExamRepository` và `WidgetSnapshotRepository`.
- UI chỉ đọc qua contract; không import SharedPreferences hoặc cache codec.
- Nếu cache không có dữ liệu, UI hiển thị empty state; không tự tạo lịch mẫu.
- Đây là cache JSON local, chưa phải triển khai Drift/SQLite.

## Android widgets

- `WidgetService` đọc lịch qua `ScheduleRepository`, tạo timeline và publish bằng `home_widget`.
- `ScheduleWidgetProvider` đọc `widgetTimeline`.
- `OverviewWidgetProvider` đọc `widgetOverviewTimeline`.
- Kotlin chỉ đọc SharedPreferences do app publish; không có QLĐT client, WebView, HTTP request, mật khẩu hoặc cookie/session.
- Widget timeline luôn giữ cả ngày hiện tại và ngày người dùng đang chọn.

## Khởi tạo Android

Flutter 3.47.2 tạo Android scaffold trong `tool/bootstrap.sh`. Source Kotlin/XML được lưu tại `platform/android_widget/` và cài vào scaffold bằng `tool/install_android_widgets.sh`. Không cần commit thư mục Android sinh tự động.

## Contract freeze

Các model và repository trong `lib/core/contracts/` là API nội bộ giữa các module:

- `UserDto`
- `SemesterDto`
- `ClassDto`
- `ExamDto`
- `QldtImportPayload`
- `WidgetSnapshot`
- `QldtIntakeRepository`
- `ScheduleRepository`
- `ExamRepository`
- `WidgetSnapshotRepository`

Thay đổi field hoặc method signature cần PR riêng và review từ consumer liên quan.

## Giới hạn tích hợp

- Chưa nối đăng nhập/session QLĐT thực tế vào app.
- Chưa có luồng sync live để tự nạp cache từ QLĐT.
- Cần cài APK trên thiết bị Android và thêm hai widget từ launcher để xác minh hiển thị thực tế.
