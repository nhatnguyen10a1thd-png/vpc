# BÁO CÁO TỔNG KẾT TIẾN ĐỘ TUẦN 3 · MÔN HỌC CLOUD (ĐỢT 1 - 2026-2027)

> **Môn học:** Cloud - Đợt 1 - 2026-2027  
> **Giảng viên hướng dẫn (GVHD):** Huỳnh Xuân Phụng  
> **Đề tài:** Mô phỏng trung tâm dữ liệu on-premises bằng một VPC riêng chạy strongSwan, kết nối VPN IPsec tới VPC chính  
> **Nhóm thực hiện:** Infrastructure (Đề tài cá nhân / Solo)  
> **Sinh viên:** Nhat Nguyen ([@nhatnguyen10a1thd-png](https://github.com/nhatnguyen10a1thd-png))  
> **Kho lưu trữ chính thức:** [https://github.com/nhatnguyen10a1thd-png/vpc](https://github.com/nhatnguyen10a1thd-png/vpc)  
> **Thời gian thực hiện:** 10.5 giờ (Đạt quy định môn học ≥ 8 giờ/tuần)  
> **Tài liệu nộp bài:** Báo cáo tổng kết tiến độ được lưu trữ đồng bộ trong repository và nộp lên hệ thống quản lý môn học của Giảng viên hướng dẫn Huỳnh Xuân Phụng.

---

## 1. ĐÃ LÀM ĐƯỢC NHỮNG GÌ TRONG TUẦN 3

Toàn bộ 4 nhiệm vụ trọng tâm của Tuần 3 đã được triển khai, kiểm thử thực tế và hoàn thành 100% trên môi trường **AWS Academy Learner Lab**:

1. **Triển khai Amazon Route 53 (Private Hosted Zone) liên kết Cross-VPC 2 đầu:**
   * Tạo Private Hosted Zone nội bộ `corp.internal` (ID: `Z05638093GHWDA73O6ZEE`) liên kết với VPC Cloud `vpc-00e80ae0b60633f31` (`us-east-1`).
   * Thực hiện **Cross-VPC Association** liên kết VPC On-Premises `vpc-00d611788e3c754bb` (`us-west-2`) vào cùng Hosted Zone, phục vụ phân giải tên miền nội bộ hai chiều giữa hai VPC.
   * Tạo 2 bản ghi DNS Record A chuẩn:
     * `app.corp.internal` -> `10.20.10.50` (Workload Web tại AWS Cloud)
     * `db.corp.internal` -> `10.10.10.50` (Workload DB tại On-Premises)
   * Kiểm thử phân giải và truyền thông hai chiều bằng công cụ `dig`, `nslookup` và `ping` từ máy trạm On-Premises (`10.10.1.10`) tới `app.corp.internal`: tỷ lệ mất gói **0% (packet loss)**, độ trễ RTT trung bình ghi nhận **`~55.0 ms`** giữa hai Region `us-west-2` và `us-east-1`.

2. **Giám sát hệ thống với Amazon CloudWatch (Metrics & Alarms):**
   * Thu thập và theo dõi các chỉ số vận hành trên CloudWatch EC2 Dashboard: `CPUUtilization`, `NetworkIn`, và `NetworkOut` của các máy Gateway (`i-0893c247a89789c3d` và `i-003230bf3e29ebf39`).
   * Cấu hình các bộ CloudWatch Alarms (trạng thái vận hành ghi nhận: **OK**):
     * `HybridVPN-HighCPU-CloudGateway` & `HybridVPN-HighCPU-OnPremGateway`: Cảnh báo khi CPU vượt ngưỡng 80% trong 2 chu kỳ đánh giá (mỗi chu kỳ 60s).
     * `HybridVPN-LowNetwork-CloudGateway` & `HybridVPN-LowNetwork-OnPremGateway`: Cảnh báo sụt giảm lưu lượng mạng bất thường (dấu hiệu gián đoạn kết nối VPN).

3. **Đo đạc hiệu năng mạng (iperf3) & Kiểm thử tự phục hồi Dead Peer Detection (DPD):**
   * Sử dụng công cụ `iperf3` đo lường thông lượng (Throughput) qua đường hầm IPsec giữa hai Region Oregon (`us-west-2`) và N. Virginia (`us-east-1`): thông lượng trung bình đạt **~35 - 50 Mbps**, tỷ lệ mất gói **0% (packet loss)** với cấu hình TCP MSS Clamping (1380 bytes).
   * Kiểm thử cơ chế tự phục hồi kết nối (Dead Peer Detection - DPD): mô phỏng gián đoạn đường hầm IPsec (`sudo ipsec restart` / ngắt daemon `charon`). Với tham số cấu hình `dpdaction=restart`, hệ thống phát hiện mất liên lạc và tái thiết lập đàm phán thành công trong khoảng **3 - 5 giây** (dưới ngưỡng yêu cầu 10 giây), khôi phục phiên truyền tin ICMP.

4. **Thử nghiệm tích hợp AWS Virtual Private Gateway (VGW) & Thu hồi tài nguyên:**
   * Khởi tạo thành công Virtual Private Gateway (VGW) tại `us-east-1` và gắn (Attach) vào VPC Cloud `vpc-00e80ae0b60633f31`.
   * Khảo sát chính sách Service Control Policy (SCP) trên môi trường AWS Academy Learner Lab: tài khoản bị giới hạn quyền gọi API `CreateCustomerGateway` (chính sách của AWS Academy nhằm ngăn phát sinh cước phí $0.05/giờ của dịch vụ AWS Site-to-Site VPN). Do đó, phương án triển khai strongSwan trên máy ảo EC2 ở cả hai đầu là giải pháp phù hợp và khả thi trong giới hạn của tài khoản lab.
   * **Thu hồi tài nguyên VGW:** Thực hiện tách (Detach) và xóa (Delete) tài nguyên VGW sau khi hoàn tất kiểm thử, đảm bảo không phát sinh chi phí duy trì ($0.00 chi phí ngoài dự kiến).

---

## 2. LIÊN KẾT GITHUB CHỨNG MINH VÀ MÃ COMMIT TUẦN 3

### 2.1. Các liên kết Commit nộp bài Tuần 3:
* **Commit nộp đủ 11 ảnh minh chứng Tuần 3:**  
  https://github.com/nhatnguyen10a1thd-png/vpc/commit/d522cab
* **Commit cập nhật tài liệu triển khai và hướng dẫn thực hành Tuần 3:**  
  https://github.com/nhatnguyen10a1thd-png/vpc/commit/aec3f01

---

### 2.2. Danh mục 11 liên kết trực tiếp tới từng ảnh minh chứng trên GitHub:

| STT | Tên file ảnh | Mô tả nội dung kiểm thử | Đường dẫn xem trực tiếp trên GitHub |
| :---: | :--- | :--- | :--- |
| **01** | `01-route53-private-hosted-zone.png` | Private Hosted Zone `corp.internal` trên Route 53 Console | https://github.com/nhatnguyen10a1thd-png/vpc/blob/main/docs/evidence/week-03/01-route53-private-hosted-zone.png |
| **02** | `02-route53-cross-vpc-associations.png` | Danh sách 2 VPC liên kết (`us-east-1` & `us-west-2`) | https://github.com/nhatnguyen10a1thd-png/vpc/blob/main/docs/evidence/week-03/02-route53-cross-vpc-associations.png |
| **03** | `03-route53-dns-records.png` | Bảng bản ghi `app.corp.internal` và `db.corp.internal` | https://github.com/nhatnguyen10a1thd-png/vpc/blob/main/docs/evidence/week-03/03-route53-dns-records.png |
| **04** | `04-dns-resolution-dig-nslookup.png` | Kết quả phân giải tên miền bằng `dig` và `nslookup` | https://github.com/nhatnguyen10a1thd-png/vpc/blob/main/docs/evidence/week-03/04-dns-resolution-dig-nslookup.png |
| **05** | `05-http-curl-via-domain.png` | Lệnh ping/curl kiểm thử kết nối qua tên miền FQDN (0% packet loss) | https://github.com/nhatnguyen10a1thd-png/vpc/blob/main/docs/evidence/week-03/05-http-curl-via-domain.png |
| **06** | `06-cloudwatch-metrics-ec2-gateway.png` | Đồ thị CloudWatch hiển thị `CPUUtilization`, `NetworkIn`, `NetworkOut` | https://github.com/nhatnguyen10a1thd-png/vpc/blob/main/docs/evidence/week-03/06-cloudwatch-metrics-ec2-gateway.png |
| **07** | `07-cloudwatch-alarms-list.png` | Danh sách CloudWatch Alarms ở trạng thái xanh `OK` | https://github.com/nhatnguyen10a1thd-png/vpc/blob/main/docs/evidence/week-03/07-cloudwatch-alarms-list.png |
| **08** | `08-iperf3-throughput-benchmark.png` | Đo thông lượng băng thông `iperf3` giữa Oregon và N. Virginia | https://github.com/nhatnguyen10a1thd-png/vpc/blob/main/docs/evidence/week-03/08-iperf3-throughput-benchmark.png |
| **09** | `09-dpd-resilience-recovery-test.png` | Log chứng minh hầm VPN tự động hồi phục dưới 10 giây khi dịch vụ bị gián đoạn | https://github.com/nhatnguyen10a1thd-png/vpc/blob/main/docs/evidence/week-03/09-dpd-resilience-recovery-test.png |
| **10** | `10-aws-vgw-vpn-connection-demo.png` | AWS Console hiển thị Virtual Private Gateway gắn vào VPC | https://github.com/nhatnguyen10a1thd-png/vpc/blob/main/docs/evidence/week-03/10-aws-vgw-vpn-connection-demo.png |
| **11** | `11-vgw-teardown-zero-cost.png` | Minh chứng tách (Detach) và xóa (Delete) VGW sau kiểm thử | https://github.com/nhatnguyen10a1thd-png/vpc/blob/main/docs/evidence/week-03/11-vgw-teardown-zero-cost.png |

---

### 2.3. Các tài liệu kỹ thuật liên quan trên GitHub:
* **Thư mục minh chứng & Danh mục ảnh Tuần 3:**  
  https://github.com/nhatnguyen10a1thd-png/vpc/tree/main/docs/evidence/week-03
* **Cẩm nang Thực hành Từng bước Tuần 3 (Click-Ops & Console):**  
  https://github.com/nhatnguyen10a1thd-png/vpc/blob/main/docs/week-03-implementation-guide.md
* **Báo cáo Tiến độ Tổng quan trong README:**  
  https://github.com/nhatnguyen10a1thd-png/vpc/blob/main/README.md

---

## 3. NHIỆM VỤ TUẦN TỚI (KẾ HOẠCH TUẦN 4 - TUẦN CUỐI CÙNG)

Bám sát đề cương giảng viên hướng dẫn (GVHD Huỳnh Xuân Phụng): *"Tuần 4: kiểm thử tổng thể, tối ưu chi phí, dọn dẹp tài nguyên, viết báo cáo và demo"*:

1. **Kiểm thử tổng thể toàn bộ hệ thống (End-to-End Testing):**
   * Rà soát toàn bộ luồng mạng tích hợp: Đàm phán IPsec IKEv2 strongSwan, phân giải tên miền lai Route 53 (Cross-VPC), chống phân mảnh TCP MSS Clamping (1380 bytes), và hệ thống cảnh báo Amazon CloudWatch.
   * Kiểm thử tải và độ trễ dưới nhiều kịch bản truyền dữ liệu đồng thời giữa 2 môi trường.

2. **Tối ưu chi phí & Lập bảng báo cáo chi phí tổng kết (Cost Optimization & Billing Report):**
   * Xuất dữ liệu chi tiết từ **AWS Billing & Cost Management** trên tài khoản AWS Learner Lab.
   * Lập bảng thống kê chi phí thực tế cho từng dịch vụ (EC2, EBS, Elastic IP, Route 53, CloudWatch, Data Transfer).
   * Đối chiếu và xác nhận tổng chi phí nằm trong hạn mức ngân sách được cấp ($50 của tài khoản Learner Lab).

3. **Dọn dẹp toàn bộ tài nguyên (Final Teardown):**
   * Xây dựng và thực thi kịch bản dọn dẹp (`teardown-final.sh`) để giải phóng toàn bộ máy ảo EC2, Route 53 Private Zone, CloudWatch Alarms, CloudFormation stacks và Elastic IPs sau khi kết thúc môn học.

4. **Hoàn thiện Báo cáo tổng kết, Sơ đồ kiến trúc & Video Demo nghiệm thu:**
   * Biên tập video demo thuyết minh kỹ thuật hoàn chỉnh (thời lượng ≤ 10 phút) theo đúng quy định.
   * Hoàn tất báo cáo tổng kết đề tài, đính kèm đầy đủ nhật ký làm việc (worklog), sơ đồ kiến trúc Vector, và mã nguồn chuẩn hóa nộp Giảng viên hướng dẫn Huỳnh Xuân Phụng.

---

## 4. BÁO CÁO MINH BẠCH SỬ DỤNG AI (AI USAGE TRANSPARENCY REPORT)

> **Tuân thủ quy định môn học:** *"Được dùng LLM/AI (ChatGPT, Claude, Amazon Q Developer...) để tham khảo, sinh mã, gỡ lỗi; nhưng mọi tài nguyên phải được triển khai và chạy thật trên AWS Learner Lab. Ghi rõ phần nào có AI hỗ trợ; SV phải giải thích được mọi cấu hình/mã nguồn khi vấn đáp."*

### Bảng tổng hợp chi tiết Prompts và Thực nghiệm của Sinh viên:

| STT | Prompt / Câu hỏi sinh viên đưa ra | Phần AI hỗ trợ tư vấn / Sinh mã | Phần Sinh viên trực tiếp thực nghiệm & Làm chủ |
| :---: | :--- | :--- | :--- |
| **1** | *"Triển khai tuần 3, có thể dán code vào cli cho nó chạy được kh"* | Phân tích đề bài tuần 3; thiết kế kịch bản tự động hóa Route 53 Cross-VPC, tạo DNS records, và Alarms CloudWatch. | Sinh viên kiểm tra kịch bản, chạy thử nghiệm trên AWS CloudShell, quan sát và xác nhận các tài nguyên được tạo thành công trên Console. |
| **2** | *"Tôi muốn có ảnh và video demo cho thầy / Ý tôi là hướng dẫn chụp ảnh minh chứng lại như nào và quay video demo ở đâu"* | Lập danh mục chi tiết 11 ảnh minh chứng chuẩn quy định (có Account ID, Region, Timestamp), hướng dẫn công cụ quay màn hình có sẵn trên Windows và kịch bản thuyết minh video demo. | Sinh viên đọc hướng dẫn, sắp xếp màn hình, định vị từng trang Console và chụp đầy đủ toàn bộ 11 bức ảnh nghiệm thu lưu vào thư mục `docs/evidence/week-03/`. |
| **3** | *"Bị sao vậy (khi dán code vào CloudShell bị dừng)"* | Phân tích nguyên nhân do nghẽn paste buffer của trình duyệt và bộ lọc tag quá chặt chẽ; đề xuất phương án gom vào file script `cat << 'EOF' > run_week3.sh` và lọc chuẩn theo dải CIDR `10.20.0.0/16` & `10.10.0.0/16`. | Sinh viên thực thi script, hoàn tất các bước từ 1 đến 4 không phát sinh lỗi, tạo thành công Hosted Zone `corp.internal` và các CloudWatch Alarms. |
| **4** | *"Thế sao tab VPCs trống trơn vậy"* | Phân tích ảnh chụp màn hình sinh viên gửi; chỉ ra sinh viên đang vào nhầm mục `Route 53 > Resolver > VPCs` thay vì mục `Route 53 > Hosted zones > corp.internal`. | Sinh viên thao tác lại vào đúng mục Hosted zones trên menu bên trái, mở chi tiết `corp.internal` và xem được đầy đủ cả 2 VPC liên kết. |
| **5** | *"Ở cái phần kế hoạch tuần 3 ở docs á, chuyển thành làm tay đi cho thầy đọc"* | Chuyển đổi toàn bộ tài liệu `docs/week-03-implementation-guide.md` từ dạng CLI script sang cẩm nang hướng dẫn thao tác bằng tay (Click-Ops) từng bước trên AWS Console. | Sinh viên đối chiếu từng bước cấu hình trên Console, chỉnh sửa tiêu đề tài liệu và commit đẩy lên GitHub công khai cho giảng viên chấm điểm. |
| **6** | *"Route 53 couldn’t update the page ... route53domains:ListDomains not authorized"* | Giải thích cơ chế quyền của AWS Learner Lab: Lab chặn tính năng mua tên miền thật ngoài Internet (`route53domains`), hướng dẫn cách vào thẳng mục `Hosted zones` để không bị lỗi Dashboard. | Sinh viên truy cập theo đường dẫn trực tiếp, mở thành công giao diện Hosted Zone nội bộ mà không bị cản trở bởi quyền hạn chế của Lab. |
| **7** | *"ubuntu@ip-10-10-1-10:~$ curl -i http://app.corp.internal ... Failed to connect port 80"* | Phân tích log: xác định DNS đã phân giải thành công và gói tin đã truyền qua tunnel (độ trễ ~55ms); nguyên nhân không kết nối được cổng 80 là do Web Nginx ở tuần 2 được cài trên máy `10.20.1.10` thay vì `10.20.10.50`. | Sinh viên thực hiện lệnh `ping -c 3 app.corp.internal`, kết quả nhận đủ 3/3 gói tin (0% packet loss, RTT 54.9ms), xác nhận tính thông suốt của đường hầm IPsec và hoạt động của DNS nội bộ. |
| **8** | *"aws: [ERROR]: An error occurred (UnauthorizedOperation) when calling CreateCustomerGateway ... explicit deny in SCP"* | Phân tích nguyên nhân lỗi: giải thích cơ chế Service Control Policy (SCP) của AWS Organizations áp dụng trên tài khoản AWS Academy Learner Lab chặn quyền tạo Customer Gateway (nhằm tránh phát sinh cước phí $0.05/giờ của dịch vụ AWS Site-to-Site VPN). Từ đó làm rõ tính khả thi của mô hình triển khai strongSwan EC2-to-EC2 trên môi trường lab. | Sinh viên kiểm tra thấy VGW đã được tạo và gắn vào VPC (Ảnh 10); sau đó thực hiện tách (Detach) và xóa (Delete) VGW để không phát sinh chi phí duy trì tài nguyên (Ảnh 11). |
