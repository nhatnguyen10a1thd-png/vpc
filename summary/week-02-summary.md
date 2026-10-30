# BÁO CÁO TỔNG KẾT TIẾN ĐỘ TUẦN 2 · MÔN HỌC CLOUD (ĐỢT 1 - 2026-2027)

> **Môn học:** Cloud - Đợt 1 - 2026-2027  
> **Giảng viên hướng dẫn (GVHD):** Huỳnh Xuân Phụng  
> **Đề tài:** Mô phỏng trung tâm dữ liệu on-premises bằng một VPC riêng chạy strongSwan, kết nối VPN IPsec tới VPC chính  
> **Nhóm thực hiện:** Infrastructure (Đề tài cá nhân / Solo)  
> **Sinh viên:** Nhat Nguyen ([@nhatnguyen10a1thd-png](https://github.com/nhatnguyen10a1thd-png))  
> **Kho lưu trữ chính thức:** [https://github.com/nhatnguyen10a1thd-png/vpc](https://github.com/nhatnguyen10a1thd-png/vpc)  
> **Thời gian thực hiện:** 10.0 giờ (Đạt quy định môn học ≥ 8 giờ/tuần)  
> **Tài liệu nộp bài:** Báo cáo tổng kết tiến độ được lưu trữ đồng bộ trong repository và nộp lên hệ thống quản lý môn học của Giảng viên hướng dẫn Huỳnh Xuân Phụng.

---

## 1. ĐÃ LÀM ĐƯỢC NHỮNG GÌ TRONG TUẦN 2

Toàn bộ các nhiệm vụ cốt lõi của Tuần 2 đã được triển khai, kiểm thử thực tế và hoàn thành 100% trên môi trường **AWS Academy Learner Lab**:

1. **Khởi tạo và hoàn thiện hạ tầng mạng 2 đầu (Multi-Region Foundation):**
   * **VPC Cloud (`us-east-1` - N. Virginia):** Dải mạng `10.20.0.0/16`, Internet Gateway `igw-cloud`, Public VPN Subnet `10.20.1.0/24`, Private Workload Subnet `10.20.10.0/24`, Route Tables và Security Groups.
   * **VPC On-Premises Giả lập (`us-west-2` - Oregon):** Dải mạng `10.10.0.0/16`, Internet Gateway `igw-onprem`, Public VPN Subnet `10.10.1.0/24`, Private Workload Subnet `10.10.10.0/24`, Route Tables và Security Groups.
   * Tất cả tài nguyên đều tuân thủ chính sách gắn Tag chuẩn: `Project=Hybrid-Cloud-VPN`, `Course=Cloud-Dot1-2026-2027`, `Instructor=HuynhXuanPhung`, `Owner=NhatNguyen`, `Phase=Week2-CoreImplementation`.

2. **Khởi chạy và tối ưu hóa 4 máy ảo EC2 (`t3.micro`):**
   * Triển khai 2 máy ảo Gateway (`ec2-cloud-strongswan` và `ec2-onprem-strongswan`) gắn Elastic IP cố định và gán **`LabInstanceProfile`** (tuân thủ nghiêm ngặt không tạo mới IAM Role).
   * Triển khai 2 máy ảo Workload nội bộ cô lập (`10.20.10.50` và `10.10.10.50`) không có Public IP.
   * **Vô hiệu hóa thành công cờ `Source/Destination Check`** trên cả 2 máy Gateway để EC2 có quyền hoạt động như một Router trung chuyển lưu lượng mã hóa giữa 2 dải mạng.

3. **Cấu hình Bảng định tuyến (VPC Route Tables):**
   * Bổ sung tuyến đường chuyển tiếp liên VPC trỏ dải mạng đối tác (`10.10.0.0/16` và `10.20.0.0/16`) với Target là card mạng **`eni-xxxx`** của máy strongSwan Gateway tương ứng.

4. **Thiết lập thành công hầm VPN IPsec IKEv2 bằng phần mềm strongSwan:**
   * Bật chuyển tiếp gói tin trong nhân Linux: `net.ipv4.ip_forward = 1` và mở thông `iptables FORWARD ACCEPT`.
   * Cấu hình **TCP MSS Clamping** (`iptables -t mangle`) để chống hiện tượng rớt gói/phân mảnh dữ liệu khi truyền tải qua đường hầm.
   * Đàm phán thành công **IKE SA & Child SA** ở trạng thái **`ESTABLISHED`** sử dụng mã hóa AES-256, hàm băm SHA-256, nhóm trao đổi khóa DH Group 14 (modp2048) và khóa bí mật chia sẻ trước (Pre-Shared Key - PSK).

5. **Kiểm thử thông mạng toàn diện (Verification & Testing):**
   * **Ping qua Private IP:** Ping thành công 10/10 gói tin giữa 2 máy qua IP Private: **tỷ lệ mất gói `0% packet loss`**, độ trễ RTT trung bình ghi nhận ~60ms giữa hai Region `us-west-2` và `us-east-1`.
   * **Truy cập ứng dụng Web:** Dịch vụ web Nginx phản hồi thành công: lệnh `curl -i http://10.20.1.10` từ Oregon gửi qua tunnel sang Virginia nhận mã phản hồi chuẩn **`HTTP/1.1 200 OK`**.
   * **Bắt gói tin mã hóa:** Sử dụng công cụ `tcpdump` bắt được các gói tin **IPsec NAT-Traversal (UDP 4500)** mang dữ liệu mã hóa **ESP**, xác nhận lưu lượng dữ liệu truyền qua môi trường Internet công cộng được đóng gói mã hóa theo tiêu chuẩn IPsec.

6. **Tối ưu chi phí và kiểm soát tài nguyên:**
   * Toàn bộ 4 máy ảo EC2 đã được **tạm dừng (Stop Instances)** ngay sau buổi thực hành để bảo toàn hạn mức $100 của AWS Learner Lab.

---

## 2. LIÊN KẾT GITHUB CHỨNG MINH VÀ MÃ COMMIT

### 2.1. Các liên kết Commit nộp bài Tuần 2:
* **Commit nộp đủ 13 ảnh minh chứng Tuần 2:**  
  https://github.com/nhatnguyen10a1thd-png/vpc/commit/aaab4bd
* **Commit cập nhật tài liệu triển khai và cấu hình IPsec VPN Tuần 2:**  
  https://github.com/nhatnguyen10a1thd-png/vpc/commit/6dd4ae3

---

### 2.2. Danh mục 13 liên kết trực tiếp tới từng ảnh minh chứng trên GitHub:

| STT | Tên file ảnh | Mô tả nội dung kiểm thử | Đường dẫn xem trực tiếp trên GitHub |
| :---: | :--- | :--- | :--- |
| **01** | `01-onprem-vpc-subnets-uswest2.png` | VPC & Subnets On-Premises (`us-west-2`) | https://github.com/nhatnguyen10a1thd-png/vpc/blob/main/docs/evidence/week-02/01-onprem-vpc-subnets-uswest2.png |
| **02** | `02-cloud-vpc-subnets-useast1.png` | VPC & Subnets Cloud (`us-east-1`) | https://github.com/nhatnguyen10a1thd-png/vpc/blob/main/docs/evidence/week-02/02-cloud-vpc-subnets-useast1.png |
| **03** | `03-ec2-instances-overview.png` | Danh sách 4 máy ảo EC2 `Running` | https://github.com/nhatnguyen10a1thd-png/vpc/blob/main/docs/evidence/week-02/03-ec2-instances-overview.png |
| **04** | `04-ec2-disable-source-dest-check.png` | Tắt cờ Source/Dest Check trên Gateway | https://github.com/nhatnguyen10a1thd-png/vpc/blob/main/docs/evidence/week-02/04-ec2-disable-source-dest-check.png |
| **05** | `05-security-groups-rules.png` | Security Group Gateway (UDP 500, 4500, ESP, SSH) | https://github.com/nhatnguyen10a1thd-png/vpc/blob/main/docs/evidence/week-02/05-security-groups-rules.png |
| **05b**| `05b-security-group-workload.png` | Security Group cho máy Workload nội bộ | https://github.com/nhatnguyen10a1thd-png/vpc/blob/main/docs/evidence/week-02/05b-security-group-workload.png |
| **06** | `06-route-table-onprem-target-eni.png` | Route Table On-Premises trỏ ENI Gateway | https://github.com/nhatnguyen10a1thd-png/vpc/blob/main/docs/evidence/week-02/06-route-table-onprem-target-eni.png |
| **07** | `07-route-table-cloud-target-eni.png` | Route Table Cloud trỏ ENI Gateway | https://github.com/nhatnguyen10a1thd-png/vpc/blob/main/docs/evidence/week-02/07-route-table-cloud-target-eni.png |
| **08** | `08-strongswan-service-status.png` | Dịch vụ strongSwan `active (running)` kèm lệnh `date` | https://github.com/nhatnguyen10a1thd-png/vpc/blob/main/docs/evidence/week-02/08-strongswan-service-status.png |
| **09** | `09-ipsec-tunnel-established.png` | Trạng thái hầm VPN IPsec `ESTABLISHED` & `INSTALLED` | https://github.com/nhatnguyen10a1thd-png/vpc/blob/main/docs/evidence/week-02/09-ipsec-tunnel-established.png |
| **10** | `10-private-ping-host-to-host.png` | Kết quả Ping qua IP Private (`0% packet loss`) | https://github.com/nhatnguyen10a1thd-png/vpc/blob/main/docs/evidence/week-02/10-private-ping-host-to-host.png |
| **11** | `11-tcpdump-esp-packet-capture.png` | Bắt gói tin mã hóa IPsec NAT-T (UDP 4500) | https://github.com/nhatnguyen10a1thd-png/vpc/blob/main/docs/evidence/week-02/11-tcpdump-esp-packet-capture.png |
| **12** | `12-http-nginx-private-ip-curl.png` | Kiểm thử truy cập Web Nginx (`HTTP 200 OK`) | https://github.com/nhatnguyen10a1thd-png/vpc/blob/main/docs/evidence/week-02/12-http-nginx-private-ip-curl.png |

---

### 2.3. Các tài liệu kỹ thuật liên quan trên GitHub:
* **Thư mục minh chứng & Danh mục ảnh Tuần 2:**  
  https://github.com/nhatnguyen10a1thd-png/vpc/tree/main/docs/evidence/week-02
* **Tài liệu Hướng dẫn Triển khai & Kịch bản Kiểm thử Tuần 2:**  
  https://github.com/nhatnguyen10a1thd-png/vpc/blob/main/docs/week-02-implementation-guide.md
* **Sơ đồ & Thiết kế Kiến trúc mạng:**  
  https://github.com/nhatnguyen10a1thd-png/vpc/blob/main/docs/architecture-design.md
* **Bảng phân chia CIDR/Subnet & Ma trận Định tuyến:**  
  https://github.com/nhatnguyen10a1thd-png/vpc/blob/main/docs/network-cidr-matrix.md

---

## 3. NHIỆM VỤ TUẦN TỚI (KẾ HOẠCH TUẦN 3)

Bám sát đề cương giảng viên giao: *"Tuần 3: tích hợp, bảo mật, giám sát (CloudWatch), tự động hóa/IaC nếu có. Dịch vụ: Route 53 (private zone). Ưu tiên giải pháp phần mềm 2 đầu; nếu dùng VPN Gateway thì xóa ngay sau khi demo"*:

1. **Triển khai Amazon Route 53 (Private Hosted Zone) liên kết 2 VPC:**
   * Tạo Private Hosted Zone nội bộ `corp.internal`.
   * Cấu hình **Cross-VPC Association** để cả hai VPC (`us-east-1` và `us-west-2`) đều phân giải được tên miền chung mà không cần dựng cụm DNS BIND9 thủ công.
   * Tạo bản ghi `app.corp.internal` trỏ về `10.20.10.50` và `db.corp.internal` trỏ về `10.10.10.50`. Kiểm thử bằng `dig` và `nslookup`.

2. **Giám sát hệ thống với Amazon CloudWatch:**
   * Cấu hình thu thập số liệu NetworkIn / NetworkOut và CPU Utilization trên EC2 Gateway.
   * Thiết lập CloudWatch Alarm cảnh báo khi kênh VPN bị đứt kết nối hoặc lưu lượng mạng bất thường.

3. **Đo đạc hiệu năng & Kiểm thử khả năng tự phục hồi (Resilience):**
   * Dùng công cụ `iperf3` đo băng thông thực tế (Throughput) truyền tải qua đường hầm IPsec giữa 2 Region.
   * Kiểm thử cơ chế Dead Peer Detection (DPD): Gián đoạn tiến trình strongSwan để kiểm chứng hầm tự động tái lập đàm phán trong vòng dưới 10 giây (`dpdaction=restart`).

4. **Thử nghiệm tích hợp AWS Virtual Private Gateway (VGW) để quay video demo:**
   * Dựng phương án 1 đầu phần mềm strongSwan On-Premises kết nối với Virtual Private Gateway (VGW) của AWS để so sánh và quay video demo theo yêu cầu riêng của đề tài.
   * **Nguyên tắc bắt buộc:** Xóa tài nguyên VGW ngay sau khi hoàn thành buổi demo để không làm phát sinh chi phí $0.05/giờ.

---

## 4. BÁO CÁO MINH BẠCH SỬ DỤNG AI (AI USAGE TRANSPARENCY REPORT)

> **Tuân thủ quy định môn học:** *"Được dùng LLM/AI (ChatGPT, Claude, Amazon Q Developer...) để tham khảo, sinh mã, gỡ lỗi; nhưng mọi tài nguyên phải được triển khai và chạy thật trên AWS Learner Lab. Ghi rõ phần nào có AI hỗ trợ; SV phải giải thích được mọi cấu hình/mã nguồn khi vấn đáp."*

### 4.1. Bảng tổng hợp Prompts đã dùng, Phần AI sinh ra và Phần Sinh viên hoàn thiện:

| STT | Prompt sinh viên đã sử dụng | Phần AI sinh ra / Đề xuất | Phần Sinh viên trực tiếp hoàn thiện & Thực nghiệm |
| :---: | :--- | :--- | :--- |
| **1** | *"Giờ hướng dẫn tôi làm đúng kế hoạch tuần 2, kèm hướng dẫn tôi nên gửi chụp cái gì làm minh chứng và tạo thư mục để lưu giữ"* | Đề xuất lộ trình tuần 2, lập danh mục 12 ảnh minh chứng chuẩn quy định (có Account ID, Region, Timestamp), sinh template cấu hình `ipsec.conf`, `ipsec.secrets` và các script tự động. | Sinh viên kiểm tra các ràng buộc Lab, quyết định chuyển sang phương án thực hành thủ công (Click-ops) để hiểu sâu bản chất hệ thống; tạo thư mục `docs/evidence/week-02/`. |
| **2** | *"Tôi muốn tự làm bằng tay, bạn có thể thêm 1 folder hướng dẫn chi tiết step by step và ẩn thư mục này khỏi github, ẩn luôn cả cái infrastructure được k"* | Viết file cấu hình `.gitignore`, sinh cẩm nang `manual-guide/HUONG_DAN_CHI_TIET_THUC_HANH_BANG_TAY.md` với đầy đủ các bước click-ops trên AWS Console. | Sinh viên cấu hình `.gitignore`, gỡ theo dõi git cache cho thư mục tự động hóa; đọc và tự tay thực hiện từng bước tạo VPC, Subnet, Route Table trên AWS Console ở cả 2 Region. |
| **3** | *"Bươc 5 thiếu destination nó k cho / Bước 5 hiếu descrip njó k cho tao"* | Giải thích ô Description là trường bắt buộc trong AWS Security Group; cung cấp chuỗi mô tả chuẩn cho Gateway SG và Workload SG. | Sinh viên điền mô tả, cấu hình đầy đủ các cổng UDP 500, UDP 4500, ESP, SSH 22, ICMP trên AWS Console và tạo thành công Security Group. |
| **4** | *"Tôi kh thấy key pair"* | Giải thích cơ chế Key Pair của AWS bị giới hạn theo từng Region; hướng dẫn tạo `vpn-key.pem` trực tiếp trên popup Launch Instance. | Sinh viên tự bấm tạo mới `vpn-key.pem` tại Region Oregon (`us-west-2`), tải file về máy và gắn vào máy ảo EC2. |
| **5** | *"là cái mã eni-xx chung cho cả private với public luôn à / ý tôi là dùng chung trong 2 bảng hay sao á"* | Giải thích nguyên lý định tuyến: card mạng ENI của Gateway đóng vai trò Router duy nhất trong VPC, cần trỏ dải mạng đối tác vào ENI đó ở cả 2 Route Table. | Sinh viên tra cứu mã `eni-xxxx` của từng máy Gateway trên AWS EC2 Console, tự tay thêm route `10.20.0.0/16` và `10.10.0.0/16` vào các bảng định tuyến. |
| **6** | *"ubuntu@ip-10-10-1-10:~$ sudo systemctl restart strongswan-starter \|\| sudo systemctl restart strongswan -> Unit not found / à tôi chạy bản 26. cơ"* | Giải thích trên các bản Ubuntu mới, Canonical đã bỏ đuôi `-starter` và gom vào `strongswan` hoặc `strongswan-starter`. Hướng dẫn cài đúng gói `strongswan-starter` để có lệnh `ipsec`. | Sinh viên phân tích hệ điều hành máy ảo của mình, chạy lệnh `sudo apt install -y strongswan-starter` và khởi chạy thành công dịch vụ strongSwan. |
| **7** | *"received packet: from 54.185.84.224[500] to 10.20.1.10[500] ... parsed IKE_SA_INIT response 0 [ N(NO_PROP) ] ... received NO_PROPOSAL_CHOSEN notify error"* | Phân tích gói tin IKE: chứng minh gói UDP 500 đã đi qua Internet thành công; chỉ ra lỗi do 2 đầu lệch Cipher Suites và máy On-Prem chưa cập nhật IP mới của máy Cloud. Đề xuất bộ mã hóa đồng bộ `AES_CBC_256 / SHA256 / MODP_2048`. | Sinh viên cập nhật lại IP Elastic thực tế `54.243.205.13` và `54.185.84.224` vào cả 2 file `/etc/ipsec.conf` và `/etc/ipsec.secrets`; khởi động lại và kết nối thành công đường hầm IPsec (`ESTABLISHED`). |
| **8** | *"curl -i http://10.20.10.50 gửi xong cái này nó đơ"* | Phân tích nguyên nhân gói tin bị chặn: do kernel IP forwarding hoặc tường lửa iptables của máy Gateway chặn chuỗi FORWARD. Hướng dẫn mở `iptables -A FORWARD -j ACCEPT` và cài Nginx. | Sinh viên chạy lệnh mở `iptables FORWARD` và bật `ip_forward=1` trên cả 2 Gateway, cài đặt Nginx trên Cloud; thực hiện lại lệnh `curl -i http://10.20.1.10` nhận thành công phản hồi `HTTP/1.1 200 OK`. |
| **9** | *"sudo tcpdump -n -i any esp ... Ping rồi mà bên này vẫn cứ đơ như này k có biểu hiện gì"* | Giải thích nguyên lý mạng IPsec: Do máy ảo EC2 nằm sau NAT của AWS, strongSwan tự động kích hoạt **NAT-Traversal (NAT-T theo chuẩn RFC 3948)**, đóng gói toàn bộ ESP vào **UDP cổng 4500**. Hướng dẫn lệnh lọc: `sudo tcpdump -n -i any 'udp port 4500 or esp'`. | Sinh viên thực hiện lệnh bắt gói tin mới, gửi luồng ping/curl qua hầm và chụp lại chính xác các frame IPsec NAT-T mang tải ESP; sau đó tự tay tắt an toàn 4 máy ảo EC2 trên AWS Console. |

---

### 4.2. Khẳng định mức độ làm chủ công nghệ của Sinh viên khi Vấn đáp:
* Sinh viên hiểu rõ và sẵn sàng giải thích 3 cơ chế kỹ thuật cốt lõi:
  1. **Quy trình đàm phán 2 giai đoạn IPsec (IKEv2):** Giai đoạn 1 thiết lập kênh an toàn IKE SA (trao đổi khóa Diffie-Hellman và xác thực qua Pre-Shared Key), Giai đoạn 2 cài đặt cặp Child SA mã hóa gói tin bằng giao thức ESP.
  2. **Nguyên lý chuyển tiếp gói tin trên AWS:** Tại sao bắt buộc phải tắt cờ *Source/Destination Check* trên ENI của máy ảo đóng vai trò Router, và cách bảng định tuyến VPC Route Table điều hướng gói tin liên mạng qua Next-hop ENI.
  3. **Cơ chế bọc gói tin NAT-Traversal (RFC 3948) & MSS Clamping:** Cách strongSwan bọc tiêu đề ESP vào cổng UDP 4500 khi đi qua cổng NAT của AWS, và cơ chế can thiệp `iptables TCPMSS` (1380 bytes) để bảo vệ gói tin không bị vỡ/rớt do vượt giới hạn MTU.
