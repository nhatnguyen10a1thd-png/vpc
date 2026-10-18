# Nghiên cứu dịch vụ AWS, Nền tảng & Ràng buộc Lab (Services, Foundation & LabRole Prerequisites)

> **Môn học:** Cloud - Đợt 1 - 2026-2027  
> **Giảng viên hướng dẫn (GVHD):** Huỳnh Xuân Phụng  
> **Nhóm thực hiện:** Infrastructure  
> **Sinh viên:** Nhat Nguyen ([@nhatnguyen10a1thd-png](https://github.com/nhatnguyen10a1thd-png))  
> **Tài liệu:** Tuần 1 - Tìm hiểu dịch vụ, Phân tích kiến trúc nền tảng và Ràng buộc IAM LabRole

---

## 1. Phân tích chi tiết các dịch vụ AWS sử dụng trong đề tài

### 1.1. Amazon Virtual Private Cloud (Amazon VPC)
- **Vai trò:** Cung cấp hạ tầng mạng ảo hóa độc lập, mô phỏng cả hai đầu mạng: Trung tâm dữ liệu On-Premises (tại Region `us-west-2`) và AWS Production Cloud (tại Region `us-east-1`).
- **Các thành phần cốt lõi:**
  - **Subnets:** Chia tách mạng thành Public Subnet (đặt Gateway) và Private Subnet (đặt Workload an toàn).
  - **Internet Gateway (IGW):** Cho phép các EC2 Gateway sở hữu Public IP/EIP giao tiếp với nhau qua môi trường Internet công cộng, hình thành đường hầm IPsec.
  - **Route Tables:** Điều khiển hướng đi của gói tin. Điểm mấu chốt là cấu hình tuyến đường đến mạng đối tác qua ENI (Elastic Network Interface) của EC2 strongSwan.
  - **Security Groups & Network ACLs:** Cung cấp tường lửa tầng máy ảo (Stateful) và tầng mạng (Stateless) cho phép lọc chính xác UDP 500, UDP 4500 và ESP (Protocol 50).

### 1.2. Amazon Elastic Compute Cloud (Amazon EC2)
- **Vai trò:**
  - **Máy chủ VPN Gateway (strongSwan):** Chạy trên cấu hình máy ảo `t3.micro` hoặc `t3.small` với hệ điều hành Ubuntu 22.04 LTS hoặc Amazon Linux 2023. Đây là router phần mềm trung chuyển lưu lượng mã hóa.
  - **Máy chủ Workload nội bộ:** Đóng vai trò máy khách (Client) hoặc máy chủ dịch vụ (Web/Nginx/iperf3) trong Private Subnet.
- **Ràng buộc quan trọng:**
  - **Source/Destination Check:** Mặc định EC2 kiểm tra IP nguồn/đích của gói tin. Để EC2 strongSwan hoạt động như một Router/Gateway, cờ này **bắt buộc phải tắt** (`SourceDestCheck: false`).

### 1.3. Amazon Route 53 (Private Hosted Zone)
- **Vai trò:** Hệ thống DNS nội bộ có khả năng quản lý tên miền riêng tư (`corp.internal`).
- **Điểm sáng tạo trong đề tài:** Sử dụng cơ chế **Cross-VPC Association**. Bằng cách ủy quyền liên kết giữa VPC Cloud (`us-east-1`) và VPC On-Prem (`us-west-2`), cả hai đầu mạng đều có thể phân giải tên miền máy chủ của nhau mà không cần dựng cụm DNS server BIND9 thủ công, tối ưu hóa độ tin cậy và tận dụng tối đa dịch vụ Cloud Native.

### 1.4. AWS Identity and Access Management (IAM) & LabRole Constraints
- **Vai trò:** Quản lý quyền truy cập của các máy ảo EC2 vào các dịch vụ khác của AWS.
- **Đặc thù môi trường AWS Academy Learner Lab:**
  - Tài khoản sinh viên không có quyền tạo IAM Role hoặc IAM Policy mới (`iam:CreateRole`, `iam:CreatePolicy` bị cấm bởi Service Control Policy - SCP).
  - AWS Academy đã tạo sẵn một Role chuyên dụng tên là **`LabRole`** có quyền quản lý hầu hết các tài nguyên cơ bản (EC2, S3, VPC, Route 53, CloudWatch).
  - **Giải pháp triển khai:** Gắn trực tiếp `LabRole` vào EC2 Instance Profile khi khởi tạo máy ảo để EC2 có quyền đọc file cấu hình từ Amazon S3.

### 1.5. Amazon Simple Storage Service (Amazon S3)
- **Vai trò:** Lưu trữ sao lưu tập trung các file cấu hình VPN (`ipsec.conf`, `ipsec.secrets`, `swanctl.conf`), script tự động hóa khởi tạo, và kết quả kiểm thử qua các tuần.
- **Tên Bucket tuần 1:** `hybrid-vpn-foundation-storage-<account-id>` (được gắn tag định danh chuẩn).

---

## 2. So sánh giải pháp: Phần mềm 2 đầu (strongSwan) vs AWS Virtual Private Gateway (VGW)

| Đặc tính | Giải pháp Phần mềm 2 đầu (strongSwan <-> strongSwan) [Ưu tiên] | Giải pháp AWS VGW (strongSwan <-> AWS VGW) [Demo] |
| :--- | :--- | :--- |
| **Bản chất** | Hai máy ảo EC2 chạy strongSwan tự đàm phán IPsec IKEv2. | Một đầu là phần mềm strongSwan, một đầu là dịch vụ quản lý AWS Virtual Private Gateway. |
| **Chi phí duy trì** | Rất thấp (Chỉ tính cước EC2 `t3.micro`, nằm gọn trong hạn mức miễn phí hoặc tốn ~0.0104$/giờ). | **$0.05/giờ cho mỗi VPN Connection.** Nếu quên xóa sẽ làm cạn kiệt ngân sách $100 của AWS Academy trong 1-2 tháng. |
| **Mức độ kiểm soát** | Kiểm soát 100% cấu hình: Cipher suites, DH groups, DPD, iptables, TCP MSS, logging mức độ debug. | Bị cố định theo template của AWS. Cấu hình phía AWS Cloud bị trừu tượng hóa, không can thiệp sâu được vào nhân mạng. |
| **Học thuật & Đồ án** | Giúp sinh viên nắm vững nguyên lý hoạt động của giao thức IPsec, routing table của Linux, iptables NAT và gói tin mạng. | Phù hợp để làm quen với thao tác kéo thả trên AWS Console. |
| **Kế hoạch thực hiện** | **Sử dụng xuyên suốt 4 tuần cho toàn bộ bài kiểm thử.** | **Chỉ dựng lên để quay video/chụp ảnh nghiệm thu demo, sau đó XÓA NGAY LẬP TỨC.** |

---

## 3. Chính sách gắn Tag tài nguyên chuẩn (AWS Tagging Policy)

Theo chuẩn quản trị hạ tầng (Cloud Governance), tất cả tài nguyên được khởi tạo từ Tuần 1 phải có bộ Tag sau:

```json
{
  "Project": "Hybrid-Cloud-VPN",
  "Environment": "Lab-Simulation",
  "Course": "Cloud-Dot1-2026-2027",
  "Instructor": "HuynhXuanPhung",
  "Owner": "NhatNguyen",
  "Phase": "Week1-Foundation",
  "ManagedBy": "AWS-CLI-CloudFormation"
}
```

### Lệnh gán Tag đồng loạt qua AWS CLI:
```bash
aws ec2 create-tags --resources <resource-ids> \
    --tags Key=Project,Value=Hybrid-Cloud-VPN \
           Key=Environment,Value=Lab-Simulation \
           Key=Course,Value=Cloud-Dot1-2026-2027 \
           Key=Instructor,Value=HuynhXuanPhung \
           Key=Owner,Value=NhatNguyen \
           Key=Phase,Value=Week1-Foundation
```
