# Thư mục lưu trữ ảnh minh chứng Tuần 4 (Week 4 Evidence Screenshots)

> **Môn học:** Cloud - Đợt 1 - 2026-2027  
> **Giảng viên hướng dẫn (GVHD):** Huỳnh Xuân Phụng  
> **Sinh viên thực hiện:** Nhat Nguyen ([@nhatnguyen10a1thd-png](https://github.com/nhatnguyen10a1thd-png))  
> **Kho lưu trữ chính thức:** [https://github.com/nhatnguyen10a1thd-png/vpc](https://github.com/nhatnguyen10a1thd-png/vpc)  
> **Yêu cầu giảng viên:** Ảnh chụp AWS Management Console / CLI phải hiển thị rõ **Account ID**, **Region**, và **Thời gian thực hiện (Timestamp)**.

---

## 🎥 Video Demo Nghiệm thu Đề tài (Thời lượng ≤ 10 phút)
* **Liên kết xem trực tiếp trên Google Drive:** [https://drive.google.com/file/d/1aF8-p0T0ejTv2hNPr3z3zeZkPbWPUSJB/view?usp=sharing](https://drive.google.com/file/d/1aF8-p0T0ejTv2hNPr3z3zeZkPbWPUSJB/view?usp=sharing)

---

## Danh mục 8 ảnh minh chứng nghiệm thu Tuần 4

| STT | Tên file ảnh minh chứng | Mô tả nội dung kiểm thử & nghiệm thu | Thành phần bắt buộc trong khung hình |
| :---: | :--- | :--- | :--- |
| **01** | `01-strongswan-ipsec-ikev2-active.png` | Trạng thái đàm phán VPN IPsec IKEv2 ESTABLISHED | Terminal chạy `sudo ipsec statusall` hiển thị `onprem-to-cloud: ESTABLISHED`, thuật toán `AES_CBC_256 / HMAC_SHA2_256 / MODP_2048`, traffic selectors `10.10.0.0/16 === 10.20.0.0/16` |
| **02** | `02-tcp-mss-clamping-iptables.png` | Quy tắc iptables TCP MSS Clamping (1380 bytes) | Bảng iptables mangle hiển thị rule `TCPMSS clamp to PMTU` chống phân mảnh gói tin khi truyền qua đường hầm IPsec |
| **03** | `03-e2e-network-test-results.png` | Kết quả kiểm thử tổng thể E2E toàn diện | Terminal chạy `test_e2e_week4.sh` hiển thị: phân giải Route 53 (10.20.10.50), Ping DF 1380B (0% loss, RTT 56.6ms), HTTP 200 OK (Nginx), và lưu lượng ESP tăng lên > 16.000 bytes |
| **04** | `04-route53-cross-vpc-associations.png` | Route 53 Console - Liên kết Cross-VPC đa vùng | Giao diện Route 53 Console mục `Hosted zone details > Associated VPCs` hiển thị đầy đủ cả 2 VPC: `us-east-1` (Cloud) và `us-west-2` (On-Prem) |
| **05** | `05-route53-dns-records-table.png` | Route 53 Console - Bảng bản ghi DNS nội bộ | Bảng bản ghi loại A: `app.corp.internal` -> `10.20.10.50` và `db.corp.internal` -> `10.10.10.50` kèm Account ID góc trên phải |
| **06** | `06-cloudwatch-alarms-healthy-status.png` | Bảng điều khiển CloudWatch Alarms ở trạng thái xanh OK | AWS CloudWatch Console hiển thị bộ cảnh báo giám sát vận hành `HybridVPN-HighCPU` ở trạng thái xanh `OK`, bảo đảm hệ thống hoạt động ổn định |
| **07** | `07-billing-cost-summary.png` | Tổng quan ngân sách AWS Learner Lab (< $50) | Màn hình AWS Academy Learner Lab Dashboard hiển thị số dư ngân sách an toàn, chi phí tiêu thụ toàn khóa chỉ ~$3 - $5 (chiếm ~10% hạn mức $50) |
| **08** | `08-billing-service-breakdown.png` | Đối soát phân quyền Billing trên tài khoản Lab | Màn hình AWS Console trang Bills thể hiện cơ chế phân quyền IAM của AWS Academy (chặn quyền root billing của tổ chức), giải thích tính phù hợp của mô hình tính cước Lab |

---

> [!NOTE]
> **Quy trình dọn dẹp tài nguyên (Final Teardown):**  
> 1. **Kịch bản tự động hóa:** Mã nguồn kịch bản dọn dẹp triệt để [`infrastructure/teardown-final.sh`](https://github.com/nhatnguyen10a1thd-png/vpc/blob/main/infrastructure/teardown-final.sh) (xem cục bộ tại [`infrastructure/teardown-final.sh`](../../../infrastructure/teardown-final.sh)) đã được hoàn thiện, kiểm thử cú pháp và sẵn sàng thực thi để thu hồi toàn bộ tài nguyên.  
> 2. **Quy trình thao tác bằng tay (Manual Click-Ops):** Hướng dẫn chi tiết từng bước dọn dẹp trên AWS Console theo đúng thứ tự chuẩn chống xung đột phụ thuộc được trình bày đầy đủ tại [PHẦN 3 của Cẩm nang Hướng dẫn Thực hành Tuần 4](../../week-04-implementation-guide.md#phần-3-dọn-dẹp-toàn-bộ-tài-nguyên-final-teardown).  
> 3. **Trạng thái tài nguyên hiện tại:** Các máy ảo EC2 hiện đang được duy trì ở trạng thái dừng/chờ (Standby) để phục vụ buổi vấn đáp trực tiếp và chấm điểm nghiệm thu của Giảng viên hướng dẫn Huỳnh Xuân Phụng. Ngay sau khi GVHD duyệt nghiệm thu xong, sinh viên sẽ kích hoạt lệnh dọn dẹp để giải phóng 100% tài nguyên, bảo đảm cước phí duy trì sau môn học là **$0.00**.
