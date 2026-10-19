# Hướng dẫn Triển khai Tuần 2: Triển khai Chức năng Lõi trên AWS & Kiểm thử VPN

> **Môn học:** Cloud - Đợt 1 - 2026-2027  
> **Giảng viên hướng dẫn (GVHD):** Huỳnh Xuân Phụng  
> **Nhóm thực hiện:** Infrastructure (Đề tài cá nhân / Solo)  
> **Sinh viên:** Nhat Nguyen ([@nhatnguyen10a1thd-png](https://github.com/nhatnguyen10a1thd-png))  
> **Giai đoạn:** Tuần 2 - Triển khai các chức năng lõi trên AWS, cấu hình strongSwan IPsec IKEv2, kiểm thử từng thành phần và thu thập minh chứng.

---

## 1. Ràng buộc & Quy định thực hành trên AWS Learner Lab

Để đảm bảo tuân thủ 100% quy định của môn học và không bị trừ điểm hoặc khóa tài khoản Lab:
1. **Khu vực hoạt động (Region):** Chỉ sử dụng 2 Region được cấp phép:
   - `us-west-2` (Oregon): Đại diện cho **Trung tâm dữ liệu On-Premises**.
   - `us-east-1` (N. Virginia): Đại diện cho **AWS Cloud Production**.
2. **Quyền IAM (LabRole):** Không tạo IAM User/Role mới. Khi tạo EC2, chọn **IAM Instance Profile:** `LabInstanceProfile` (liên kết với `LabRole`).
3. **Cấu hình máy ảo (EC2):**
   - Loại instance: `t3.micro` (hoặc `t3.small`), thuộc dải nano -> large.
   - Số lượng: Tối đa 2 instance tại `us-west-2` và 2 instance tại `us-east-1` (tổng 4 instances <= giới hạn 9 instances/region).
   - Ổ cứng EBS: 8 GB gp3 (tổng <= 100 GB).
   - Hệ điều hành: Ubuntu Server 22.04 LTS (HVM), SSD Volume Type.
4. **Chính sách gắn Tag bắt buộc (AWS Tagging Policy):**
   Mọi tài nguyên (VPC, Subnet, IGW, Route Table, Security Group, EC2, Elastic IP, Volume) phải có bộ tag:
   ```yaml
   Project: Hybrid-Cloud-VPN
   Environment: Lab-Simulation
   Course: Cloud-Dot1-2026-2027
   Instructor: HuynhXuanPhung
   Owner: NhatNguyen
   Phase: Week2-CoreImplementation
   ```
5. **Tiết kiệm chi phí:** Dừng (Stop) hoặc xóa (Teardown) máy ảo sau mỗi buổi thực hành để bảo toàn hạn mức $100.
6. **Yêu cầu ảnh chụp minh chứng:**
   > [!IMPORTANT]
   > Tất cả ảnh chụp màn hình nộp báo cáo phải hiển thị rõ **Account ID**, **Region**, và **Thời gian hệ thống (Timestamp trên khay đồng hồ máy tính hoặc lệnh `date` trong CLI)**.

---

## 2. Mô hình kiến trúc & Địa chỉ mạng Tuần 2

```
+-------------------------------------------------------------+     +-------------------------------------------------------------+
|               ON-PREMISES VPC (us-west-2)                   |     |                 AWS CLOUD VPC (us-east-1)                   |
|                      10.10.0.0/16                           |     |                        10.20.0.0/16                         |
|                                                             |     |                                                             |
|  [Public VPN Subnet: 10.10.1.0/24]                          |     |  [Public VPN Subnet: 10.20.1.0/24]                          |
|  +-------------------------------------------------------+  |     |  +-------------------------------------------------------+  |
|  | EC2 strongSwan Gateway (ec2-onprem-strongswan)        |  |     |  | EC2 strongSwan Gateway (ec2-cloud-strongswan)         |  |
|  | Private IP: 10.10.1.10                                |  |     |  | Private IP: 10.20.1.10                                |  |
|  | Public EIP: <ONPREM_EIP>                              |  |     |  | Public EIP: <CLOUD_EIP>                               |  |
|  | Source/Dest Check: DISABLED                           |  |     |  | Source/Dest Check: DISABLED                           |  |
|  | iptables: TCP MSS Clamped to PMTU (1380)              |  |     |  | iptables: TCP MSS Clamped to PMTU (1380)              |  |
|  +---------------------------+---------------------------+  |     |  +---------------------------+---------------------------+  |
|                              |                              |     |                              |                              |
|                              v                              |     |                              v                              |
|  [Private Workload Subnet: 10.10.10.0/24]                   |     |  [Private Workload Subnet: 10.20.10.0/24]                   |
|  +-------------------------------------------------------+  |     |  +-------------------------------------------------------+  |
|  | EC2 Workload Host (ec2-onprem-workload)               |  |     |  | EC2 Workload Host (ec2-cloud-workload)                |  |
|  | Private IP: 10.10.10.50 (No Public IP)                |  |     |  | Private IP: 10.20.10.50 (No Public IP)                 |  |
|  | Testing: ping client, curl client                     |  |     |  | Service: Nginx HTTP Server (port 80), iperf3 daemon   |  |
|  +-------------------------------------------------------+  |     |  +-------------------------------------------------------+  |
+------------------------------+------------------------------+     +------------------------------+------------------------------+
                               |                                                                   |
                               +=========> [IPsec IKEv2 AES-256 Tunnel qua Internet] <=============+
```

---

## 3. Các bước triển khai chi tiết từng phần

### Bước 1: Khởi tạo Nền tảng VPC tại 2 Region

Bạn có thể tạo nhanh toàn bộ VPC, Subnet, IGW, Route Table và Security Group bằng 2 template CloudFormation chuẩn đã được chuẩn bị sẵn:
- Phía Cloud: `infrastructure/cloudformation-vpc-foundation.yaml`
- Phía On-Prem: `infrastructure/cloudformation-onprem-foundation.yaml`

#### Cách 1: Chạy lệnh trên AWS CloudShell (Khuyến nghị)
1. Mở AWS CloudShell từ giao diện AWS Console (biểu tượng góc trên bên phải).
2. Tải hoặc clone mã nguồn repository:
   ```bash
   git clone https://github.com/nhatnguyen10a1thd-png/vpc.git
   cd vpc
   ```
3. Chạy script triển khai tự động:
   ```bash
   chmod +x infrastructure/deploy-week2.sh
   ./infrastructure/deploy-week2.sh
   ```

#### Cách 2: Tạo qua AWS CloudFormation Console
1. **Tại Region `us-east-1`:**
   - Vào **CloudFormation** > **Create stack** > **With new resources (standard)**.
   - Chọn **Upload a template file** > Chọn file `infrastructure/cloudformation-vpc-foundation.yaml`.
   - Stack name: `Hybrid-Cloud-VPN-Cloud-Foundation`.
   - Bấm **Next** qua các bước và chọn **Submit**.
2. **Chuyển sang Region `us-west-2`:**
   - Đổi Region sang **Oregon (`us-west-2`)**.
   - Vào **CloudFormation** > **Create stack** > Upload file `infrastructure/cloudformation-onprem-foundation.yaml`.
   - Stack name: `Hybrid-Cloud-VPN-OnPrem-Foundation`.
   - Bấm **Next** và chọn **Submit**.

---

### Bước 2: Khởi chạy 4 máy ảo EC2 & Gán Elastic IP

| Tên máy EC2 | Region | Subnet | Private IP | Elastic IP | Security Group | Ghi chú |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `ec2-cloud-strongswan` | `us-east-1` | `subnet-cloud-vpn-a` | `10.20.1.10` | Có (Allocate EIP mới) | `sg-cloud-gateway` | Chạy strongSwan |
| `ec2-cloud-workload` | `us-east-1` | `subnet-cloud-workload-a` | `10.20.10.50` | Không (Private Only) | `sg-cloud-workload` | Nginx HTTP, iperf3 |
| `ec2-onprem-strongswan` | `us-west-2` | `subnet-onprem-vpn-a` | `10.10.1.10` | Có (Allocate EIP mới) | `sg-onprem-gateway` | Chạy strongSwan |
| `ec2-onprem-workload` | `us-west-2` | `subnet-onprem-workload-a` | `10.10.10.50` | Không (Private Only) | `sg-onprem-workload` | Client ping, curl |

> [!NOTE]
> Ghi lại 2 địa chỉ Public Elastic IP:
> - `CLOUD_EIP`: Địa chỉ IP của máy `ec2-cloud-strongswan`.
> - `ONPREM_EIP`: Địa chỉ IP của máy `ec2-onprem-strongswan`.

---

### Bước 3: Vô hiệu hóa Source/Destination Check trên 2 máy Gateway

> [!CRITICAL]
> **Điểm cốt lõi thường bị hỏi khi vấn đáp:** Mặc định AWS EC2 chỉ cho phép gói tin đi ra/vào nếu IP nguồn/đích trùng với IP của card mạng (ENI). Khi máy strongSwan làm Router trung chuyển gói tin giữa 2 mạng `10.10.0.0/16` và `10.20.0.0/16`, **bắt buộc phải vô hiệu hóa Source/Destination Check**.

Thực hiện trên AWS Console cho **cả 2 máy EC2 strongSwan**:
1. Chọn máy `ec2-cloud-strongswan` (tại `us-east-1`) > Bấm **Actions** > **Networking** > **Change source/destination check**.
2. Chọn dấu tick **Stop** (Disabled) > Bấm **Save**.
3. Chuyển sang `us-west-2` và lặp lại thao tác tương tự cho máy `ec2-onprem-strongswan`.

*Lệnh AWS CLI tương đương:*
```bash
aws ec2 modify-instance-attribute --instance-id <CLOUD_GATEWAY_ID> --no-source-dest-check --region us-east-1
aws ec2 modify-instance-attribute --instance-id <ONPREM_GATEWAY_ID> --no-source-dest-check --region us-west-2
```

---

### Bước 4: Cấu hình Bảng định tuyến (Route Table) chuyển tiếp lưu lượng

Để các máy Workload trong subnet nội bộ biết đường đi sang VPC đối diện, ta cấu hình Route Table:

#### 1. Tại VPC On-Premises (`us-west-2`):
- Mở **VPC** > **Route Tables** > Chọn cả 2 bảng định tuyến:
  - `rtb-onprem-private` (gắn với `subnet-onprem-workload-a`)
  - `rtb-onprem-public` (gắn với `subnet-onprem-vpn-a`)
- Bấm **Edit routes** > **Add route**:
  - **Destination:** `10.20.0.0/16` (Dải mạng của AWS Cloud)
  - **Target:** Chọn **Network Interface** > Chọn ENI của máy `ec2-onprem-strongswan` (`10.10.1.10`).
  - Bấm **Save changes**.

#### 2. Tại VPC AWS Cloud (`us-east-1`):
- Mở **VPC** > **Route Tables** > Chọn cả 2 bảng định tuyến:
  - `rtb-cloud-private` (gắn với `subnet-cloud-workload-a`)
  - `rtb-cloud-public` (gắn với `subnet-cloud-vpn-a`)
- Bấm **Edit routes** > **Add route**:
  - **Destination:** `10.10.0.0/16` (Dải mạng của On-Premises)
  - **Target:** Chọn **Network Interface** > Chọn ENI của máy `ec2-cloud-strongswan` (`10.20.1.10`).
  - Bấm **Save changes**.

---

### Bước 5: Cấu hình strongSwan IPsec VPN trên 2 máy Gateway

SSH vào từng máy Gateway bằng cặp khóa SSH (`vockey.pem` hoặc khóa tạo trong Lab):

#### 1. Trên máy On-Premises Gateway (`ec2-onprem-strongswan`):
Chạy lệnh cấu hình tự động:
```bash
# Tải script từ repository
curl -fsSL https://raw.githubusercontent.com/nhatnguyen10a1thd-png/vpc/main/infrastructure/strongswan/setup-gateway.sh -o setup-gateway.sh
chmod +x setup-gateway.sh

# Chạy cấu hình với EIP thực tế:
sudo ./setup-gateway.sh <ONPREM_EIP> <CLOUD_EIP> 10.10.0.0/16 10.20.0.0/16 onprem
```

#### 2. Trên máy Cloud Gateway (`ec2-cloud-strongswan`):
Chạy lệnh cấu hình tương ứng:
```bash
curl -fsSL https://raw.githubusercontent.com/nhatnguyen10a1thd-png/vpc/main/infrastructure/strongswan/setup-gateway.sh -o setup-gateway.sh
chmod +x setup-gateway.sh

# Chạy cấu hình với EIP thực tế:
sudo ./setup-gateway.sh <CLOUD_EIP> <ONPREM_EIP> 10.20.0.0/16 10.10.0.0/16 cloud
```

#### 3. Kiểm tra trạng thái đường hầm VPN (SA):
Trên một trong hai Gateway, kiểm tra:
```bash
sudo ipsec statusall
```
**Kết quả mong đợi:**
- `Security Associations (1 up, 1 active)`
- IKE SA: `ESTABLISHED`
- Child SA: `INSTALLED, TUNNEL` với `10.10.0.0/16 === 10.20.0.0/16`
- Thuật toán mã hóa: `AES_GCM_16_256` hoặc `AES_CBC_256/HMAC_SHA2_256_128/MODP_2048`.

---

### Bước 6: Kiểm thử Kết nối & Bắt gói tin (Verification & Diagnostics)

#### Kiểm thử 1: Ping giữa 2 máy Workload qua Private IP
1. Từ máy `ec2-onprem-strongswan`, nhảy bước (jump) SSH sang máy `ec2-onprem-workload` (`10.10.10.50`):
   ```bash
   ssh ubuntu@10.10.10.50
   ```
2. Thực hiện lệnh ping liên tục sang máy `ec2-cloud-workload` (`10.20.10.50`):
   ```bash
   ping -c 10 10.20.10.50
   ```
   **Kết quả:** 10 packets transmitted, 10 received, `0% packet loss`.

#### Kiểm thử 2: Bắt gói tin mã hóa ESP qua `tcpdump`
1. Mở một cửa sổ terminal khác trên `ec2-onprem-strongswan`.
2. Chạy lệnh theo dõi lưu lượng card mạng `eth0`:
   ```bash
   sudo tcpdump -n -i eth0 'esp or udp port 500 or udp port 4500'
   ```
3. Khi lệnh `ping` ở máy workload đang chạy, terminal `tcpdump` sẽ xuất hiện liên tục các dòng:
   `IP <ONPREM_EIP> > <CLOUD_EIP>: ESP(spi=0x..., seq=...)`
   *(Chứng minh gói tin không truyền trần dưới dạng ICMP bản rõ mà đã được mã hóa 100% bằng giao thức ESP)*.

#### Kiểm thử 3: Kiểm tra dịch vụ Web HTTP (Nginx) nội bộ
Từ máy `ec2-onprem-workload` (`10.10.10.50`), gọi dịch vụ web Nginx trên Cloud:
```bash
curl -i http://10.20.10.50
```
**Kết quả:**
- Header trả về `HTTP/1.1 200 OK`.
- Thân trang HTML hiển thị:
  `🌐 Mạng Lai Hybrid Cloud - Workload Server | Trạng thái: HOẠT ĐỘNG TỐT (ACTIVE)`.

---

## 4. Hướng dẫn chi tiết Chụp ảnh Minh chứng Tuần 2 (Evidence Guide)

Giảng viên yêu cầu minh chứng rõ ràng, không chấp nhận ảnh cắt xén mất bối cảnh. Dưới đây là bảng 12 ảnh cần chụp và lưu vào thư mục:  
📁 [`docs/evidence/week-02/`](docs/evidence/week-02/)

| Tên file ảnh | Cách chụp & Vị trí màn hình | Chi tiết bắt buộc phải có trong ảnh |
| :--- | :--- | :--- |
| `01-onprem-vpc-subnets-uswest2.png` | VPC Console tại `us-west-2` (Oregon) | Góc trên phải có `AWS Account ID`, Region `Oregon`, danh sách VPC `10.10.0.0/16` và 2 Subnet `10.10.1.0/24`, `10.10.10.0/24`. |
| `02-cloud-vpc-subnets-useast1.png` | VPC Console tại `us-east-1` (N. Virginia) | Góc trên phải có `AWS Account ID`, Region `N. Virginia`, danh sách VPC `10.20.0.0/16` và 2 Subnet `10.20.1.0/24`, `10.20.10.0/24`. |
| `03-ec2-instances-overview.png` | EC2 Instances Console | Danh sách máy ảo ở trạng thái `Running`, hiển thị rõ Instance Type `t3.micro`, Private IPs (`10.10.1.10`, `10.20.1.10`, v.v.), và thẻ Tag `Project=Hybrid-Cloud-VPN`. |
| `04-ec2-disable-source-dest-check.png` | Màn hình popup `Change source/destination check` | Ô chọn `Stop` (Disabled) cho máy ảo EC2 Gateway. |
| `05-security-groups-rules.png` | EC2 Security Groups Console | Bảng Inbound rules hiển thị: UDP 500, UDP 4500, Protocol 50 ESP, ICMP, TCP 22. |
| `06-route-table-onprem-target-eni.png` | Route Table Console tại `us-west-2` | Tab **Routes** hiển thị dòng `10.20.0.0/16` với Target là `eni-xxxx` (Gateway On-Prem). |
| `07-route-table-cloud-target-eni.png` | Route Table Console tại `us-east-1` | Tab **Routes** hiển thị dòng `10.10.0.0/16` với Target là `eni-xxxx` (Gateway Cloud). |
| `08-strongswan-service-status.png` | Terminal SSH vào Gateway | Lệnh `sudo systemctl status strongswan-starter` hoặc `strongswan` báo `active (running)`. Có gõ kèm lệnh `date` để đối chiếu thời gian. |
| `09-ipsec-tunnel-established.png` | Terminal SSH Gateway | Lệnh `sudo ipsec statusall` hiển thị `ESTABLISHED`, Child SA `INSTALLED`, bytes in/bytes out. |
| `10-private-ping-host-to-host.png` | Terminal Workload On-Prem | Lệnh `ping -c 10 10.20.10.50` cho kết quả `0% packet loss`, latency ~60ms. |
| `11-tcpdump-esp-packet-capture.png` | Terminal Gateway trong lúc ping | Lệnh `sudo tcpdump -n -i eth0 esp` bắt được các frame ESP mã hóa. |
| `12-http-nginx-private-ip-curl.png` | Terminal Workload On-Prem | Lệnh `curl -i http://10.20.10.50` trả về mã `200 OK` và nội dung HTML Nginx. |

---

## 5. Dọn dẹp & Giải phóng tài nguyên sau buổi thực hành (Teardown)

Sau khi hoàn tất kiểm thử và lưu toàn bộ ảnh minh chứng:
1. Chạy script tạm dừng các máy ảo (tiết kiệm chi phí):
   ```bash
   ./infrastructure/teardown-week2.sh stop
   ```
2. Nếu muốn xóa sạch toàn bộ môi trường (re-deploy từ đầu ở buổi sau):
   ```bash
   ./infrastructure/teardown-week2.sh terminate
   ```

---

## 6. Nhật ký công việc Tuần 2 (Worklog mẫu nộp báo cáo)

Theo yêu cầu môn học, mỗi sinh viên phải đạt tối thiểu **8 giờ làm việc/tuần**:

| Ngày | Số giờ | Công việc chi tiết | Sản phẩm / Minh chứng |
| :---: | :---: | :--- | :--- |
| **Thứ 2** | 2.5h | Viết CloudFormation template `cloudformation-onprem-foundation.yaml`, cấu hình VPC, Subnets, Route Tables, Security Groups 2 Region. | Template YAML hoàn chỉnh, stack tạo thành công trên AWS. |
| **Thứ 4** | 2.5h | Khởi tạo 4 máy ảo EC2 `t3.micro`, cấp phát Elastic IP, vô hiệu hóa Source/Dest Check và cấu hình định tuyến ENI trong Route Table. | Máy EC2 `running`, tắt cờ Source/Dest Check thành công. |
| **Thứ 6** | 3.0h | Viết script cài đặt strongSwan IKEv2, tinh chỉnh sysctl kernel forward và MSS Clamping iptables. Cấu hình đàm phán PSK giữa 2 đầu Gateway. | Đường hầm IPsec `ESTABLISHED`, Child SA `INSTALLED`. |
| **Chủ Nhật**| 2.0h | Kiểm thử thông mạng Private IP (Ping, HTTP Nginx, tcpdump ESP), chụp 12 ảnh minh chứng và cập nhật tài liệu báo cáo tuần 2. | 12 ảnh minh chứng trong `docs/evidence/week-02/`, báo cáo tuần 2. |
| **TỔNG** | **10.0h** | **Đạt yêu cầu (>= 8 giờ/tuần)** | Đầy đủ minh chứng theo quy định |
