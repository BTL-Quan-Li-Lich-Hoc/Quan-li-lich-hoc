# Local data & sync — Dương

Branch: `feature/local-data-sync-duong`
Target PR: `develop`

Phạm vi chính:
- Drift/SQLite local database.
- Entity, DAO và repository.
- Cache/offline query.
- Đồng bộ dữ liệu an toàn, lỗi sync không xóa dữ liệu cũ đang dùng được.

Quy tắc:
- UI không truy vấn SQL trực tiếp.
- Chạy `bash tool/quality.sh` trước khi đưa PR ra khỏi Draft.
