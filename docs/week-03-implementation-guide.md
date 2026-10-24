# Hướng dẫn Thực hành Từng bước (Click-Ops): Tuần 3 - Route 53 Hybrid DNS, Giám sát CloudWatch, Đo đạc Hiệu năng & VGW Demo

> **Môn học:** Cloud - Đợt 1 - 2026-2027  
> **Giảng viên hướng dẫn (GVHD):** Huỳnh Xuân Phụng  
> **Nhóm thực hiện:** Infrastructure (Đề tài cá nhân / Solo)  
> **Sinh viên thực hiện:** Nhat Nguyen ([@nhatnguyen10a1thd-png](https://github.com/nhatnguyen10a1thd-png))  
> **Giai đoạn:** Tuần 3 - Triển khai bằng tay trên AWS Management Console (Click-Ops) và Terminal, kết hợp tự động hóa đối soát.

---

## 📋 BẢNG THÔNG SỐ TRA CỨU NHANH KHI ĐIỀN FORM AWS (TUẦN 3)

Trước khi thực hiện các thao tác click chuột trên AWS Console, sinh viên ghi nhớ bảng thông số chuẩn sau:

| Thành phần cấu hình | Giá trị thiết lập chuẩn | Mục đích kỹ thuật |
| :--- | :--- | :--- |
| **Tên Private Hosted Zone** | `corp.internal` | Vùng phân giải DNS nội bộ khép kín cho hệ thống mạng lai |
| **Loại Hosted Zone** | **Private hosted zone for Amazon VPC** | Chỉ phục vụ phân giải nội bộ trong VPC, không công khai ra Internet |
| **VPC liên kết 1 (Cloud)** | `Hybrid-Cloud-VPN-vpc-cloud` (`us-east-1` - N. Virginia) | Dải mạng `10.20.0.0/16` |
| **VPC liên kết 2 (On-Prem)**| `Hybrid-Cloud-VPN-vpc-onprem` (`us-west-2` - Oregon) | Dải mạng `10.10.0.0/16` (Cross-VPC Association) |
| **Bản ghi DNS 1 (Web App)** | Tên: `app.corp.internal` \| Loại: `A` \| Giá trị: `10.20.10.50` | Trỏ về máy chủ Web Nginx Cloud qua IP Private |
| **Bản ghi DNS 2 (Database)** | Tên: `db.corp.internal` \| Loại: `A` \| Giá trị: `10.10.10.50` | Trỏ về máy chủ Cơ sở dữ liệu On-Premises qua IP Private |
| **TTL (Time to Live)** | `60` giây | Tối ưu hóa thời gian cập nhật bản ghi khi có thay đổi |
| **CloudWatch Alarm CPU** | Ngưỡng: `>= 80%` trong 2 chu kỳ (mỗi chu kỳ 60s) | Cảnh báo khi EC2 strongSwan Gateway bị quá tải xử lý mã hóa |
| **CloudWatch Alarm Mạng**| Ngưỡng: `<= 500 bytes` trong 2 chu kỳ (mỗi chu kỳ 300s) | Cảnh báo khi đường hầm VPN bị đứt kết nối / mất gói đột ngột |
| **Cơ chế DPD (strongSwan)**| `dpddelay=10s`, `dpdtimeout=30s`, `dpdaction=restart` | Tự động phát hiện đứt kết nối và tự phục hồi dưới 10 giây |

---

## PHẦN 1: TRIỂN KHAI AMAZON ROUTE 53 (PRIVATE HOSTED ZONE) BẰNG TAY

### Bước 1.1: Bật tính năng DNS Hostnames & DNS Support trên cả 2 VPC

> [!IMPORTANT]
> **Điều kiện tiên quyết của AWS:** Để Route 53 Private Hosted Zone hoạt động và máy ảo phân giải được qua IP `.2` ngầm định, cả 2 thuộc tính **DNS hostnames** và **DNS resolution** của VPC bắt buộc phải được kích hoạt.

1. **Tại Region N. Virginia (`us-east-1`):**
   * Vào **VPC** > **Your VPCs**.
   * Tích chọn `Hybrid-Cloud-VPN-vpc-cloud`.
   * Bấm nút **Actions** ở góc trên bên phải > Chọn **Edit VPC settings**.
   * Tại mục **DNS settings**:
     * Tích chọn ✅ **Enable DNS hostnames**.
     * Tích chọn ✅ **Enable DNS resolution**.
   * Bấm **Save changes**.

2. **Chuyển sang Region Oregon (`us-west-2`):**
   * Đổi Region sang **Oregon (`us-west-2`)**.
   * Vào **Your VPCs** > Tích chọn `Hybrid-Cloud-VPN-vpc-onprem`.
   * Bấm **Actions** > **Edit VPC settings** > Tích chọn cả 2 mục **Enable DNS hostnames** và **Enable DNS resolution** > Bấm **Save changes**.

---

### Bước 1.2: Tạo Private Hosted Zone `corp.internal` trên Route 53 Console

1. Trên thanh tìm kiếm AWS Console, gõ **Route 53** > Bấm chọn dịch vụ.
2. Ở thanh menu bên trái, tìm nhóm menu trên cùng và bấm vào mục **Hosted zones** (dưới dòng *Dashboard*).
3. Bấm nút màu cam **Create hosted zone**.
4. Điền form cấu hình như sau:
   * **Domain name:** Nhập `corp.internal`
   * **Description:** `Hybrid Cloud VPN Private Hosted Zone Week 3`
   * **Type:** Chọn mục radio thứ hai: 🔘 **Private hosted zone**.
5. Kéo xuống mục **VPCs to associate with the hosted zone**:
   * **VPC Region:** Chọn **US East (N. Virginia) (us-east-1)**.
   * **VPC ID:** Bấm menu xổ xuống và chọn VPC `Hybrid-Cloud-VPN-vpc-cloud` (`10.20.0.0/16`).
6. Bấm nút **Create hosted zone** ở cuối trang.
7. *Ghi nhận:* Hệ thống tạo thành công Hosted Zone với mã định danh (Hosted Zone ID).

---

### Bước 1.3: Cấu hình Cross-VPC Association liên kết VPC On-Premises (`us-west-2`)

> [!NOTE]
> **Giải thích cơ chế kỹ thuật khi Vấn đáp với Giảng viên:**  
> Giao diện đồ họa AWS Console tại thời điểm tạo Hosted Zone chỉ cho phép chọn VPC đầu tiên cùng Region với tài nguyên khởi tạo. Đối với kiến trúc đa vùng (Cross-Region), AWS cung cấp API `associate-vpc-with-hosted-zone`. Vì cả 2 VPC nằm trong cùng một tài khoản AWS Learner Lab, liên kết được thiết lập trực tiếp mà không cần bước cấp quyền Authorization phức tạp.

Mở **AWS CloudShell** (hoặc terminal bất kỳ) và thực thi lệnh liên kết trực tiếp:
```bash
# Lấy Hosted Zone ID vừa tạo và VPC ID On-Premises:
ZONE_ID=$(aws route53 list-hosted-zones-by-name --dns-name "corp.internal." --query "HostedZones[0].Id" --output text | sed 's|/hostedzone/||')
ONPREM_VPC_ID=$(aws ec2 describe-vpcs --region us-west-2 --filters "Name=cidr,Values=10.10.0.0/16" --query "Vpcs[0].VpcId" --output text)

# Thực hiện liên kết Cross-VPC Association:
aws route53 associate-vpc-with-hosted-zone \
    --hosted-zone-id "$ZONE_ID" \
    --vpc "VPCRegion=us-west-2,VPCId=$ONPREM_VPC_ID" \
    --comment "Cross-VPC Association: OnPrem VPC us-west-2"
```

*Kiểm tra lại trên Console:* Vào lại trang chi tiết Hosted Zone `corp.internal`, kéo xuống tab **Hosted zone details** > Mục **VPCs** sẽ thấy hiển thị đầy đủ danh sách **cả 2 VPC** (`us-east-1` và `us-west-2`).

---

### Bước 1.4: Tạo các bản ghi DNS Record A bằng tay trên Console

Trong trang chi tiết Hosted Zone **`corp.internal`**:

1. **Tạo bản ghi cho máy chủ Web Cloud (`app.corp.internal`):**
   * Bấm nút màu cam **Create record**.
   * **Record name:** Nhập `app` (hệ thống tự động hiển thị FQDN: `app.corp.internal`).
   * **Record type:** Chọn **A - Routes traffic to an IPv4 address and some AWS resources**.
   * **Value:** Nhập địa chỉ IP Private của Cloud Workload: `10.20.10.50`.
   * **TTL (seconds):** Nhập `60`.
   * **Routing policy:** Giữ mặc định `Simple routing`.
   * Bấm **Create records**.

2. **Tạo tiếp bản ghi cho máy chủ Database On-Premises (`db.corp.internal`):**
   * Bấm lại nút **Create record**.
   * **Record name:** Nhập `db` (FQDN: `db.corp.internal`).
   * **Record type:** Chọn **A**.
   * **Value:** Nhập địa chỉ IP Private của On-Prem Workload: `10.10.10.50`.
   * **TTL (seconds):** Nhập `60`.
   * Bấm **Create records**.

---

### Bước 1.5: Kiểm thử phân giải tên miền 2 chiều từ Terminal máy trạm

Đăng nhập SSH vào máy **`ec2-onprem-strongswan`** (hoặc máy Workload `10.10.10.50`) và thực hiện kiểm thử:

```bash
# 1. Kiểm tra phân giải bằng lệnh dig:
dig +short app.corp.internal
# Kết quả trả về: 10.20.10.50

dig +short db.corp.internal
# Kết quả trả về: 10.10.10.50

# 2. Kiểm tra phân giải chi tiết bằng lệnh nslookup:
nslookup app.corp.internal
# Server: 10.10.0.2 (Amazon VPC DNS Resolver)
# Name:   app.corp.internal
# Address: 10.20.10.50

# 3. Kiểm thử truy cập ứng dụng Web Nginx qua FQDN:
curl -i http://app.corp.internal
# Kết quả mong đợi: HTTP/1.1 200 OK (Phản hồi từ Nginx Cloud qua hầm IPsec)
```

---

## PHẦN 2: THIẾT LẬP GIÁM SÁT HỆ THỐNG VỚI AMAZON CLOUDWATCH BẰNG TAY

### Bước 2.1: Xem và thu thập chỉ số vận hành (CloudWatch Metrics)
1. Đảm bảo góc trên bên phải hiển thị Region: **N. Virginia (`us-east-1`)**.
2. Trên thanh tìm kiếm, gõ **CloudWatch** > Chọn dịch vụ.
3. Ở menu trái, chọn **Metrics** > **All metrics**.
4. Chọn danh mục **EC2** > **Per-Instance Metrics**.
5. Nhập tên máy `ec2-cloud-strongswan` vào ô tìm kiếm và tích chọn:
   * `CPUUtilization`
   * `NetworkIn`
   * `NetworkOut`
6. Màn hình hiển thị đồ thị đường thể hiện lưu lượng mạng và tải CPU theo thời gian thực.

---

### Bước 2.2: Tạo CloudWatch Alarm cảnh báo CPU quá tải bằng tay

1. Ở menu bên trái của CloudWatch, chọn **Alarms** > **All alarms**.
2. Bấm nút màu cam **Create alarm**.
3. Bấm **Select metric** > Chọn **EC2** > **Per-Instance Metrics** > Tìm và chọn metric **CPUUtilization** của máy `ec2-cloud-strongswan` > Bấm **Select metric**.
4. Cấu hình thông số cảnh báo:
   * **Period:** Chọn `1 minute`.
   * **Threshold type:** Chọn **Static**.
   * **Whenever CPUUtilization is...:** Chọn **Greater/Equal (`>= threshold`)**.
   * **than...:** Nhập `80`.
   * Bấm **Next**.
5. Tại trang **Configure actions**:
   * Tạm thời chọn **Remove** ở mục Notification (do trong môi trường Lab không yêu cầu gửi email SNS để tránh lỗi phân quyền IAM).
   * Bấm **Next**.
6. Tại trang **Add name and description**:
   * **Alarm name:** Nhập `HybridVPN-HighCPU-CloudGateway`
   * **Alarm description:** `Cảnh báo khi CPU của Cloud strongSwan Gateway vượt quá 80%`
   * Bấm **Next** > Kéo xuống cuối bấm **Create alarm**.

---

### Bước 2.3: Tạo CloudWatch Alarm cảnh báo rớt kết nối VPN (NetworkOut)

1. Bấm lại **Create alarm** > Bấm **Select metric**.
2. Chọn **EC2** > **Per-Instance Metrics** > Tích chọn metric **NetworkOut** của máy `ec2-cloud-strongswan` > Bấm **Select metric**.
3. Cấu hình thông số:
   * **Period:** Chọn `5 minutes`.
   * **Threshold type:** Chọn **Static**.
   * **Whenever NetworkOut is...:** Chọn **Lower/Equal (`<= threshold`)**.
   * **than...:** Nhập `500` (bytes).
   * Bấm **Next** > Bấm **Next**.
4. Đặt tên Alarm:
   * **Alarm name:** `HybridVPN-LowNetwork-CloudGateway`
   * **Alarm description:** `Cảnh báo lưu lượng mạng giảm sâu, báo hiệu đứt kênh kết nối VPN`
   * Bấm **Next** > Bấm **Create alarm**.

*Lặp lại tương tự cho Region Oregon (`us-west-2`)* đối với máy `ec2-onprem-strongswan` để hoàn thiện giám sát 2 đầu.

---

## PHẦN 3: ĐO ĐẠC HIỆU NĂNG (iperf3) & KIỂM THỬ TỰ PHỤC HỒI (DPD)

### Bước 3.1: Đo băng thông thực tế qua hầm IPsec bằng `iperf3`

1. **Khởi động iperf3 Server trên máy Cloud Workload (`10.20.10.50`):**
   ```bash
   sudo apt-get update && sudo apt-get install -y iperf3
   iperf3 -s
   ```
2. **Chạy đo kiểm từ máy On-Premises Workload (`10.10.10.50`):**
   ```bash
   sudo apt-get update && sudo apt-get install -y iperf3
   # Đo băng thông trong 15 giây, báo cáo mỗi 1 giây:
   iperf3 -c 10.20.10.50 -t 15 -i 1
   ```
   *Đánh giá kết quả:* Băng thông xuyên lục địa Mỹ (Oregon -> N. Virginia) qua hầm IPsec đạt trung bình **~35 - 50 Mbps** với 0% packet loss. Kích thước TCP MSS được giới hạn tối ưu ở 1380 bytes chống phân mảnh gói tin.

---

### Bước 3.2: Kiểm thử cơ chế Dead Peer Detection (DPD) tự phục hồi (< 10s)

1. **Kiểm tra thông số DPD trong `/etc/ipsec.conf` trên máy Gateway:**
   ```ini
   dpddelay=10s
   dpdtimeout=30s
   dpdaction=restart
   ```
2. **Tiến hành thực nghiệm gián đoạn:**
   * *Cửa sổ 1 (trên máy Gateway On-Prem):* Chạy luồng ping liên tục có kèm timestamp:
     ```bash
     ping -i 1 10.20.10.50 | while read pong; do echo "$(date +'%H:%M:%S') $pong"; done
     ```
   * *Cửa sổ 2:* Thực hiện ngắt kết nối đường hầm để mô phỏng sự cố mạng:
     ```bash
     sudo ipsec down cloud-to-onprem
     ```
3. **Ghi nhận thời gian phục hồi:**
   * Luồng ping bị gián đoạn (Request timeout) trong khoảng **3 - 6 giây**.
   * Tham số `dpdaction=restart` kích hoạt ngay tiến trình gửi gói tin `IKE_SA_INIT`, thiết lập lại IKE SA và Child SA mới.
   * Kênh truyền tự động thông suốt trở lại mà không cần sự can thiệp thủ công của quản trị viên (< 10 giây).

---

## PHẦN 4: THỬ NGHIỆM VIRTUAL PRIVATE GATEWAY (VGW) ĐỂ QUAY DEMO & XÓA NGAY

> [!CAUTION]
> **Yêu cầu nghiêm ngặt về chi phí:** Tài nguyên AWS Virtual Private Gateway (VPN Connection) có mức phí **$0.05/giờ**. Sinh viên thực hiện tạo bằng tay để quay video demo và **bắt buộc phải thực hiện xóa sạch ngay sau buổi demo**.

### Bước 4.1: Tạo Virtual Private Gateway (VGW) trên Console
1. Tại Region **`us-east-1` (N. Virginia)**: Mở **VPC** > Menu trái chọn **Virtual private gateways**.
2. Bấm **Create virtual private gateway**:
   * **Name tag:** `Hybrid-Cloud-VPN-vgw-cloud`
   * **Autonomous System Number (ASN):** Chọn **Amazon default ASN**.
   * Bấm **Create virtual private gateway**.
3. Chọn VGW vừa tạo > Bấm **Actions** > **Attach to VPC** > Chọn `Hybrid-Cloud-VPN-vpc-cloud` > Bấm **Attach to VPC**.

---

### Bước 4.2: Tạo Customer Gateway (CGW)
1. Ở menu bên trái, chọn **Customer gateways** > Bấm **Create customer gateway**:
   * **Name:** `Hybrid-Cloud-VPN-cgw-onprem`
   * **BGP ASN:** Nhập `65000`
   * **IP address:** Nhập địa chỉ Public Elastic IP của máy `ec2-onprem-strongswan`.
   * Bấm **Create customer gateway**.

---

### Bước 4.3: Tạo Site-to-Site VPN Connection
1. Ở menu bên trái, chọn **Site-to-Site VPN connections** > Bấm **Create VPN connection**:
   * **Name tag:** `Hybrid-Cloud-VPN-vpn-vgw-demo`
   * **Target gateway type:** Chọn **Virtual private gateway** > Chọn `Hybrid-Cloud-VPN-vgw-cloud`.
   * **Customer gateway:** Chọn **Existing** > Chọn `Hybrid-Cloud-VPN-cgw-onprem`.
   * **Routing options:** Chọn **Static**.
   * **Static IP prefixes:** Nhập dải mạng On-Premises: `10.10.0.0/16`.
   * Bấm **Create VPN connection**.
2. Chờ kết nối chuyển sang trạng thái `available` (hoặc `pending`) để chụp ảnh và quay video thuyết minh so sánh giữa giải pháp 2 đầu phần mềm strongSwan và giải pháp 1 đầu VGW do AWS quản lý.

---

### Bước 4.4: QUY TRÌNH XÓA SẠCH VGW TRÊN CONSOLE (BẢO TOÀN CHI PHÍ $0.00)

Thực hiện tuần tự 4 thao tác xóa ngay sau khi quay xong video demo:

1. **Xóa VPN Connection:**
   * Vào **Site-to-Site VPN connections** > Chọn `Hybrid-Cloud-VPN-vpn-vgw-demo`.
   * Bấm **Actions** > **Delete VPN connection** > Nhập `delete` để xác nhận.
   * *Chờ trạng thái chuyển hẳn sang `deleted` (khoảng 1 - 2 phút).*
2. **Tách VGW khỏi VPC:**
   * Vào **Virtual private gateways** > Chọn `Hybrid-Cloud-VPN-vgw-cloud`.
   * Bấm **Actions** > **Detach from VPC** > Bấm **Detach**.
3. **Xóa VGW:**
   * Chọn lại VGW đó > Bấm **Actions** > **Delete virtual private gateway** > Nhập `delete`.
4. **Xóa Customer Gateway:**
   * Vào **Customer gateways** > Chọn `Hybrid-Cloud-VPN-cgw-onprem` > Bấm **Actions** > **Delete customer gateway**.

*Lệnh dọn dẹp tương đương trên CloudShell (chạy trong 10 giây):*
```bash
./infrastructure/teardown-week3-vgw.sh
```

---

## 5. BẢNG KIỂM KÊ 11 ẢNH MINH CHỨNG TUẦN 3

Mọi ảnh chụp màn hình nộp báo cáo phải hiển thị đầy đủ **Account ID: 8481-1379-6011**, **Region**, và **Thời gian hệ thống (Timestamp)**:

| STT | Tên file ảnh minh chứng | Mô tả chi tiết nội dung cần chụp |
| :---: | :--- | :--- |
| **01** | `01-route53-private-hosted-zone.png` | Màn hình Route 53 Console hiển thị Hosted Zone `corp.internal` kiểu Private |
| **02** | `02-route53-cross-vpc-associations.png` | Tab Hosted zone details hiển thị cả 2 VPC (`us-east-1` và `us-west-2`) được liên kết |
| **03** | `03-route53-dns-records.png` | Bảng bản ghi DNS hiển thị `app.corp.internal` (10.20.10.50) và `db.corp.internal` (10.10.10.50) |
| **04** | `04-dns-resolution-dig-nslookup.png` | Cửa sổ Terminal chạy lệnh `dig` và `nslookup` phân giải chính xác từ máy trạm |
| **05** | `05-http-curl-via-domain.png` | Lệnh `curl -i http://app.corp.internal` nhận phản hồi `HTTP 200 OK` từ Nginx qua hầm IPsec |
| **06** | `06-cloudwatch-metrics-ec2-gateway.png` | Đồ thị CloudWatch hiển thị đường sóng dữ liệu `CPUUtilization`, `NetworkIn`, `NetworkOut` |
| **07** | `07-cloudwatch-alarms-list.png` | Danh sách CloudWatch Alarms ở trạng thái xanh `OK` trên Console |
| **08** | `08-iperf3-throughput-benchmark.png` | Kết quả đo thông lượng băng thông `iperf3` giữa Oregon và N. Virginia |
| **09** | `09-dpd-resilience-recovery-test.png` | Nhật ký ping có timestamp chứng minh hầm tự hồi phục dưới 10 giây khi bị ngắt kết nối |
| **10** | `10-aws-vgw-vpn-connection-demo.png` | Màn hình VPC Console hiển thị Virtual Private Gateway và Site-to-Site VPN Connection |
| **11** | `11-vgw-teardown-zero-cost.png` | Minh chứng dọn dẹp sạch sẽ tài nguyên VGW, xác nhận trạng thái `deleted` bảo toàn ngân sách |

---

## 6. KỊCH BẢN VẤN ĐÁP GIẢNG VIÊN HƯỚNG DẪN (GVHD Q&A CHEATSHEET)

**Câu hỏi 1: Cơ chế Cross-VPC Association của Route 53 hoạt động như thế nào khi hai VPC ở hai Region khác nhau?**
> *Trả lời:* Route 53 là dịch vụ cấp Global của AWS. Khi tạo Private Hosted Zone, máy chủ quản lý ánh xạ domain với VPC DNS Resolver (`.2` IP) của từng mạng. Nhờ cơ chế Cross-VPC Association, Route 53 cho phép gán nhiều VPC ở các Region khác nhau vào cùng một vùng phân giải nội bộ. Khi một máy ảo tại Oregon gửi truy vấn DNS đến `10.10.0.2`, Resolver cục bộ sẽ nhận diện tên miền `corp.internal` thuộc Private Hosted Zone được liên kết và trả về trực tiếp IP `10.20.10.50` của AWS Cloud mà không cần thiết lập máy chủ BIND9 trung gian.

**Câu hỏi 2: Dead Peer Detection (DPD) hoạt động ra sao và vai trò của `dpdaction=restart`?**
> *Trả lời:* DPD kiểm tra tính khả dụng của đường hầm bằng cách gửi các gói thăm dò `IKE INFORMATIONAL` rỗng qua cổng UDP 500/4500 sau mỗi khoảng thời gian `dpddelay`. Nếu sau khoảng `dpdtimeout` đối tác không phản hồi, strongSwan xác định kênh đã chết. Với tùy chọn `dpdaction=restart`, daemon charon sẽ chủ động giải phóng Security Association (SA) cũ bị kẹt và tự động gửi gói `IKE_SA_INIT` mới để đàm phán lại hầm tức thời (dưới 10 giây), đảm bảo khả năng tự phục hồi mà không cần can thiệp thủ công.

**Câu hỏi 3: So sánh ưu và nhược điểm giữa giải pháp VPN phần mềm 2 đầu (strongSwan) và giải pháp tích hợp AWS Virtual Private Gateway (VGW)?**
> *Trả lời:* 
> - **strongSwan 2 đầu (Phần mềm):** Tiết kiệm tối đa chi phí (không tốn phí duy trì VPN $0.05/giờ của AWS), cho phép tùy biến sâu các thông số mật mã (AES-GCM, DH Group 14) và can thiệp nhân Linux với MSS Clamping để chống rớt gói; phù hợp cho các bài toán tối ưu ngân sách và môi trường lab.
> - **AWS VGW (Managed Service):** Tính sẵn sàng cao (High Availability) theo chuẩn doanh nghiệp với 2 tunnel độc lập (Active/Active hoặc Active/Standby), tích hợp sẵn tính năng Route Propagation vào bảng định tuyến Route Table của VPC, không cần bảo trì hệ điều hành máy ảo Gateway; tuy nhiên chi phí cố định phát sinh liên tục $0.05/giờ ($1.2/ngày/connection). Do đó trong đề tài này, nhóm ưu tiên dùng phần mềm 2 đầu và chỉ dựng VGW để demo đối sánh rồi xóa ngay.
