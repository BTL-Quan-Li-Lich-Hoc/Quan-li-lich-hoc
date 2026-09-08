# Security & privacy rules

Repo này liên quan đến phiên đăng nhập QLĐT và dữ liệu học tập cá nhân. Không dùng dữ liệu thật làm fixture công khai.

## Không được commit

- Password Microsoft/QLĐT.
- Access token, refresh token, cookie, session dump.
- File DB/cache thật từ thiết bị.
- HTML snapshot chứa tên, MSSV, email, lịch cá nhân.
- Keystore, signing key, `key.properties`.
- Screenshot/log có thông tin tài khoản thật.

## Test data

Fixture/test phải dùng dữ liệu giả rõ ràng. Nếu cần tái hiện parser, hãy sanitize toàn bộ identifier và thông tin cá nhân trước khi đưa vào repo.

## Luồng đăng nhập

Ưu tiên WebView/luồng xác thực chính thức. App không tạo form riêng để thu password. Chỉ lưu tối thiểu session cần thiết bằng secure storage/cookie storage phù hợp và phải xóa khi logout.

## Khi phát hiện lộ dữ liệu

Không chỉ xóa ở commit mới. Cần coi credential/session đã lộ là không còn an toàn, revoke/đăng xuất phiên liên quan và làm sạch lịch sử Git nếu dữ liệu nhạy cảm đã được push.
