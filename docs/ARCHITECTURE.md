# Architecture

## Nguyên tắc

Kiến trúc feature-first + contract-first để 4 thành viên có thể làm song song mà không khóa nhau.

```text
lib/
  app/                 # app shell, router, theme
  core/
    contracts/         # DTO + repository interface, được freeze
  shared/              # widget/helper dùng chung
  features/
    qldt_intake/
    timetable/
    exam/
    local_data_sync/
    account/
    widget/
```

## Luồng dữ liệu

```text
QLĐT authenticated WebView/session
          |
          v
     qldt_intake
          |
          v
   QldtImportPayload
          |
          v
 local_data_sync (transaction)
          |
          +----> ScheduleRepository ----> timetable UI
          |
          +----> ExamRepository --------> exam UI
          |
          +----> WidgetSnapshot --------> Android widget
```

## Ranh giới bắt buộc

1. UI không import DAO/database implementation.
2. Parser không ghi DB trực tiếp; parser trả `QldtImportPayload`.
3. Chỉ local-data layer quyết định transaction/migration/cache.
4. Widget không gọi mạng/QLĐT; app chuẩn bị `WidgetSnapshot` cho widget.
5. Logout xóa session, secure storage liên quan, dữ liệu local theo policy và snapshot widget.
6. Sync chỉ replace dữ liệu sau khi parse/validate thành công; lỗi mạng/parser không phá cache cũ.

## Contract freeze

Các kiểu sau được xem là API nội bộ giữa thành viên:

- `UserDto`
- `SemesterDto`
- `ClassDto`
- `ExamDto`
- `QldtImportPayload`
- `WidgetSnapshot`
- repository interfaces trong `repositories.dart`

Nếu cần đổi field hoặc method signature, mở PR riêng và tag Lead + thành viên bị ảnh hưởng.

## Mock-driven parallel work

TV2 và TV4 có thể tạo fake/mock implementation của repository để dựng UI/widget trước khi TV1/TV3 hoàn thành parser/DB. Khi implementation thật sẵn sàng, chỉ thay provider binding; không sửa UI để truy cập SQL/HTML trực tiếp.
