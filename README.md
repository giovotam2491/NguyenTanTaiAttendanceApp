# NguyenTanTai Attendance — Flutter

Ứng dụng chấm công cá nhân dùng API Render chung của nhóm. Giao diện tiếng Việt lấy cảm hứng ColorOS 17, sáng/tối theo hệ thống.

## Chức năng client đã nối

- Đăng ký, xác minh email; đăng nhập → OTP → nhận phiên và tài khoản theo response do người dùng cung cấp.
- Phiên chỉ ở memory; đóng app hoặc hết hạn thì đăng nhập lại. 401 đóng các trang được bảo vệ; 403 hiện lỗi. Logout xóa phiên local ngay và gửi refreshToken để thu hồi phía server.
- Admin: quản lý nhân viên, ca làm, yêu cầu; phân ca, duyệt/từ chối; cấu hình địa điểm và lấy QR server.
- Employee: Dashboard cá nhân, yêu cầu, vào/ra ca qua QR + GPS và lịch sử.
- CRUD có tạo/sửa/xóa, xác nhận xóa; password chỉnh sửa để trống sẽ không gửi thay đổi password.
- Camera/GPS chỉ yêu cầu khi người dùng thao tác. Không có tracking nền hoặc chia sẻ vị trí tự động. Có thể dán QR nếu camera không khả dụng.
- Chấm công giữ nguyên payload/idempotencyKey sau timeout/5xx/kết quả không đọc được, không tự retry; rời rồi mở lại màn hình trong cùng phiên vẫn giữ thao tác. Đóng app/đăng xuất sẽ xóa trạng thái trong memory. Người dùng kiểm tra lịch sử trước khi quyết định gửi lại cùng thao tác.

## Chạy

Máy hiện tại dùng Flutter 3.47.7/Dart 3.13.5. Cần Android SDK/toolchain tương thích, điện thoại có camera/GPS và mạng để nghiệm thu thiết bị.

```bash
flutter pub get
flutter run
```

Xem trên trình duyệt:

```bash
flutter run -d chrome
```

Base URL mặc định: https://webapi-chamcong-nhom9-tongnhatbaoan.onrender.com

```bash
flutter run --dart-define=API_BASE_URL=https://your-api.example
```

Không đưa database connection string, JWT signing key, Brevo key hoặc token thật vào code/Git. Client không dùng backend riêng để thay thế API nhóm.

## Hợp đồng response và giới hạn

Auth verify-otp dùng shape đã cung cấp: accessToken/accessExpiresAt/refreshToken/user, trong user có id/name/email/username/department/role/shiftId/active. Token đã dán vào chat không được lưu trong source hoặc fixture.

Đã đối chiếu source trong Downloads ngày 22/10/2026: register/login trả challengeId; lists employees/shifts/requests là array; attendance là {total,page,pageSize,items}; office có configured; QR là {code,expiresAt}. Các fixture dùng cấu trúc này và dữ liệu tổng hợp.

Đơn chỉ có Nghỉ phép hoặc Giải trình chấm công; lý do ít nhất 10 ký tự. Chỉ chủ đơn pending được sửa/xóa; admin duyệt đơn người khác pending với nhận xét bắt buộc và version. Giới hạn grace 0–60, radius 20–5000 m; GPS accuracy <=80 m, không mocked và timestamp mới. Server vẫn quyết định quy tắc nghiệp vụ và phân quyền.

QR tự ẩn khi hết hạn, không tự sinh mới; lịch sử hiển thị checkIn/checkOut theo UTC+7 và dùng metadata phân trang. Thông báo lỗi nghiệp vụ từ server được đọc có kiểm tra, giữ fallback nếu body hỏng.

Cần thử API thật để xác nhận source nhận được trùng bản deploy, email/permission/idempotency hoạt động đúng. Chưa kiểm chứng camera/GPS trên Android thật. Source API chưa có CORS; bản web có thể cần nhóm cấu hình server/proxy, không sửa backend trong thay đổi này.

Chưa làm: standalone chia sẻ vị trí/cảm biến chuyển động, tính năng mới, refresh tự động, lưu phiên lâu dài hoặc iOS. Những mục này không được tính là hoàn thành đề thi.

## Kiểm chứng

```bash
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build apk --debug
```

Tests dùng MockClient và GPS tổng hợp, không gửi OTP/email, không dùng token thật hoặc ghi dữ liệu nhóm. Cần người dùng thử luồng với tài khoản được phép dùng trên API thật.

Dependency ngoài SDK: http, geolocator, mobile_scanner, qr_flutter. Tài liệu chính thức: https://pub.dev/packages/geolocator · https://pub.dev/packages/mobile_scanner · https://pub.dev/packages/qr_flutter
