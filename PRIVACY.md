# Quyền riêng tư

> App sinh ra để bớt phiền, không phải để tạo thêm một nơi thu gom dữ liệu.

Better Phenikaa xử lý lịch học, lịch thi và trạng thái phiên trên thiết bị để
hiển thị các chức năng người dùng yêu cầu. Dự án không vận hành backend phân tích
riêng, không thêm tracker quảng cáo và không bán dữ liệu người dùng.

## Dữ liệu được xử lý

- Phiên đăng nhập cần thiết để truy cập QLĐT.
- Dữ liệu lịch học, lịch thi và học kỳ đã đồng bộ.
- Cấu hình theme, font, widget và tùy chọn trợ lí.
- Thời điểm đồng bộ để nhắc người dùng khi dữ liệu đã cũ.

## Cách xử lý

- Dữ liệu lịch và cấu hình được lưu cục bộ trên thiết bị.
- Ảnh và font do người dùng chọn được sao chép vào vùng riêng của ứng dụng.
- Widget chỉ nhận dữ liệu cần thiết để render trên launcher.
- Đăng xuất hoặc xóa dữ liệu ứng dụng sẽ loại bỏ dữ liệu cục bộ theo cơ chế của
  hệ điều hành và ứng dụng.

## Chẩn đoán

Chế độ chẩn đoán không nằm trong APK phát hành mặc định. File chẩn đoán phải được
ẩn danh, lưu cục bộ và chỉ được chia sẻ khi người dùng chủ động chọn. Người dùng
nên kiểm tra file trước khi gửi vì website QLĐT có thể thay đổi ngoài dự kiến.

## Dịch vụ bên ngoài

Đăng nhập và lấy lịch phụ thuộc vào các trang do Microsoft và Phenikaa vận hành;
các dịch vụ đó có chính sách riêng. Better Phenikaa không kiểm soát hoạt động
của các hệ thống bên ngoài này.

Nếu phát hiện dữ liệu nhạy cảm xuất hiện trong log hoặc repo, làm theo
[`SECURITY.md`](SECURITY.md). Đừng gửi cả tài khoản thật chỉ để báo rằng một nút
không chạy.
