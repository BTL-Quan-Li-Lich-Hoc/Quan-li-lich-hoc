# Better Phenikaa Web Bridge - QLĐT Beta

> Đăng nhập một lần cho tử tế, đừng bắt người dùng làm lễ trước QLĐT mỗi ngày.

Chrome extension cục bộ dùng cho **Better Phenikaa App trên web** để đăng nhập và đọc lịch từ QLĐT beta mà không thu mật khẩu trong app.

QLĐT sử dụng đúng địa chỉ:

`https://qldtbeta.phenikaa-uni.edu.vn/`

## Cài một lần

1. Giải nén ZIP bridge.
2. Mở `chrome://extensions`.
3. Xóa bản Better Phenikaa Web Bridge cũ nếu có.
4. Bật **Developer mode**.
5. Chọn **Load unpacked**.
6. Chọn thư mục có `manifest.json`.
7. Reload `https://lonelychromosome.github.io/demoD/`.

## Luồng đăng nhập tự động

1. Trong Better Phenikaa App, bấm **Đăng nhập QLĐT (Microsoft)**.
2. Bridge tự mở tab `qldtbeta.phenikaa-uni.edu.vn`.
3. Bạn đăng nhập Microsoft trên trang chính thức.
4. Khi QLĐT tải xong phiên người dùng, bridge tự lấy tên + lịch học/lịch thi.
5. Tab QLĐT tự đóng.
6. Trình duyệt tự quay về Better Phenikaa App và app đăng nhập luôn, không cần bấm xác nhận hay Đồng bộ lần hai.

Nếu đã có phiên QLĐT hợp lệ, bước 3 có thể được bỏ qua và dữ liệu được lấy ngay.

## Riêng tư

Extension không có form mật khẩu và không gửi password/cookie/token sang GitHub Pages hay server trung gian. Nó chỉ chạy yêu cầu lấy lịch trong context của tab QLĐT đã đăng nhập và chuyển kết quả lịch + tên hiển thị về Better Phenikaa App trong trình duyệt cục bộ.
