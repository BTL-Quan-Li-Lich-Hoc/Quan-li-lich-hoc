# Leader first run

## 1. Mở môi trường chuẩn

Khuyến nghị dùng GitHub Codespaces / Dev Container. Container pin Flutter 3.47.2, Dart 3.13 và JDK 17. Sau khi tạo Codespace, `postCreateCommand` tự chạy `tool/bootstrap.sh`.

Nếu cần chạy lại thủ công:

```bash
bash tool/bootstrap.sh
```

Bootstrap:
- tạo Android/Web scaffold nếu còn thiếu;
- cài Kotlin/XML cho hai Android home widgets từ `platform/android_widget/`;
- chạy `flutter pub get`.

Không cần tự cài Flutter trên máy host khi dùng Codespaces.

## 2. Kiểm tra trước khi push

```bash
bash tool/quality.sh
flutter build apk --debug
```

`tool/quality.sh` chạy Dart format, Flutter analyze và Flutter tests.

## 3. Quy trình nhánh

- Thành viên làm trên feature branch đã phân công.
- Push branch cá nhân và mở PR vào `develop`.
- Bản tích hợp cuối ngày dùng `feature/btl-integration-day10`.
- Không push trực tiếp hoặc force-push vào `main`.
- Chỉ merge PR khi format, analyze, tests và APK build đạt.

## 4. Commit

Commit message ngắn, tiếng Việt, trung tính, chỉ mô tả thay đổi; không ghi tên, username, chữ ký hoặc lời nhắn cá nhân.

Ví dụ: `Thêm giao diện lịch ngày và tuần`.

## 5. Android widget

Mã Kotlin/XML gốc nằm trong `platform/android_widget/`. Thư mục `android/` được Flutter tạo tại môi trường build; không commit scaffold sinh tự động. Hai provider chỉ đọc snapshot local do Flutter publish qua `home_widget`, không gọi QLĐT.

## 6. Kiểm thử thiết bị

GitHub Actions xác nhận format, analyze, tests và build APK. Vẫn cần cài APK lên điện thoại Android, thêm hai widget từ launcher và kiểm tra hiển thị/kích thước thực tế. Flutter Web preview không thay thế bước này.
