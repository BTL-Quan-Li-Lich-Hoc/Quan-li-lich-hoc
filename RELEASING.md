# Phát hành

> Build được APK chưa có nghĩa là đã có một bản phát hành. Zip đổi tên đẹp vẫn
> chỉ là zip đổi tên đẹp.

## Trạng thái hiện tại

Cấu hình Android hiện tại dùng debug signing cho tác vụ build release trong CI.
Vì vậy artifact CI chỉ dành cho kiểm thử. Nó chưa tạo được danh tính phát hành
độc quyền cho Better Phenikaa.

## Trước bản public đầu tiên

1. Tạo một Android upload/release keystore riêng trên máy tin cậy.
2. Giữ keystore và mật khẩu ngoài Git; sao lưu ngoại tuyến ít nhất hai bản.
3. Đưa credential ký vào secret của môi trường phát hành.
4. Cấu hình Gradle chỉ dùng khóa đó trong luồng phát hành chính thức.
5. Công bố SHA-256 certificate fingerprint tại trang release.
6. Gắn tag bất biến cho commit phát hành.
7. Phát hành APK cùng checksum SHA-256 và changelog.
8. Cài thử bản nâng cấp được ký bằng đúng khóa trước khi công bố.

## Quy tắc

- Không upload keystore vào artifact CI, issue, release hoặc Library công khai.
- Không dùng debug key để tự nhận một APK là bản chính thức.
- Không thay khóa giữa các bản nếu vẫn muốn Android chấp nhận cập nhật.
- Mất khóa có thể đồng nghĩa mất khả năng cập nhật cùng application ID.
- Fork công khai phải đổi package ID và nhận diện theo `TRADEMARK.md`.

## Cài đặt repository

Nên bật trên nhánh ổn định:

- Require pull request trước khi merge.
- Require CI status checks.
- Chặn force push và xóa nhánh.
- Require review từ CODEOWNERS cho phần nhạy cảm.
- Bật secret scanning, push protection và private vulnerability reporting nếu
  gói GitHub của repository hỗ trợ.

Mấy khóa này không làm code thông minh hơn. Chúng chỉ ngăn một cú bấm lúc buồn
ngủ biến nhánh ổn định thành hiện trường.
