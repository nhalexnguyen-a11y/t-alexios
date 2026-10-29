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
- **Máy đã lắp, Khách hàng, Thành viên** như trước.

## Quyền

Phân quyền riêng của T-Alexios (bảng `svc_members`, `supabase/003_phan_quyen_rieng.sql`), không phụ thuộc vai trò trong Alexios. Tài khoản đăng nhập dùng chung; tài khoản chưa được thêm vào `svc_members` không vào được app và không đọc được dữ liệu.

| | Super Admin | CEO, CTO/COO | Kỹ thuật |
|---|---|---|---|
| Xem toàn bộ nhật ký, máy, khách hàng | ✓ | ✓ | ✓ |
| Ghi nhật ký, thêm máy, khách hàng | ✓ | ✓ | ✓ |
| Sửa hồ sơ lắp đặt | ✓ | ✓ | Hồ sơ mình phụ trách |
| Sửa phiếu sửa chữa, bàn giao | ✓ | ✓ | Khi là người tạo, phụ trách hoặc tham gia |
| Xoá nhật ký | ✓ | ✓ | Nhật ký mình tạo |
| Xoá máy, khách hàng | ✓ | ✓ | |
| Chốt hoàn thành (khoá hồ sơ) | ✓ | CEO | |
| Thêm, gỡ thành viên, đổi vai trò | ✓ | | |
