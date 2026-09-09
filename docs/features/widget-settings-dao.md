# Widget & settings — Đạo

Branch: `feature/widget-settings-dao`
Target PR: `develop`

Phạm vi chính:
- Android home widget 4×1.
- Hiển thị lớp hiện tại/sắp tới.
- Điều hướng ngày trên widget.
- Tích hợp dữ liệu local qua `WidgetSnapshot`.
- Settings, loading/empty/error và tối ưu cập nhật widget.

Quy tắc:
- Widget chỉ đọc snapshot local đã được app ghi.
- Chạy `bash tool/quality.sh` trước khi đưa PR ra khỏi Draft.
