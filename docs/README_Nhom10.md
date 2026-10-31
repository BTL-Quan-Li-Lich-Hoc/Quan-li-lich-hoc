# 📱 Better Phenikaa - Dự Án Nhóm 10

## 📝 Tổng quan đề tài

**Better Phenikaa** là ứng dụng di động hỗ trợ sinh viên Trường Đại học Phenikaa theo dõi lịch học, lịch thi và các thông tin học tập cần thiết ngay trên thiết bị Android.

Ứng dụng được phát triển dựa trên nhu cầu thực tế: thay vì phải thường xuyên mở hệ thống QLĐT, đăng nhập và thực hiện nhiều thao tác để kiểm tra lịch, Better Phenikaa đưa các thông tin quan trọng ra giao diện ứng dụng và màn hình chính thông qua widget.

Dự án tập trung vào ba mục tiêu chính:

- Giảm số thao tác cần thiết khi kiểm tra lịch học và lịch thi.
- Duy trì dữ liệu học tập gần nhất trên thiết bị để người dùng vẫn có thể xem lịch khi chưa thực hiện đồng bộ mới.
- Tạo trải nghiệm sử dụng trực quan, thuận tiện và phù hợp với thói quen sử dụng điện thoại hằng ngày của sinh viên.

> [!IMPORTANT]
> **Better Phenikaa là dự án độc lập do sinh viên phát triển, không phải ứng dụng chính thức của Trường Đại học Phenikaa.**
> Dự án không đại diện, không được tài trợ và không được quản lý bởi nhà trường.

---

## 🎓 Vai trò trong Bài tập lớn Kỹ thuật phần mềm

Better Phenikaa được sử dụng làm **Bài tập lớn môn Kỹ thuật phần mềm**, với mục tiêu vận dụng các nội dung đã học vào một sản phẩm có quy mô và luồng xử lý thực tế. Dự án thể hiện quá trình từ xác định yêu cầu, phân chia chức năng, thiết kế cấu trúc dữ liệu và kiến trúc phần mềm, triển khai các module, tích hợp hệ thống bên ngoài, quản lý mã nguồn, kiểm thử và hoàn thiện sản phẩm theo nhóm.

---

## 💡 Lý do lựa chọn đề tài

Trong quá trình sử dụng hệ thống QLĐT, sinh viên thường phải đăng nhập và thực hiện nhiều bước chỉ để kiểm tra những thông tin lặp lại hằng ngày như hôm nay học môn gì, học ở đâu hoặc sắp có lịch thi nào.

Nhóm lựa chọn xây dựng Better Phenikaa nhằm giải quyết trực tiếp vấn đề đó bằng một ứng dụng di động có khả năng:

- truy cập dữ liệu học tập từ QLĐT;
- tổ chức lại dữ liệu theo học kỳ, môn học, lịch học và lịch thi;
- lưu dữ liệu cục bộ trên thiết bị;
- hiển thị lịch trực quan trong ứng dụng;
- đưa thông tin cần thiết ra Android Home Screen Widget;
- hỗ trợ nhắc lịch thi và cảnh báo khi dữ liệu đã lâu chưa được cập nhật.

Bên cạnh giá trị sử dụng thực tế, đề tài còn giúp nhóm tiếp cận nhiều vấn đề kỹ thuật thường gặp trong một ứng dụng hoàn chỉnh như WebView, xử lý dữ liệu, đồng bộ trạng thái, lưu trữ cục bộ, widget Android, notification, theme, responsive UI và kiểm thử trên thiết bị thật.

---

## 🚀 Chức năng chính

| Chức năng | Mô tả |
| :--- | :--- |
| **Đăng nhập QLĐT** | Cho phép người dùng truy cập hệ thống QLĐT thông qua WebView trong ứng dụng. |
| **Tiếp nhận dữ liệu học tập** | Xử lý dữ liệu lấy từ phiên làm việc QLĐT và chuyển thành dữ liệu mà ứng dụng có thể sử dụng. |
| **Quản lý học kỳ và môn học** | Tổ chức dữ liệu theo học kỳ hiện tại, môn học và các lịch liên quan. |
| **Lịch học** | Hiển thị lịch học theo ngày và tuần, giúp người dùng theo dõi nhanh các buổi học sắp tới. |
| **Lịch thi** | Hiển thị các ca thi và hỗ trợ người dùng theo dõi những kỳ thi sắp diễn ra. |
| **Đồng bộ chủ động** | Người dùng chủ động yêu cầu cập nhật dữ liệu khi cần; dữ liệu hợp lệ gần nhất được giữ lại nếu lần đồng bộ mới gặp lỗi. |
| **Widget Android** | Hiển thị nhanh lịch học và lịch thi ngay trên màn hình chính mà không cần mở ứng dụng. |
| **Thông báo và nhắc lịch** | Hỗ trợ nhắc lịch thi, cảnh báo dữ liệu đã lâu chưa đồng bộ và tập trung thông báo trong ứng dụng. |
| **Theme giao diện** | Hỗ trợ nhiều giao diện khác nhau nhằm tăng khả năng cá nhân hóa trải nghiệm sử dụng. |
| **Lưu trữ cục bộ** | Lưu dữ liệu và thiết lập cần thiết trực tiếp trên thiết bị để giảm phụ thuộc vào kết nối liên tục. |

---

## 🧩 Kiến trúc dữ liệu

Dữ liệu học tập được tổ chức theo hướng tách biệt nguồn dữ liệu và chỉ hợp nhất sau khi đã xác định đúng học kỳ và môn học.

Mô hình dữ liệu chính có thể khái quát như sau:

```text
CurrentSemester
└── Subjects[]
    ├── subjectId
    ├── name
    ├── studySchedules[]
    └── examSchedules[]
```

Ba nhóm dữ liệu chính gồm:

1. **Thông tin đăng ký môn học**: dùng để xác định học kỳ và danh sách môn hiện tại.
2. **Lịch học**: chứa các buổi học tương ứng với từng môn.
3. **Lịch thi**: chứa các ca thi tương ứng với từng môn.

Sau khi xử lý, dữ liệu được chuẩn hóa và lưu thành snapshot cục bộ để ứng dụng và widget cùng sử dụng.

---

## 🔄 Cơ chế đồng bộ

Better Phenikaa sử dụng cơ chế **đồng bộ chủ động**: người dùng lựa chọn thời điểm cần cập nhật thông tin mới từ QLĐT.

Quá trình đồng bộ thực hiện theo luồng:

```text
Đăng nhập QLĐT
        ↓
Xác định học kỳ hiện tại
        ↓
Lấy danh sách môn
        ↓
Lấy lịch học và lịch thi
        ↓
Chuẩn hóa và ghép dữ liệu
        ↓
Lưu snapshot cục bộ
        ↓
Cập nhật giao diện và widget
```

Một nguyên tắc quan trọng của hệ thống là **không xóa dữ liệu tốt đang có chỉ vì một lần đồng bộ mới thất bại**. Nếu QLĐT không phản hồi, phiên đăng nhập hết hạn hoặc quá trình lấy dữ liệu gặp lỗi, ứng dụng vẫn giữ snapshot hợp lệ gần nhất để người dùng tiếp tục xem lịch.

---

## 📱 Android Widget

Widget là một thành phần quan trọng của Better Phenikaa, giúp người dùng xem thông tin mà không cần mở ứng dụng.

Ứng dụng hỗ trợ các cách hiển thị như:

- lịch học gần nhất;
- lịch thi sắp tới;
- chuyển ngày;
- chuyển giữa chế độ lịch học và lịch thi;
- trạng thái đồng bộ;
- làm mới nội dung sau khi dữ liệu thay đổi.

Widget được thiết kế để hoạt động cùng nguồn dữ liệu cục bộ của ứng dụng, nhờ đó việc xem lịch trên màn hình chính không yêu cầu truy cập QLĐT mỗi lần hiển thị.

---

## 🎨 Giao diện và cá nhân hóa

Better Phenikaa không chỉ tập trung vào khả năng lấy và hiển thị dữ liệu mà còn chú trọng trải nghiệm sử dụng hằng ngày.

Ứng dụng hỗ trợ:

- giao diện lịch theo ngày và tuần;
- nhiều theme dựng sẵn;
- thay đổi màu sắc và phong cách hiển thị;
- font tích hợp hoặc font do người dùng lựa chọn;
- animation khi chuyển trạng thái;
- thiết kế thích ứng với nhiều kích thước màn hình;
- giao diện widget đồng bộ với phong cách của ứng dụng.

---

## 🔔 Thông báo

Hệ thống thông báo hỗ trợ người dùng theo dõi các thông tin quan trọng mà không cần kiểm tra ứng dụng liên tục.

Một số loại thông báo chính:

- nhắc lịch thi sắp tới;
- thay đổi liên quan đến dữ liệu lịch;
- nhắc người dùng khi dữ liệu đã lâu chưa được đồng bộ;
- thông báo trạng thái cần người dùng xử lý, ví dụ khi phiên đăng nhập không còn hợp lệ.

Ứng dụng đồng thời có khu vực tập trung thông báo để người dùng có thể xem lại các sự kiện quan trọng.

---

## 🔐 Bảo mật & quyền riêng tư dữ liệu

Better Phenikaa được xây dựng theo nguyên tắc ưu tiên xử lý dữ liệu trên thiết bị của người dùng.

- Ứng dụng **không xây dựng máy chủ riêng để thu thập dữ liệu học tập của người dùng**.
- Dữ liệu lịch, thiết lập, theme và các thông tin cần thiết được lưu **cục bộ trên thiết bị**.
- Ứng dụng không tích hợp hệ thống quảng cáo hoặc cơ chế theo dõi hành vi người dùng.
- Thông tin xác thực, cookie, token hoặc dữ liệu phiên đăng nhập không được đưa vào mã nguồn công khai.
- Khi đồng bộ gặp lỗi, hệ thống ưu tiên giữ snapshot dữ liệu hợp lệ gần nhất thay vì thay thế bằng dữ liệu rỗng hoặc chưa hoàn chỉnh.

---

## ⚠️ Hạn chế

- Phiên bản hiện tại tập trung vào **Android**.
- Hoạt động của widget có thể khác nhau giữa launcher và cơ chế quản lý tiến trình của từng hãng điện thoại.
- Một số chức năng phụ thuộc vào cấu trúc và khả năng truy cập của hệ thống QLĐT; nếu hệ thống phía QLĐT thay đổi, ứng dụng có thể cần cập nhật tương ứng.
- Khả năng đồng bộ phụ thuộc vào trạng thái phiên đăng nhập, kết nối mạng và phản hồi từ hệ thống QLĐT.

---

## 🛠️ Công nghệ sử dụng

- **Ngôn ngữ lập trình:** Dart
- **Framework:** Flutter
- **Nền tảng chính:** Android
- **WebView / truy cập QLĐT:** `flutter_inappwebview`
- **Android Home Screen Widget:** `home_widget`
- **Xử lý HTML:** `html`
- **Lưu trữ và thiết lập cục bộ:** `shared_preferences`
- **UI:** Flutter Material Design
- **Kiểm thử:** Flutter Test và kiểm thử trên thiết bị Android thực tế
- **Phân tích chất lượng mã nguồn:** `very_good_analysis`

---

## 👥 Phân công thành viên

| Thành viên | MSSV | Phân công |
| :--- | :--- | :--- |
| **Nguyễn Minh Đạo** *(Trưởng nhóm)* | **24100222** | Phụ trách logic vận hành tổng thể của ứng dụng, đồng bộ dữ liệu, tích hợp và vận hành **Android Widget**. |
| **Đặng Văn Nam Khán** | **24100041** | Phụ trách **trang đăng nhập**, kết nối và xử lý luồng truy cập **QLĐT**, phục vụ việc lấy dữ liệu cho ứng dụng. |
| **Nguyễn Thanh Hải** | **21011491** | Phụ trách thiết kế và hoàn thiện **toàn bộ giao diện UI** của ứng dụng, bảo đảm tính thống nhất và thuận tiện khi sử dụng. |

---

## 🎯 Mục tiêu của dự án

Better Phenikaa hướng tới một sản phẩm có thể sử dụng trong thực tế thay vì chỉ dừng ở mức mô phỏng chức năng.

Thông qua dự án, nhóm đặt mục tiêu:

- xây dựng một ứng dụng Flutter hoàn chỉnh từ giao diện đến xử lý dữ liệu;
- giải quyết bài toán tích hợp với một hệ thống web có sẵn;
- tổ chức và duy trì dữ liệu học tập cục bộ;
- phát triển Android Widget có khả năng hoạt động độc lập với giao diện chính;
- xây dựng cơ chế thông báo và cá nhân hóa giao diện;
- kiểm thử ứng dụng trên thiết bị thực tế và xử lý các khác biệt giữa nhiều môi trường Android.

---

## 📌 Kết luận

Better Phenikaa được xây dựng từ một nhu cầu rất đơn giản: **giảm thời gian và thao tác cần thiết để sinh viên kiểm tra lịch học và lịch thi**.

Từ nhu cầu đó, dự án được mở rộng thành một ứng dụng kết hợp WebView, xử lý dữ liệu, lưu trữ cục bộ, widget, notification và hệ thống giao diện tùy biến. Đây cũng là cơ sở để nhóm vận dụng kiến thức lập trình ứng dụng vào một bài toán thực tế có dữ liệu, trạng thái và môi trường sử dụng thật.
