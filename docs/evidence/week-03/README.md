# Thư mục lưu trữ ảnh minh chứng Tuần 3 (Week 3 Evidence Screenshots)

> **Môn học:** Cloud - Đợt 1 - 2026-2027  
> **Giảng viên hướng dẫn (GVHD):** Huỳnh Xuân Phụng  
> **Sinh viên thực hiện:** Nhat Nguyen ([@nhatnguyen10a1thd-png](https://github.com/nhatnguyen10a1thd-png))  
> **Yêu cầu giảng viên:** Ảnh chụp AWS Management Console / CLI phải hiển thị rõ **Account ID**, **Region**, và **Thời gian thực hiện (Timestamp)**.

---

## Danh mục ảnh minh chứng cần lưu giữ (Tuần 3)

| STT | Tên file ảnh minh chứng | Mô tả nội dung cần chụp | Thành phần bắt buộc trong khung hình |
| :---: | :--- | :--- | :--- |
| **01** | `01-route53-private-hosted-zone.png` | Private Hosted Zone `corp.internal` trên Route 53 | Hosted Zone Name: `corp.internal`, Type: `Private hosted zone`, Associated VPCs, Account ID, Global Route 53 Console |
| **02** | `02-route53-cross-vpc-associations.png` | Danh sách 2 VPC liên kết (`us-east-1` & `us-west-2`) | Tab Hosted Zone Details > Associated VPCs hiển thị cả 2 VPC (`Hybrid-Cloud-VPN-vpc-cloud` và `Hybrid-Cloud-VPN-vpc-onprem`) |
| **03** | `03-route53-dns-records.png` | Bảng bản ghi DNS `app.corp.internal` & `db.corp.internal` | Record Type A: `app.corp.internal` trỏ về `10.20.10.50` và `db.corp.internal` trỏ về `10.10.10.50` |
| **04** | `04-dns-resolution-dig-nslookup.png` | Kiểm thử phân giải tên miền bằng `dig` và `nslookup` | Terminal chạy `dig +short app.corp.internal` trả về `10.20.10.50` và `dig +short db.corp.internal` trả về `10.10.10.50` |
| **05** | `05-http-curl-via-domain.png` | Kiểm thử truy cập Web qua tên miền FQDN | Terminal chạy `curl -i http://app.corp.internal` trả về phản hồi chuẩn `HTTP/1.1 200 OK` (Nginx) |
| **06** | `06-cloudwatch-metrics-ec2-gateway.png` | Thu thập metrics CPUUtilization, NetworkIn/Out trên CloudWatch | AWS CloudWatch Metrics Console hiển thị biểu đồ đường đo đạc `CPUUtilization`, `NetworkIn`, `NetworkOut` của Gateway |
| **07** | `07-cloudwatch-alarms-list.png` | Danh sách các CloudWatch Alarms ở trạng thái `OK` | AWS CloudWatch Alarms Console hiển thị 6 Alarms: `HybridVPN-HighCPU`, `HybridVPN-LowNetwork`, `HybridVPN-StatusCheckFailed` |
| **08** | `08-iperf3-throughput-benchmark.png` | Kết quả đo thông lượng băng thông `iperf3` qua hầm IPsec | Terminal hiển thị kết quả `iperf3 -c 10.20.10.50 -t 15` đạt thông lượng ~35 - 50 Mbps qua hầm VPN |
| **09** | `09-dpd-resilience-recovery-test.png` | Log chứng minh hầm tự hồi phục dưới 10 giây (DPD) | Terminal hiển thị luồng ping liên tục có timestamp, hầm tự khôi phục chỉ sau 3-6 giây khi bị ngắt kết nối (`dpdaction=restart`) |
| **10** | `10-aws-vgw-vpn-connection-demo.png` | AWS Console hiển thị Virtual Private Gateway và VPN Connection | AWS VPC Console > Virtual Private Gateways & Site-to-Site VPN connections ở trạng thái `available` phục vụ demo so sánh |
| **11** | `11-vgw-teardown-zero-cost.png` | Minh chứng dọn dẹp xóa sạch VGW và VPN Connection | Terminal chạy `./infrastructure/teardown-week3-vgw.sh` và AWS Console xác nhận trạng thái `deleted`, bảo toàn hạn mức $100 |

---

## Hướng dẫn lưu file ảnh:
- Chụp ảnh màn hình ở độ phân giải rõ nét (định dạng `.png`).
- Đặt tên file chính xác theo danh sách trên và sao chép trực tiếp vào thư mục này:  
  `docs/evidence/week-03/`
- Commit và push lên GitHub sau khi hoàn thành buổi thực hành.
