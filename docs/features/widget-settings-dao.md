# Giao diện lịch, widget và tích hợp — Đạo

Branch: `feature/widget-settings-dao`
Target PR: `develop`

## Phạm vi giao diện Flutter

- Lịch học có chế độ **Ngày/Tuần**, chuyển ngày/tuần trước-sau và nút về hôm nay.
- Mỗi buổi học hiển thị môn, mã môn, phòng, giảng viên và thời gian.
- Lịch thi hiển thị theo thời gian tăng dần, gồm ngày thi, phòng và ca thi.
- Có trạng thái loading, empty và error riêng trên màn hình; lỗi có nút thử lại.
- Điều hướng dưới cùng giữa Lịch học và Lịch thi.
- Hai màn hình dùng chung `ScheduleCoordinator`, không tự đọc HTML hoặc SQL.

## Tích hợp dữ liệu

- `ScheduleCoordinator` đọc dữ liệu qua `ScheduleRepository.watchRange` và `ExamRepository.watchAll`.
- Khi module QLĐT được nối, `syncFromQldt()` gọi `QldtIntakeRepository.sync()`, lưu kết quả qua hai repository rồi cập nhật giao diện.
- Khi chưa gắn implementation của các repository, UI hiển thị trạng thái chưa có dữ liệu; không tự tạo lịch giả.
- Contract nằm trong `lib/core/contracts/`; không đổi model/interface trong phần giao diện này.

## Widget Android

- Android widget nhỏ: lớp hiện tại/sắp tới, điều hướng ngày.
- Android widget tổng quan: danh sách lớp trong ngày.
- Cả hai chỉ đọc snapshot local do app publish.
- Settings cơ bản và cleanup khi logout.
- Không Theme Engine, không Tiên Môn Premium, không assistant/panel.

## Các class chính

- `TimetableScreen`: lịch học Ngày/Tuần.
- `ExamScreen`: danh sách lịch thi.
- `ScheduleStatePanel`: empty/error state dùng chung.
- `ScheduleCoordinator`: điều phối trạng thái và repository.
- `WidgetSnapshotSelector`: chọn lớp hiện tại/sắp tới cho widget nhỏ.
- `WidgetTimeline`: dữ liệu theo ngày cho widget nhỏ.
- `OverviewWidgetTimeline`: toàn bộ lớp theo ngày cho widget tổng quan.
- `WidgetService`: orchestration giữa repository, snapshot và Android widget.
- `WidgetPlatformBridge`: publish dữ liệu cho hai widget.
- `ScheduleWidgetProvider` và `OverviewWidgetProvider`: Android widget native.

## Kiểm tra

Trong Codespaces:

```bash
bash tool/quality.sh
flutter build apk --debug
```

Các test giao diện/điều phối hiện bao phủ:
- Khởi động app và chuyển giữa chế độ lịch Ngày/Tuần.
- Trạng thái trống khi chưa kết nối repository.
- Chuẩn hóa ngày được chọn.
- Nhận payload theo các contract hiện có.

GitHub Actions trên nhánh này chạy format, analyzer, test và build APK debug. Bản build chỉ được coi là đạt khi workflow thực tế xanh.

## Quy tắc

- Widget không gọi QLĐT/network trực tiếp.
- Sync lỗi không xóa snapshot cũ.
- Native Android nằm ở `platform/android_widget/`; `tool/bootstrap.sh` chép overlay vào Android scaffold.
