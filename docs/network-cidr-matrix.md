# Bảng phân hoạch mạng & Ma trận định tuyến (Network CIDR & Routing Matrix)

> **Môn học:** Cloud - Đợt 1 - 2026-2027  
> **Giảng viên hướng dẫn (GVHD):** Huỳnh Xuân Phụng  
> **Nhóm thực hiện:** Infrastructure (Đề tài cá nhân / Solo)  
> **Sinh viên:** Nhat Nguyen ([@nhatnguyen10a1thd-png](https://github.com/nhatnguyen10a1thd-png))  
> **Tài liệu:** Tuần 1 - Phân hoạch dải địa chỉ IP, Cấu hình bảng định tuyến và Ma trận Security Group

---

## 1. Nguyên tắc thiết kế dải địa chỉ (IP Allocation Principles)

1. **Phân tách không gian địa chỉ RFC 1918 (Non-overlapping CIDR):**
   - Môi trường On-Premises (giả lập tại `us-west-2`) sử dụng dải mạng: `10.10.0.0/16`.
   - Môi trường AWS Cloud (Production tại `us-east-1`) sử dụng dải mạng: `10.20.0.0/16`.
   - **Mục đích:** Đảm bảo không xảy ra xung đột IP (IP overlapping) khi thiết lập IPsec VPN và định tuyến trực tiếp giữa hai mạng riêng.
2. **Cấu trúc Subnet 2 tầng chuẩn hóa (VPN & Workload Subnets):**
   - Mỗi VPC bao gồm:
     - **VPN Subnet (Public):** Đặt các Edge Gateway có Public IP/EIP để thiết lập đường hầm IPsec qua Internet.
     - **Workload Subnet (Private):** Chứa các máy chủ ứng dụng nội bộ, cô lập hoàn toàn khỏi Internet trực tiếp, chỉ định tuyến nội bộ qua VPN.

---

## 2. Bảng phân hoạch chi tiết Subnet (Subnet Allocation Table)

### 2.1. VPC On-Premises Giả lập (`us-west-2` - Oregon) · CIDR: `10.10.0.0/16`

| Tên Subnet | Dải CIDR | Khả dụng (Usable IPs) | AZ | Loại Subnet | Mục đích sử dụng | Địa chỉ IP tiêu biểu |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `subnet-onprem-vpn-a` | `10.10.1.0/24` | 251 IPs | `us-west-2a` | Public | Đặt strongSwan VPN Gateway, NAT | `10.10.1.10` (Gateway ENI) |
| `subnet-onprem-workload-a`| `10.10.10.0/24`| 251 IPs | `us-west-2a` | Private | Máy chủ nội bộ On-Prem, Client test | `10.10.10.50` (Workload/DB Host) |
| `subnet-onprem-spare-b`  | `10.10.20.0/24`| 251 IPs | `us-west-2b` | Dự phòng | Dự phòng mở rộng High Availability | Dự trữ tương lai |

> **AWS Reserved IPs trong Subnet `/24`:**
> - `10.10.1.0`: Network Address
> - `10.10.1.1`: VPC Router Default Gateway
> - `10.10.1.2`: AmazonProvidedDNS
> - `10.10.1.3`: Reserved by AWS for future use
> - `10.10.1.255`: Network Broadcast Address

---

### 2.2. VPC AWS Cloud (`us-east-1` - N. Virginia) · CIDR: `10.20.0.0/16`

| Tên Subnet | Dải CIDR | Khả dụng (Usable IPs) | AZ | Loại Subnet | Mục đích sử dụng | Địa chỉ IP tiêu biểu |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `subnet-cloud-vpn-a` | `10.20.1.0/24` | 251 IPs | `us-east-1a` | Public | Đặt strongSwan Gateway / VGW Endpoint | `10.20.1.10` (Gateway ENI) |
| `subnet-cloud-workload-a`| `10.20.10.0/24`| 251 IPs | `us-east-1a` | Private | Máy chủ Production Backend, Nginx, API | `10.20.10.50` (Web Server) |
| `subnet-cloud-spare-b`  | `10.20.20.0/24`| 251 IPs | `us-east-1b` | Dự phòng | Mở rộng Multi-AZ Cloud Workload | Dự trữ tương lai |

---

## 3. Ma trận Bảng định tuyến (Route Table Matrix)

### 3.1. Tuyến định tuyến tại VPC On-Premises (`us-west-2`)

#### A. Public Route Table (`rtb-onprem-public`)
*Gắn với: `subnet-onprem-vpn-a`*

| Destination CIDR | Target / Next Hop | Trạng thái | Diễn giải kỹ thuật |
| :--- | :--- | :--- | :--- |
| `10.10.0.0/16` | `local` | Active | Giao tiếp nội bộ bên trong VPC On-Prem |
| `0.0.0.0/0` | `igw-onprem` (Internet Gateway) | Active | Truy cập Internet công cộng (để đàm phán VPN) |
| `10.20.0.0/16` | `eni-strongswan-onprem` (`10.10.1.10`) | Active | Định tuyến dải mạng Cloud qua strongSwan Gateway |

#### B. Private Route Table (`rtb-onprem-private`)
*Gắn với: `subnet-onprem-workload-a`*

| Destination CIDR | Target / Next Hop | Trạng thái | Diễn giải kỹ thuật |
| :--- | :--- | :--- | :--- |
| `10.10.0.0/16` | `local` | Active | Giao tiếp nội bộ subnet On-Prem |
| `10.20.0.0/16` | `eni-strongswan-onprem` (`10.10.1.10`) | Active | Gói tin gửi sang AWS Cloud đi qua strongSwan |
| *(Tùy chọn)* `0.0.0.0/0` | `nat-onprem` hoặc None | Inactive | Cô lập hoàn toàn, chỉ cho phép đi qua VPN |

---

### 3.2. Tuyến định tuyến tại VPC AWS Cloud (`us-east-1`)

#### A. Public Route Table (`rtb-cloud-public`)
*Gắn với: `subnet-cloud-vpn-a`*

| Destination CIDR | Target / Next Hop | Trạng thái | Diễn giải kỹ thuật |
| :--- | :--- | :--- | :--- |
| `10.20.0.0/16` | `local` | Active | Giao tiếp nội bộ bên trong VPC Cloud |
| `0.0.0.0/0` | `igw-cloud` (Internet Gateway) | Active | Truy cập Internet công cộng |
| `10.10.0.0/16` | `eni-strongswan-cloud` (`10.20.1.10`)* | Active | Định tuyến dải mạng On-Prem qua strongSwan Cloud |

*\* Lưu ý: Nếu chuyển sang phương án demo VGW, Target của `10.10.0.0/16` sẽ đổi thành `vgw-xxxxxxxxx` (Virtual Private Gateway).*

#### B. Private Route Table (`rtb-cloud-private`)
*Gắn với: `subnet-cloud-workload-a`*

| Destination CIDR | Target / Next Hop | Trạng thái | Diễn giải kỹ thuật |
| :--- | :--- | :--- | :--- |
| `10.20.0.0/16` | `local` | Active | Giao tiếp nội bộ VPC Cloud |
| `10.10.0.0/16` | `eni-strongswan-cloud` (`10.20.1.10`) | Active | Gói tin gửi về On-Prem đi qua strongSwan Cloud |

---

## 4. Ma trận Security Group (Security Group Ingress/Egress Rules)

### 4.1. Security Group: Edge VPN Gateway (`sg-vpn-gateway`)
*Áp dụng cho EC2 strongSwan cả 2 đầu*

| Loại | Protocol | Port Range | Source / Destination | Mục đích |
| :--- | :--- | :--- | :--- | :--- |
| **Inbound** | UDP | `500` | `0.0.0.0/0` (hoặc Peer EIP) | IKE SA đàm phán VPN ban đầu |
| **Inbound** | UDP | `4500` | `0.0.0.0/0` (hoặc Peer EIP) | IPsec NAT-Traversal đàm phán & dữ liệu ESP |
| **Inbound** | Custom Protocol 50 | All | `0.0.0.0/0` (hoặc Peer EIP) | ESP (Encapsulating Security Payload) |
| **Inbound** | TCP | `22` | Quản trị viên (Admin CIDR) | Quản trị từ xa qua SSH |
| **Inbound** | All Traffic | All | `10.10.0.0/16` & `10.20.0.0/16` | Cho phép định tuyến gói tin giữa 2 mạng nội bộ |
| **Inbound** | ICMP | All | `0.0.0.0/0` | Kiểm tra ping phản hồi |
| **Outbound**| All Traffic | All | `0.0.0.0/0` | Cho phép chuyển tiếp gói tin mã hóa ra ngoài |

### 4.2. Security Group: Internal Workload Host (`sg-internal-workload`)
*Áp dụng cho máy chủ ứng dụng nội bộ (không có Public IP)*

| Loại | Protocol | Port Range | Source / Destination | Mục đích |
| :--- | :--- | :--- | :--- | :--- |
| **Inbound** | ICMP | Echo Request | `10.10.0.0/16` & `10.20.0.0/16` | Cho phép ping kiểm thử từ cả 2 môi trường |
| **Inbound** | TCP | `80`, `443` | `10.10.0.0/16` & `10.20.0.0/16` | Truy cập dịch vụ Web nội bộ |
| **Inbound** | TCP | `5201` | `10.10.0.0/16` & `10.20.0.0/16` | Kiểm tra băng thông với công cụ iperf3 |
| **Inbound** | TCP | `22` | VPN Subnet CIDR | Quản trị viên nhảy bước (Bastion) qua Gateway |
| **Outbound**| All Traffic | All | `10.10.0.0/16` & `10.20.0.0/16` | Giao tiếp phản hồi dữ liệu qua VPN |

---

## 5. So sánh giải pháp: Site-to-Site VPN vs VPC Peering

| Tiêu chí | Site-to-Site VPN (strongSwan) [Được chọn] | AWS VPC Peering |
| :--- | :--- | :--- |
| **Mô phỏng thực tế** | **Rất sát thực tế doanh nghiệp:** Tái hiện kết nối từ Trung tâm dữ liệu vật lý (on-premises) lên Cloud qua đường truyền công cộng bằng kênh mã hóa IPsec. | Chỉ kết nối giữa 2 VPC nội bộ trên AWS Backbone. Không phản ánh đúng tính chất on-premise. |
| **Giao thức & Mã hóa** | IPsec IKEv2 với mã hóa cấp độ quân sự AES-256-GCM. Toàn quyền cấu hình Phase 1 / Phase 2. | Không cấu hình mã hóa thủ công (AWS tự mã hóa ở tầng vật lý). |
| **Khả năng chuyển giao** | Sinh viên nắm vững cách vận hành strongSwan trên Linux, có thể áp dụng cho mọi hạ tầng (VMware, Proxmox, Azure, GCP). | Chỉ dùng được trong môi trường thuần AWS. |
| **Chi phí** | 0 VNĐ phụ trội khi dùng EC2 t3.micro trong hạn mức Lab. | Miễn phí peering, tính cước data transfer. |
| **Kiểm soát định tuyến** | Toàn quyền can thiệp gói tin, MSS Clamping, NAT-T, iptables. | Bị giới hạn trong các tính năng cố định của VPC Peering. |
