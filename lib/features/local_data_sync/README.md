# local_data_sync

Ownership: Trần Văn Dương.

Phạm vi:
- Drift/SQLite schema, DAO, migration.
- Implementation cho ScheduleRepository, ExamRepository và WidgetSnapshotRepository.
- Transaction replace dữ liệu sau khi QLĐT parse/validate thành công.
- Offline cache; sync lỗi không được phá dữ liệu cũ.

Không đặt UI hoặc parser QLĐT trong thư mục này.
