# Cau truc feature DemoF3

> Luoi mo QLDT khong co nghia la duoc phep sap code nhu mot bai tap nop luc 23:59.

Ten nhanh thu muc trong `features/` dung tieng Viet khong dau. Ten bat buoc cua
Flutter, Android, API QLDT va cac lop da public duoc giu on dinh de tranh loi
tuong thich.

- `dang_nhap_qldt/`: dang nhap Microsoft/QLDT, phien WebView va parse du lieu.
- `dong_bo_hang_ngay/`: cau noi lap lich dong bo nen luc khoang 06:00.
- `tien_ich_lich_hoc/`: snapshot toi gian va cap nhat widget.
- `giao_dien/`: preset cu va Theme Engine moi.
  - `bo_may/`: nguon theme, sinh token, contrast va token dung chung.
  - `bang_mau_anh/`: giam mau va trich mau dai dien tren thiet bi.
  - `phoi_mau/`: tron 2-3 mau theo ty le.
  - `phong_chu/`: font he thong, font tich hop va font nhap tu may.
  - `tep_cuc_bo/`: doc tep private da duoc Android Storage Access Framework sao chep.
  - `du_lieu/`: luu va khoi phuc custom theme.
  - `xem_truoc/`: editor, preview, luu, sua, xoa va ap dung theme.

Khong chia code theo ten thanh vien. Anh, font va custom theme chi duoc xu ly va
luu cuc bo; khong co analytics, tracker hay upload len dich vu ben thu ba.
