# T-Alexios – Nhật ký dịch vụ kỹ thuật

App web cho kỹ thuật viên SatiCus ghi nhật ký khi đến khách hàng: lắp đặt, bảo trì, sửa chữa, hiệu chuẩn, đào tạo. Quản lý máy đã lắp đặt, lịch sử can thiệp theo máy, linh kiện đã thay và hạn bảo hành.

- Giao diện: `index.html` tĩnh, chạy trên GitHub Pages, dùng được trên điện thoại và laptop.
- Dữ liệu và đăng nhập: dùng chung Supabase project và tài khoản với Alexios. Không phụ thuộc app nào khác.
- Bảng riêng: `svc_customers`, `svc_equipment`, `svc_visits` (`supabase/001_nhat_ky_dich_vu.sql`, đã chạy).

## Quyền

| | Mọi tài khoản | Super Admin / Admin / Manager / CTO-COO |
|---|---|---|
| Xem toàn bộ nhật ký, máy, khách hàng | ✓ | ✓ |
| Thêm khách hàng, máy, nhật ký | ✓ | ✓ |
| Sửa khách hàng, máy | ✓ | ✓ |
| Sửa, xoá nhật ký | Chỉ của mình | Tất cả |
| Xoá khách hàng, máy | | ✓ |
