# Better Phenikaa Schedule (Cooc 1.0)

Ứng dụng Flutter dành cho bài tập lớn môn **Lập trình trên thiết bị di động**, hỗ trợ sinh viên theo dõi lịch học, lịch thi, đồng bộ thông tin từ hệ thống QLĐT và xem lịch đã lưu khi offline.

> Dự án học tập của nhóm sinh viên, không phải ứng dụng chính thức của Phenikaa University.

## Chức năng

- Đăng nhập và nhận lịch học, lịch thi từ QLĐT; kiểm tra và xử lý phản hồi trước khi cập nhật lịch.
- Hiển thị lịch học theo ngày, tuần và chế độ **Scroll liên tục**; nhóm các môn theo từng ngày.
- Hiển thị lịch thi, thông tin chi tiết môn học và các trạng thái dữ liệu.
- Lưu snapshot lịch trên thiết bị, đồng bộ thủ công và cơ chế cập nhật nền trên Android.
- Hai loại Android Home Screen Widget: lịch ngắn và lịch tổng quan.
- Theme Engine, tùy chỉnh giao diện, hiệu ứng chuyển màn hình và các tiện ích thông báo.

Dữ liệu và một số chức năng phụ thuộc vào khả năng truy cập QLĐT cũng như quyền và cấu hình hệ điều hành Android.

## Công nghệ và cấu trúc

- **Flutter / Dart**: giao diện và điều hướng.
- **Kotlin / Android**: widget, tác vụ nền, thông báo và tương tác hệ điều hành.
- **flutter_inappwebview** và **html**: xử lý luồng liên quan QLĐT.
- **shared_preferences**: lưu cấu hình và dữ liệu cục bộ; **cryptography** hỗ trợ các thao tác bảo mật trong ứng dụng.

Các phần chính:

```text
lib/
  app/                         Điểm tích hợp màn hình và điều hướng
  features/
    dang_nhap_qldt/            Đăng nhập, tiếp nhận và xử lý lịch QLĐT
    lich_hoc/                  Lịch tuần và chế độ Scroll
    giao_dien/                 Theme Engine và tùy chỉnh giao diện
    dong_bo_hang_ngay/         Đồng bộ lịch
    tien_ich_lich_hoc/         Tích hợp widget
    tro_li/                    Nội dung trợ lý
  theme/                       Theme palette
android/                       Android native và Home Screen Widget
tool/                          Script chuẩn bị và kiểm tra dự án
test/                          Kiểm tra tự động
```

Hệ thống lưu dữ liệu hiện tại dựa trên các cơ chế lưu cục bộ của ứng dụng, **không nên mô tả là đã dùng Drift/SQLite** khi code chưa triển khai chúng.

## Cài đặt và kiểm tra

Yêu cầu: **Flutter 3.47.2**, **JDK 17** và Android SDK phù hợp. Project có cấu hình GitHub Codespaces.

```bash
bash tool/bootstrap.sh
bash tool/quality.sh
flutter run
```

Để tạo APK:

```bash
flutter build apk --release
```

GitHub Actions tự thực hiện kiểm tra và build APK khi cập nhật nhánh tích hợp hoặc `main`. File APK của các lần build nằm tại phần **Actions → Artifacts**.

## Thành viên

| Thành viên | Phụ trách |
|---|---|
| Đặng Văn Nam Khánh (24100041) | Tiếp nhận dữ liệu QLĐT, đăng nhập và kiểm tra dữ liệu đầu vào |
| Trần Đỗ Quốc Huy (21011607) | Parser và logic lịch học, lịch thi |
| Trần Văn Dương (24100043) | Dữ liệu cục bộ và đồng bộ |
| Nguyễn Minh Đạo (24100222) | Giao diện Flutter, Theme Engine, widget và tích hợp |

## An toàn dữ liệu

Không đưa mật khẩu, cookie phiên, token hay dữ liệu sinh viên thật lên GitHub. Cần kiểm tra trên thiết bị Android thật đối với widget, tác vụ nền, quyền hệ thống và đăng nhập QLĐT; build thành công không thay thế việc kiểm thử các chức năng này.
