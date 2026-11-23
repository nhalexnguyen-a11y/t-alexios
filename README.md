# T-Alexios – Nhật ký dịch vụ kỹ thuật

App web cho kỹ thuật viên SatiCus ghi nhật ký khi đến khách hàng: lắp đặt, bảo trì, sửa chữa, hiệu chuẩn, đào tạo. Quản lý máy đã lắp đặt, lịch sử can thiệp theo máy, linh kiện đã thay và hạn bảo hành.

- Giao diện: `index.html` tĩnh, chạy trên GitHub Pages, dùng được trên điện thoại và laptop.
- Dữ liệu và đăng nhập: dùng chung Supabase project và tài khoản với Alexios. Không phụ thuộc app nào khác.
- Bảng riêng: `svc_customers`, `svc_equipment`, `svc_visits` (`supabase/001_*.sql`, `002_*.sql`, đã chạy).
- Mỗi nhật ký có người tạo, người phụ trách, kỹ thuật tham gia và deadline. Bàn giao = đổi người phụ trách, người cũ chuyển sang danh sách tham gia.

## Các mục

- **Tổng quan:** số liệu sửa chữa, máy sắp hết bảo hành; bảng 3 cột đặt ngang các việc chưa hoàn thành: Lắp đặt, Sửa chữa, Bảo trì.
- **Lắp đặt** (`svc_installations`): Đợt 1 thông tin lắp đặt (khách hàng, tên máy, hãng, model, serial, số hợp đồng — đều bắt buộc —, ngày dự kiến, phụ trách = người tạo, thời gian và chu kỳ bảo trì, chọn IQ/OQ/PQ/FAT/SAT) → Đợt 2 ngày ký biên bản giao nhận → Đợt 3 ngày hoàn thành các phép thử đã chọn, ngày ký biên bản nghiệm thu, thời hạn bảo hành. Đợt sau chỉ hiện khi đợt trước đủ thông tin. Tạo hồ sơ tự thêm máy vào Máy đã lắp; nghiệm thu tự tính hạn bảo hành.
- **Sửa chữa** (`svc_visits`): Đợt 1 vấn đề, khắc phục, vấn đề còn lại, hướng giải quyết tiếp theo → Đợt 2 deadline. Có người phụ trách, kỹ thuật tham gia, bàn giao.
- **Bảo trì** (`svc_maintenance`, `005_bao_tri_tu_dien.sql`): kỹ thuật tự lên lịch cho từng máy (một hoặc nhiều ngày), app nhắc trong app khi còn 14 ngày và khi quá hạn; ghi nhận "Đã bảo trì". Thời gian và chu kỳ bảo trì trong hồ sơ lắp đặt chỉ để tham khảo.
- **Chốt hoàn thành** (`006_chot_hoan_thanh.sql`): CEO (và Super Admin) bấm "Hoàn thành & chốt" trên phiếu sửa chữa hoặc hồ sơ lắp đặt đủ 3 đợt. Bản ghi đã chốt bị khoá ở database: không sửa, không xoá. Máy gặp sự cố lại thì tạo "bản ghi tiếp nối" gắn với phiếu cũ.
- **Nhân sự** (Super Admin, CEO, Manager): mỗi thành viên một thẻ tóm tắt việc đang có (lắp đặt phụ trách, sửa chữa phụ trách / tham gia, bảo trì chờ làm), số việc quá hạn, sắp đến hạn, xong trong tháng; bấm vào xem chi tiết theo 3 cụm. Chế độ **Lịch** (Tuần / Tháng): mỗi ngày liệt kê việc (lắp đặt dự kiến, giao nhận, phép thử, nghiệm thu, sửa chữa, deadline, bảo trì) với khách hàng và người phụ trách, lọc theo nhân sự.
- **Máy đã lắp, Khách hàng, Thành viên** như trước.

## Quyền

Phân quyền riêng của T-Alexios (bảng `svc_members`, `supabase/003_phan_quyen_rieng.sql`), không phụ thuộc vai trò trong Alexios. Tài khoản đăng nhập dùng chung; tài khoản chưa được thêm vào `svc_members` không vào được app và không đọc được dữ liệu.

Mô hình giao lệnh (`supabase/007_manager_giao_lenh.sql`): Manager tạo lệnh lắp đặt, sửa chữa, bảo trì và giao người phụ trách chính cùng người tham gia; User cập nhật tiến độ trên lệnh được giao.

| | Super Admin | CEO | Manager | User |
|---|---|---|---|---|
| Xem toàn bộ nhật ký, máy, khách hàng | ✓ | ✓ | ✓ | ✓ |
| Tạo lệnh lắp đặt, sửa chữa, bảo trì; thêm máy, khách hàng | ✓ | ✓ | ✓ | |
| Giao, đổi người phụ trách chính và người tham gia | ✓ | ✓ | ✓ | |
| Cập nhật tiến độ lệnh | ✓ | ✓ | ✓ | Lệnh mình phụ trách hoặc tham gia |
| Bàn giao, tạo bản ghi tiếp nối, xoá | ✓ | ✓ | ✓ | |

Mỗi lần đổi người phụ trách phiếu sửa chữa, DB tự ghi một dòng vào `svc_handovers` (người cũ, người mới, người bàn giao, deadline, lý do). Lịch sử chỉ đọc, không ai sửa hay xoá được (`supabase/008_lich_su_ban_giao.sql`).
| Chốt hoàn thành (khoá hồ sơ) | ✓ | ✓ | | |
| Xoá hồ sơ đã chốt | ✓ | ✓ | | |
| Xem mục Nhân sự | ✓ | ✓ | ✓ | |
| Thêm, gỡ thành viên, đổi vai trò | ✓ | | | |
