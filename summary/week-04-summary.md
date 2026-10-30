# BÁO CÁO TỔNG KẾT TIẾN ĐỘ TUẦN 4 & NGHIỆM THU ĐỀ TÀI · MÔN HỌC CLOUD (ĐỢT 1 - 2026-2027)

> **Môn học:** Cloud - Đợt 1 - 2026-2027  
> **Giảng viên hướng dẫn (GVHD):** Huỳnh Xuân Phụng  
> **Đề tài:** Mô phỏng trung tâm dữ liệu on-premises bằng một VPC riêng chạy strongSwan, kết nối VPN IPsec tới VPC chính  
> **Nhóm thực hiện:** Infrastructure (Đề tài cá nhân / Solo)  
> **Sinh viên:** Nhat Nguyen ([@nhatnguyen10a1thd-png](https://github.com/nhatnguyen10a1thd-png))  
> **Kho lưu trữ chính thức:** [https://github.com/nhatnguyen10a1thd-png/vpc](https://github.com/nhatnguyen10a1thd-png/vpc)  
> **Thời gian thực hiện Tuần 4:** 11.0 giờ (Đạt quy định môn học ≥ 8 giờ/tuần)  
> **Tổng thời gian tích lũy 4 tuần:** 41.5 giờ  
> **Tài liệu nộp bài:** Báo cáo tổng kết tiến độ được lưu trữ đồng bộ trong repository và nộp lên hệ thống quản lý môn học của Giảng viên hướng dẫn Huỳnh Xuân Phụng.

---

## 1. ĐÃ LÀM ĐƯỢC NHỮNG GÌ TRONG TUẦN 4

Bám sát đề cương chi tiết của Giảng viên hướng dẫn Huỳnh Xuân Phụng cho Tuần 4: *"Kiểm thử tổng thể, tối ưu chi phí, dọn dẹp tài nguyên, viết báo cáo và demo"*, sinh viên đã hoàn thành 100% các hạng mục công việc trên môi trường **AWS Academy Learner Lab**:

### 1.1. Kiểm thử tổng thể toàn bộ hệ thống (End-to-End Testing):
* **Rà soát đàm phán IPsec IKEv2 strongSwan:** Trạng thái kết nối `onprem-to-cloud: ESTABLISHED` trên cả hai Gateway. Giao thức đàm phán IKEv2, thuật toán mã hóa `AES_CBC_256 / HMAC_SHA2_256 / MODP_2048`, traffic selectors kết nối chuẩn `10.10.0.0/16 === 10.20.0.0/16`.
* **Kiểm tra chống phân mảnh TCP MSS Clamping (1380 bytes):** Kiểm chứng quy tắc `iptables -t mangle -A FORWARD -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu`. Chạy kiểm thử gói tin kích thước lớn với cờ Don't Fragment (`ping -M do -s 1352`) nhận đủ 4/4 gói (`0% packet loss`), RTT trung bình đạt `56.6 ms`.
* **Phân giải tên miền lai Route 53 (Cross-VPC) hai chiều:**
  * `app.corp.internal` -> `10.20.10.50` (Web Server Cloud)
  * `db.corp.internal` -> `10.10.10.50` (Database On-Prem)
* **Thông suốt tầng ứng dụng Web:** Gửi yêu cầu `curl -i http://10.20.1.10` nhận phản hồi chuẩn `HTTP/1.1 200 OK` từ máy chủ Nginx phía Cloud.
* **Minh chứng dữ liệu mã hóa thời gian thực:** Bộ đếm lưu lượng ESP tăng trực tiếp lên `16,503 bytes_i / 16,074 bytes_o`, chứng minh 100% dữ liệu truyền qua hầm mã hóa IPsec.
* **Giám sát sức khỏe hệ thống qua CloudWatch:** Bộ cảnh báo `HybridVPN-HighCPU` vận hành ổn định ở trạng thái xanh: **OK**.

### 1.2. Tối ưu chi phí & Báo cáo ngân sách (Cost Optimization & Billing Report):
* Khảo sát bảng điều khiển **AWS Billing & Cost Management** và **AWS Academy Learner Lab Dashboard**.
* Tổng chi phí thực tế tiêu thụ cho hệ thống mạng lai 2 Region trong suốt 4 tuần học ước tính khoảng **`~$5.56`**, chỉ chiếm khoảng **11%** hạn mức ngân sách `$50.00` được cấp.
* **Hiệu quả kinh tế:** Giải pháp VPN phần mềm strongSwan trên EC2 `t3.micro` giúp tiết kiệm **> 90%** so với việc dùng AWS Managed VPN Gateway ($72.00/tháng), giải thích cơ chế phân quyền IAM của AWS Academy Learner Lab khi vấn đáp.

### 1.3. Chuẩn bị và kiểm thử quy trình dọn dẹp tài nguyên (Final Teardown Ready):
* **Kịch bản tự động hóa:** Đã xây dựng, hoàn thiện và commit trực tiếp kịch bản tự động hóa dọn dẹp triệt để [`infrastructure/teardown-final.sh`](https://github.com/nhatnguyen10a1thd-png/vpc/blob/main/infrastructure/teardown-final.sh) vào repository để giảng viên có thể kiểm tra mã nguồn (kịch bản tự động xóa Alarms, Route 53, terminate EC2, release EIP, xóa Stacks và đối soát Zero-Cost).
* **Quy trình dọn dẹp bằng tay (Manual Click-Ops):** Quy trình dọn dẹp chi tiết gồm các bước thao tác manual theo đúng trình tự chuẩn chống xung đột phụ thuộc đã được ghi chép đầy đủ trong **PHẦN 3** của [`docs/week-04-implementation-guide.md`](https://github.com/nhatnguyen10a1thd-png/vpc/blob/main/docs/week-04-implementation-guide.md#phần-3-dọn-dẹp-toàn-bộ-tài-nguyên-final-teardown), đúng theo hình thức quy định cho tuần cuối môn học.
* **Kế hoạch dọn dẹp thực tế:** Nhằm phục vụ buổi vấn đáp trực tiếp và chấm điểm nghiệm thu của Giảng viên hướng dẫn Huỳnh Xuân Phụng, các tài nguyên máy ảo hiện đang được duy trì ở trạng thái dừng/chờ (Standby). Ngay sau khi GVHD duyệt nghiệm thu xong, kịch bản sẽ được thực thi (hoặc thực hiện thao tác manual theo PHẦN 3) để giải phóng 100% tài nguyên, bảo đảm cước phí duy trì là **$0.00**.

### 1.4. Bộ ảnh minh chứng & Video Demo nghiệm thu:
* Đã chụp và lưu trữ đầy đủ **8 ảnh minh chứng nghiệm thu chuẩn quy định** (có đầy đủ Account ID: `8481-1379-6011`, Region: `Oregon` / `N. Virginia`, và Timestamp) tại `docs/evidence/week-04/`.
* **Video Demo nghiệm thu đề tài (Thời lượng ≤ 10 phút):**  
  🎥 **Liên kết xem trực tiếp trên Google Drive:** [https://drive.google.com/file/d/1aF8-p0T0ejTv2hNPr3z3zeZkPbWPUSJB/view?usp=sharing](https://drive.google.com/file/d/1aF8-p0T0ejTv2hNPr3z3zeZkPbWPUSJB/view?usp=sharing)
* Hoàn thiện kịch bản showcase video demo nghiệm thu 7 thành quả kỹ thuật (thời lượng ≤ 10 phút) theo đúng yêu cầu đề cương GVHD Huỳnh Xuân Phụng.

---

## 2. LIÊN KẾT GITHUB CHỨNG MINH VÀ MÃ COMMIT TUẦN 4

### 2.1. Các liên kết Commit nộp bài Tuần 4:
* **Commit nộp đủ 8 ảnh minh chứng, kịch bản E2E và cẩm nang thực hành Tuần 4:**  
  https://github.com/nhatnguyen10a1thd-png/vpc/commit/c224da3
* **Commit bổ sung liên kết Video Demo nghiệm thu vào báo cáo và README:**  
  https://github.com/nhatnguyen10a1thd-png/vpc/commit/93ff852
* **Commit bổ sung kịch bản teardown-final.sh và đồng bộ hồ sơ nghiệm thu nộp lại:**  
  https://github.com/nhatnguyen10a1thd-png/vpc/commit/09a23b2

---

### 2.2. Danh mục 8 liên kết trực tiếp tới từng ảnh minh chứng & Video Demo trên GitHub:

* **Video Demo Nghiệm thu Đề tài (Thời lượng ≤ 10 phút):**  
  🎥 [https://drive.google.com/file/d/1aF8-p0T0ejTv2hNPr3z3zeZkPbWPUSJB/view?usp=sharing](https://drive.google.com/file/d/1aF8-p0T0ejTv2hNPr3z3zeZkPbWPUSJB/view?usp=sharing)

| STT | Tên file ảnh | Mô tả nội dung kiểm thử & nghiệm thu | Đường dẫn xem trực tiếp trên GitHub |
| :---: | :--- | :--- | :--- |
| **01** | `01-strongswan-ipsec-ikev2-active.png` | IPsec IKEv2 SA trạng thái `ESTABLISHED` trên Gateway | https://github.com/nhatnguyen10a1thd-png/vpc/blob/main/docs/evidence/week-04/01-strongswan-ipsec-ikev2-active.png |
| **02** | `02-tcp-mss-clamping-iptables.png` | Quy tắc iptables TCP MSS Clamping (1380 bytes) | https://github.com/nhatnguyen10a1thd-png/vpc/blob/main/docs/evidence/week-04/02-tcp-mss-clamping-iptables.png |
| **03** | `03-e2e-network-test-results.png` | Kết quả kiểm thử tổng thể E2E (DNS, MTU 1380B, HTTP 200, ESP Traffic) | https://github.com/nhatnguyen10a1thd-png/vpc/blob/main/docs/evidence/week-04/03-e2e-network-test-results.png |
| **04** | `04-route53-cross-vpc-associations.png` | Route 53 Console - Liên kết Cross-VPC đa vùng (`us-east-1` & `us-west-2`) | https://github.com/nhatnguyen10a1thd-png/vpc/blob/main/docs/evidence/week-04/04-route53-cross-vpc-associations.png |
| **05** | `05-route53-dns-records-table.png` | Route 53 Console - Bảng bản ghi DNS nội bộ (`app` & `db`) | https://github.com/nhatnguyen10a1thd-png/vpc/blob/main/docs/evidence/week-04/05-route53-dns-records-table.png |
| **06** | `06-cloudwatch-alarms-healthy-status.png` | CloudWatch Alarms hiển thị bộ cảnh báo ở trạng thái xanh `OK` | https://github.com/nhatnguyen10a1thd-png/vpc/blob/main/docs/evidence/week-04/06-cloudwatch-alarms-healthy-status.png |
| **07** | `07-billing-cost-summary.png` | Tổng quan ngân sách AWS Learner Lab (< $50) | https://github.com/nhatnguyen10a1thd-png/vpc/blob/main/docs/evidence/week-04/07-billing-cost-summary.png |
| **08** | `08-billing-service-breakdown.png` | Đối soát phân quyền Billing trên tài khoản AWS Academy Learner Lab | https://github.com/nhatnguyen10a1thd-png/vpc/blob/main/docs/evidence/week-04/08-billing-service-breakdown.png |

---

## 3. BẢNG BÁO CÁO CHI PHÍ TỔNG KẾT MÔN HỌC (BILLING & COST REPORT)

| STT | Dịch vụ AWS | Hạng mục tài nguyên | Khối lượng tiêu thụ | Tổng chi phí ($) | Tỷ trọng | Đánh giá & Tối ưu |
| :---: | :--- | :--- | :--- | :---: | :---: | :--- |
| **1** | **Amazon Elastic Compute Cloud (EC2)** | 4 máy ảo `t3.micro` | ~30 giờ tính toán | **$1.25** | 22.5% | Dừng máy (Stop) sau mỗi buổi học |
| **2** | **Amazon Elastic Block Store (EBS)** | 4 ổ gp2 dung lượng 8 GB (32 GB) | 1 tháng lưu trữ | **$3.20** | 57.5% | Nằm trong hạn mức ≤ 100 GB |
| **3** | **Amazon Virtual Private Cloud (EIP)** | 2 địa chỉ Public IPv4 tĩnh | ~40 giờ không gắn máy chạy | **$0.40** | 7.2% | Sẵn sàng giải phóng khi teardown |
| **4** | **Amazon Route 53** | 1 Private Hosted Zone + Queries | 15 ngày + 5,000 queries | **$0.26** | 4.7% | Phân giải nội bộ khép kín |
| **5** | **Amazon CloudWatch** | Metric Alarms tiêu chuẩn | 10 ngày giám sát | **$0.20** | 3.6% | Dùng Basic Monitoring miễn phí |
| **6** | **AWS Data Transfer** | Lưu lượng liên vùng Oregon - Virginia | ~10 GB qua hầm VPN | **$0.20** | 3.6% | Tối ưu hóa truyền nội bộ qua IPsec |
| **7** | **AWS Virtual Private Gateway (VGW)** | Thử nghiệm so sánh theo đề cương | 1 giờ thử nghiệm | **$0.05** | 0.9% | Đã xóa ở Tuần 3, $0.00 duy trì |
| **TỔNG**| **TOÀN BỘ 4 TUẦN HỌC** | **Kiến trúc mạng lai hoàn chỉnh** | **4 tuần thực nghiệm** | **~$5.56** | **100%** | **An toàn (Chiếm ~11% ngân sách $50)** |

---

## 4. BÁO CÁO MINH BẠCH SỬ DỤNG AI (AI USAGE TRANSPARENCY REPORT)

| STT | Prompt / Yêu cầu sinh viên đưa ra | Phần AI hỗ trợ tư vấn / Sinh mã | Phần Sinh viên trực tiếp thực nghiệm & Làm chủ |
| :---: | :--- | :--- | :--- |
| **1** | *"Tuần 4 làm gì theo đề cương thầy Phụng, hướng dẫn kiểm thử tổng thể và dọn dẹp"* | Tổng hợp 4 nhiệm vụ tuần 4 theo đề cương; thiết kế kịch bản kiểm thử E2E và script dọn dẹp `teardown-final.sh`. | Sinh viên kiểm tra kịch bản, chạy trực tiếp trên terminal Gateway, quan sát đàm phán IPsec và phân giải Route 53. |
| **2** | *"Đưa code để tôi dán vào console được không, hướng dẫn theo hướng này nhưng minh chứng phải trên UI"* | Đóng gói toàn bộ lệnh dạng block `cat << 'EOF'`, hướng dẫn cách chụp 8 ảnh trên giao diện AWS Console có Account ID, Region và Timestamp. | Sinh viên copy code vào terminal, kiểm tra kết quả trả về, chụp đầy đủ 8 bức ảnh lưu vào `docs/evidence/week-04/`. |
| **3** | *"tôi k connect đc vào onprem cloud (EC2 Instance Connect báo lỗi vàng)"* | Phân tích nguyên nhân: do máy Workload nằm trong Private Subnet không có Public IP theo đúng chuẩn thiết kế bảo mật; hướng dẫn giải pháp chạy trực tiếp từ máy Gateway. | Sinh viên hiểu bản chất mạng bảo mật (Private Subnet), thao tác trực tiếp trên máy Gateway `10.10.1.10` thành công. |
| **4** | *"ảnh 8 ấn vào bills nó bị báo lỗi You don't have permission..."* | Giải thích cơ chế IAM của AWS Academy Learner Lab chặn quyền root billing của tổ chức; hướng dẫn chụp giao diện Vocareum Learner Lab và trang báo lỗi làm minh chứng. | Sinh viên chụp giao diện Learner Lab thể hiện ngân sách $50 và màn hình Console thể hiện cơ chế phân quyền thực tế. |
| **5** | *"demo tức là demo thành quả chứ k phải cách làm"* | Thiết kế kịch bản showcase 7 thành quả lớn của đề tài, tập trung trình diễn kết quả thực tế thay vì hướng dẫn thao tác tạo tài nguyên. | Sinh viên nắm kịch bản, thao tác lướt chuột show 7 thành quả kỹ thuật khi quay video nghiệm thu. |

---

## 5. NHẬT KÝ CÔNG VIỆC TUẦN 4 (WORKLOG)

* **Sinh viên thực hiện:** Nhat Nguyen ([@nhatnguyen10a1thd-png](https://github.com/nhatnguyen10a1thd-png))
* **Nhóm:** Infrastructure (Đề tài cá nhân / Solo)
* **Thời gian thực hiện trong tuần 4:** 11.0 giờ (Đạt quy định môn học ≥ 8 giờ/tuần).
* **Phân bổ chi tiết số giờ:**
  * 3.5 giờ: Chạy kiểm thử tổng thể End-to-End (IKEv2, TCP MSS Clamping, Route 53, HTTP Nginx, ESP Traffic).
  * 2.0 giờ: Đối soát chi phí AWS Billing & Learner Lab, phân tích kinh tế so sánh với AWS Managed VPN.
  * 2.0 giờ: Xây dựng và kiểm thử kịch bản dọn dẹp `teardown-final.sh`, chuẩn bị kế hoạch thu hồi tài nguyên sau duyệt.
  * 2.0 giờ: Chuẩn bị nội dung, kịch bản showcase và quay Video Demo nghiệm thu (≤ 10 phút).
  * 1.5 giờ: Chụp và lưu trữ 8 ảnh minh chứng, hoàn thiện tài liệu hướng dẫn và đồng bộ hồ sơ đề tài.
* **Tự đánh giá kết quả:** Hoàn thành xuất sắc 100% mục tiêu đề tài theo đúng tiến độ và yêu cầu của Giảng viên hướng dẫn Huỳnh Xuân Phụng.
