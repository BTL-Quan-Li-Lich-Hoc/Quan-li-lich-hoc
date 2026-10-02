# Better Phenikaa Schedule

Bài tập lớn môn **Lập trình trên thiết bị di động** — ứng dụng Android hỗ trợ sinh viên Phenikaa theo dõi **lịch học, lịch thi và dữ liệu học tập cá nhân** ngay trên điện thoại.

> Đây là sản phẩm học tập của nhóm, không phải ứng dụng chính thức của Phenikaa University.

## 1. Mục tiêu bài tập lớn

Ứng dụng tập trung vào các nội dung đúng với môn Lập trình trên thiết bị di động:

- Xây dựng ứng dụng mobile bằng Flutter/Dart.
- Đăng nhập và lấy dữ liệu từ hệ thống QLĐT.
- Hiển thị lịch học theo ngày/tuần và lịch thi.
- Lưu dữ liệu local để vẫn xem được khi không có mạng.
- Đồng bộ dữ liệu mới mà không làm mất cache cũ khi lỗi.
- Sử dụng Android Home Screen Widget.
- Xử lý trạng thái ứng dụng, dữ liệu nền, SharedPreferences/SQLite và tương tác native Android.
- Tổ chức code để phần giao diện và phần xử lý logic có thể phát triển độc lập.

## 2. Chức năng chính

- Đăng nhập QLĐT.
- Lấy học kỳ hiện tại, danh sách môn, lịch học và lịch thi.
- Xem lịch học theo ngày và tuần.
- Xem lịch thi và các ca thi sắp tới.
- Đồng bộ lại dữ liệu khi người dùng yêu cầu.
- Xem dữ liệu đã lưu khi offline.
- Hai Android Widget:
  - Widget nhỏ: hiển thị môn hiện tại/sắp tới và chuyển ngày.
  - Widget tổng quan: hiển thị các môn trong ngày.
- Màn hình tài khoản và cài đặt cơ bản.

BTL **không mang Theme Engine, Tiên Môn Premium, assistant personality/panel hoặc các phần thử nghiệm của DemoF3**.

## 3. Phân công nhóm

| Thành viên | Phần phụ trách | Nội dung chính |
|---|---|---|
| **Đăng Văn Nam Khánh — 24100041** | **Đăng nhập & lấy dữ liệu QLĐT** | WebView/Microsoft login, cookie/session, request QLĐT, lấy dữ liệu thô, kiểm tra session, retry/timeout và xử lý lỗi kết nối |
| **Trần Đỗ Quốc Huy — 21011607** | **Parser & logic lịch học/lịch thi** | Parse dữ liệu QLĐT, chuẩn hóa môn học, ghép lịch học/lịch thi, lọc theo học kỳ, sắp xếp theo thời gian, xác định môn hiện tại/sắp tới và logic nghiệp vụ lịch |
| **Trần Văn Dương — 24100043** | **Local DB & đồng bộ dữ liệu** | Drift/SQLite, repository implementation, lưu cache offline, transaction cập nhật dữ liệu, so sánh thay đổi, giữ dữ liệu cũ khi sync thất bại và chuẩn bị snapshot local cho widget |
| **Nguyễn Minh Đạo — 24100222** | **Lead + toàn bộ UI/UX + Widget + tích hợp** | App shell, navigation, toàn bộ màn hình Flutter, lịch ngày/tuần, lịch thi, login/account/settings UI, loading/empty/error state, hai Android Widget và tích hợp các phần logic của nhóm |

### Nguyên tắc phân chia

Ba thành viên **Khánh, Huy, Dương tập trung vào logic và dữ liệu**, không phải dựng giao diện.

**Đạo phụ trách toàn bộ UI/UX và tích hợp cuối**, để giao diện thống nhất và tránh nhiều người sửa cùng một màn hình.

Luồng dữ liệu chung:

```text
QLĐT
  ↓
Khánh: login / session / lấy dữ liệu thô
  ↓
Huy: parser / chuẩn hóa / logic lịch
  ↓
Dương: local DB / sync / offline cache
  ↓
Đạo: UI Flutter + 2 Android Widget
```

## 4. Cấu trúc source

```text
lib/
  app/                  # app shell, router, navigation
  core/
    contracts/          # model + repository interface dùng chung
  features/
    qldt_intake/        # Khánh
    timetable/          # UI do Đạo, logic lịch do Huy cung cấp qua contract
    exam/               # UI do Đạo, logic lịch thi do Huy cung cấp qua contract
    local_data_sync/    # Dương
    account/            # Đạo
    widget/             # Đạo
```

Các phần logic giao tiếp với UI thông qua model/repository trong `lib/core/contracts/`. UI không đọc trực tiếp SQL hoặc HTML QLĐT.

## 5. Luồng dữ liệu

```text
QLĐT authenticated session
        ↓
Raw QLĐT data
        ↓
Parser + validation
        ↓
QldtImportPayload
        ↓
Drift / SQLite
        ↓
Repository
   ┌────┼────────┐
   ↓    ↓        ↓
Lịch học  Lịch thi  WidgetSnapshot
   ↓       ↓          ↓
Flutter UI        Android Widget
```

## 6. Công nghệ sử dụng

- **Flutter 3.47.2 / Dart 3.13**
- **Riverpod** — quản lý state
- **GoRouter** — điều hướng
- **Drift / SQLite** — lưu dữ liệu local
- **Dio + CookieJar** — request/session
- **InAppWebView** — đăng nhập QLĐT
- **HTML parser** — xử lý dữ liệu web
- **SharedPreferences / Secure Storage** — lưu cấu hình và session cần thiết
- **Home Widget + Android native Kotlin/XML** — Android Home Screen Widget

## 7. Nhánh làm việc

- `main` — khung chung và bản tích hợp ổn định.
- `develop` — tích hợp trước khi đưa vào main.
- `feature/qldt-intake-khanh` — đăng nhập/session/lấy dữ liệu.
- `feature/timetable-exam-huy` — parser + logic lịch học/lịch thi.
- `feature/local-data-sync-duong` — DB + sync + offline.
- `feature/widget-settings-dao` — UI integration + hai widget.

Mỗi người làm phần logic của mình trên branch riêng. Khi interface/model dùng chung cần thay đổi thì phải báo trước để tránh làm hỏng phần đang được người khác sử dụng.

## 8. Quy tắc dữ liệu

- Không commit mật khẩu, token, cookie/session thật hoặc dữ liệu sinh viên thật.
- Không lưu mật khẩu người dùng dưới dạng plain text.
- Dữ liệu lịch học/lịch thi được ưu tiên lưu local.
- Nếu sync lỗi, dữ liệu cũ vẫn phải sử dụng được.
- Widget không tự truy cập QLĐT; widget chỉ đọc snapshot local do app chuẩn bị.

## 9. Chạy project

Yêu cầu:

- Flutter 3.47.2
- Dart 3.13
- JDK 17
- Android SDK

```bash
bash tool/bootstrap.sh
flutter pub get
flutter run
```

Kiểm tra project:

```bash
bash tool/quality.sh
flutter build apk --debug
```

## 10. Phạm vi sản phẩm cuối

Sản phẩm cuối cần chứng minh được các nội dung chính của lập trình mobile:

- giao diện và navigation hoàn chỉnh;
- gọi và xử lý dữ liệu từ nguồn ngoài;
- lưu trữ local;
- offline;
- state management;
- xử lý lỗi;
- native Android integration;
- Android Home Screen Widget;
- build APK chạy được trên thiết bị thật.
