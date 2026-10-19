# Thư mục lưu trữ ảnh minh chứng Tuần 2 (Week 2 Evidence Screenshots)

> **Môn học:** Cloud - Đợt 1 - 2026-2027  
> **Giảng viên hướng dẫn (GVHD):** Huỳnh Xuân Phụng  
> **Sinh viên thực hiện:** Nhat Nguyen ([@nhatnguyen10a1thd-png](https://github.com/nhatnguyen10a1thd-png))  
> **Yêu cầu giảng viên:** Ảnh chụp AWS Management Console / CLI phải hiển thị rõ **Account ID**, **Region**, và **Thời gian thực hiện (Timestamp)**.

---

## Danh mục ảnh minh chứng cần lưu giữ (Tuần 2)

| STT | Tên file ảnh minh chứng | Mô tả nội dung cần chụp | Thành phần bắt buộc trong khung hình |
| :---: | :--- | :--- | :--- |
| **01** | `01-onprem-vpc-subnets-uswest2.png` | Danh sách VPC & Subnet tại `us-west-2` (Oregon) | AWS Console VPC, CIDR `10.10.0.0/16`, Subnet `10.10.1.0/24` & `10.10.10.0/24`, Account ID, Region `us-west-2` |
| **02** | `02-cloud-vpc-subnets-useast1.png` | Danh sách VPC & Subnet tại `us-east-1` (N. Virginia) | AWS Console VPC, CIDR `10.20.0.0/16`, Subnet `10.20.1.0/24` & `10.20.10.0/24`, Account ID, Region `us-east-1` |
| **03** | `03-ec2-instances-overview.png` | Danh sách 4 máy ảo EC2 đang chạy (Gateway & Workload) | EC2 Console, 2 EC2 tại mỗi Region (`t3.micro`), trạng thái `Running`, gắn đúng Tag `Project=Hybrid-Cloud-VPN` |
| **04** | `04-ec2-disable-source-dest-check.png` | Chi tiết tắt cờ Source/Destination Check trên Gateway | AWS Console EC2 > Actions > Networking > Change source/destination check: **Stop** (Disabled) |
| **05** | `05-security-groups-rules.png` | Cấu hình Security Group cho Gateway và Workload | Inbound Rules hiển thị UDP 500, UDP 4500, Protocol 50 ESP, ICMP, TCP 80, TCP 22 |
| **06** | `06-route-table-onprem-target-eni.png` | Route Table On-Premises trỏ đích `10.20.0.0/16` về ENI strongSwan | Route Table Console `us-west-2`, Target là `eni-xxxx` (Gateway `10.10.1.10`) |
| **07** | `07-route-table-cloud-target-eni.png` | Route Table Cloud trỏ đích `10.10.0.0/16` về ENI strongSwan | Route Table Console `us-east-1`, Target là `eni-xxxx` (Gateway `10.20.1.10`) |
| **08** | `08-strongswan-service-status.png` | Trạng thái dịch vụ strongSwan trên cả 2 máy Gateway | Terminal SSH hiển thị `systemctl status strongswan-starter` (hoặc `strongswan`) `active (running)` |
| **09** | `09-ipsec-tunnel-established.png` | Trạng thái đàm phán đường hầm VPN (`ipsec statusall`) | Terminal hiển thị IKE SA `ESTABLISHED`, Child SA `INSTALLED`, bytes in/out tăng |
| **10** | `10-private-ping-host-to-host.png` | Kiểm thử ping qua Private IP giữa 2 máy Workload | Terminal Workload On-Prem `10.10.10.50` ping thành công Workload Cloud `10.20.10.50` (0% packet loss) |
| **11** | `11-tcpdump-esp-packet-capture.png` | Bắt gói tin mã hóa ESP trên Gateway | Terminal Gateway chạy `tcpdump -n -i eth0 esp` bắt được các frame ESP mã hóa khi đang ping |
| **12** | `12-http-nginx-private-ip-curl.png` | Kiểm thử truy cập dịch vụ Web HTTP nội bộ qua VPN | Terminal Workload On-Prem chạy `curl -I http://10.20.10.50` trả về `HTTP/1.1 200 OK` (Nginx) |

---

## Hướng dẫn lưu file ảnh:
- Chụp ảnh màn hình ở độ phân giải rõ nét (khuyến nghị định dạng `.png`).
- Đặt tên file chính xác theo danh sách trên và sao chép trực tiếp vào thư mục này:  
  `docs/evidence/week-02/`
- Commit và push lên GitHub sau khi hoàn thành buổi thực hành.
