# Git workflow cho nhóm 4 người

## Nhánh

```text
main
  └─ develop
      ├─ feature/qldt-intake-khanh
      ├─ feature/timetable-exam-huy
      ├─ feature/local-data-sync-duong
      └─ feature/widget-settings-dao
```

## Luồng làm việc hằng ngày

1. Pull `develop` mới nhất.
2. Rebase/merge vào feature branch cá nhân.
3. Code theo phạm vi ownership.
4. Chạy `bash tool/quality.sh`.
5. Push feature branch và mở PR vào `develop`.
6. Sửa toàn bộ CI/review trước khi merge.
7. Cuối milestone, Lead mở PR `develop -> main`.

## Commit convention

Dùng prefix ngắn:

- `feat:` tính năng
- `fix:` sửa lỗi
- `refactor:` tái cấu trúc không đổi behavior
- `test:` test
- `docs:` tài liệu
- `chore:` tooling/dependency

Ví dụ: `feat(timetable): add weekly timeline navigation`

## Definition of Done

Một task chỉ xong khi:

- Build được.
- Format/analyze/test xanh.
- Không lộ dữ liệu nhạy cảm.
- Có loading/empty/error state nếu là UI async.
- Có xử lý offline/failure nếu chạm sync.
- Contract không bị thay đổi ngầm.
- Reviewer có cách test rõ ràng.

## Merge conflict

Không sửa file ownership của người khác chỉ để giải conflict mà chưa trao đổi. Với `lib/core/contracts/`, ưu tiên PR nhỏ, tách riêng khỏi feature lớn.
