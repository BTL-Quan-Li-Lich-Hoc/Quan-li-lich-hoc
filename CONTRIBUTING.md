# Đóng góp

> PR ít nhưng đúng còn hơn 40 commit đổi tên biến rồi gọi đó là tái cấu trúc.

## Trước khi code

1. Đọc README của khu vực định sửa.
2. Tạo nhánh từ nhánh phát triển hiện hành.
3. Giữ thay đổi đúng phạm vi của vấn đề.
4. Dùng dữ liệu mô phỏng; không đưa dữ liệu sinh viên thật vào test.

## Nguyên tắc

- Không đổi business logic đang ổn nếu issue không yêu cầu.
- Sync lỗi phải giữ snapshot tốt gần nhất.
- Parser không được đoán mơ hồ để biến dữ liệu sai thành dữ liệu có vẻ đúng.
- Widget phải được kiểm tra theo geometry, render, thao tác và compatibility.
- Reference UI là tiêu chuẩn đầu ra; launcher lệch thì ghi nhận launcher lệch.
- Code theo feature, không theo tên thành viên.
- PR thay đổi hành vi phải có test có ý nghĩa hoặc nêu rõ cách kiểm tra thực tế.

## Chạy kiểm tra

```bash
bash tool/bootstrap.sh
bash tool/quality.sh
```

Nếu sửa native Android, chạy thêm:

```bash
cd android
./gradlew testDebugUnitTest
```

## Pull request

Mô tả vấn đề, thay đổi, cách kiểm tra và giới hạn còn lại. Che toàn bộ dữ liệu
thật trong ảnh/log. Bản fork hoặc PR không được tự nhận là bản phát hành chính
thức chỉ vì build ra được APK.

Bằng việc đóng góp, m đồng ý phát hành phần đóng góp theo GPL-3.0-only của dự án.
