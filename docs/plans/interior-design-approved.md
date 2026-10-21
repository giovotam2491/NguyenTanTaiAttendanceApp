# Thiết kế lại phần bên trong — NguyenTanTai Attendance

Ngày 22/10/2026. Trạng thái: đề xuất và bản phác thảo để người dùng duyệt, chưa sửa product code.

## Phạm vi theo câu trả lời người dùng

Giữ Đăng nhập, Đăng ký và OTP đã chốt; tập trung phần sau đăng nhập hiện mới có giao diện chức năng cơ bản. Hiểu “cấu trúc app” là cấu trúc màn hình/điều hướng và phân cấp nội dung, không phải đổi framework hoặc viết lại kiến trúc API. Nếu người dùng muốn chỉ những tính năng hoàn toàn chưa triển khai, cần điều chỉnh phạm vi trước khi viết code.

Taste Skill đã cài từ https://github.com/Leonxlnx/taste-skill tại /home/fiat/.codex/skills/taste-skill. Kết hợp ui-ux-pro-max đang có. Thư mục cài giữ nguyên các tài nguyên phụ của skill; chỉ chạy draw bằng dữ liệu local, không chạy installer/script browser của nguồn ngoài. Catalog tự nhận skill mới ở lượt sau; nội dung đã được đọc để dùng trong lượt này.

## Nhận xét app hiện tại từ source

- AccountHome là danh sách liên kết tới chức năng; chưa có thông tin ca, trạng thái chấm công hay hàng đợi cần xử lý làm trọng tâm.
- Các màn CRUD đang dàn đều trường và nút sửa/xóa; khó quét nhanh người, ca và trạng thái đơn.
- Chấm công, lịch sử và đơn tách thành nhiều route; thiếu một khung điều hướng thống nhất để quay lại công việc hằng ngày.
- API/session và 113 kiểm thử đã có là nền cần giữ. Không có token đăng nhập thử nên chưa kiểm tra trực quan các màn bảo vệ trên server thật trong lượt thiết kế.

## Hướng thị giác

Ý tưởng: **ca làm là trung tâm**. Phần nhận diện đặc trưng là dải thời gian vào/ra ca, dựa trên bản ghi ca thực tế; không dùng biểu đồ hay số tăng trưởng trang trí.

Taste draw: editorial-greeting, seed 221026, workspace/light, giữ palette/type của sản phẩm. Chọn vì nhân viên cần xem nhanh ca cá nhân; admin cần tập trung công việc trong đội. Không redraw. Điều chỉnh có chủ ý: chuyển grid desktop sang nội dung mobile; không ép bốn KPI nếu dữ liệu chỉ cần ba con số; không dùng timeline nghỉ phép theo đội vì API chưa có dữ liệu năng lực/nhân sự tối thiểu.

- Nền sáng trung tính, surface trắng, nhấn xanh #285BDB liên hệ phần auth; tối dùng than trung tính, không glow hoặc glass.
- Một họ chữ Roboto đang phù hợp Flutter/Vietnamese, title 24–28, body/input 16, label 14; giờ và số dùng tabular figures. Không cần thêm package font.
- Khoảng cách theo 4/8; lề mobile 20, section 24–32; panel radius 20–24, field 14–16, nút 999. Ít cấp độ, dùng nhất quán.
- Một hành động chính trên màn; icon outline đồng bộ; màu trạng thái kèm chữ. Không gắn icon nhiều màu lên từng thẻ.
- Motion là phản hồi: nhấn 120–160 ms, sheet/đổi tab 200–300 ms; giảm chuyển động theo hệ thống; không animation nền lặp hoặc stagger cho cả màn hình.
- Preview dùng Roboto từ Google Fonts; app Flutter triển khai ưu tiên font sẵn có, không phụ thuộc tải font qua mạng.

UI/UX Pro Max: đã chạy design-system và Flutter search. Hai kết quả pattern đều thiên về landing page nên không dùng làm cấu trúc app. Áp dụng các nguyên tắc đã xác minh phù hợp mobile: điều hướng tối đa 4–5 mục, touch 48dp, SafeArea, chữ phóng 200%, sáng/tối và lỗi cạnh trường. Không thêm go_router chỉ vì gợi ý dataset.

## Cấu trúc cho nhân viên

| Khu vực | Câu hỏi chính | Nội dung và thao tác |
|---|---|---|
| Hôm nay | Ca của tôi hiện thế nào, tiếp theo làm gì? | Ca đang mở/ca gần nhất, giờ vào/ra, thao tác vào/ra, đơn chờ và lối vào lịch sử |
| Lịch sử | Bản ghi vào/ra nào được ghi nhận? | Khoảng ngày, danh sách ngày/ca/giờ/trễ; mở chi tiết; phân trang thật |
| Đơn | Đơn của tôi đang ở bước nào? | Trạng thái, loại, ngày, lý do, nhận xét; tạo đơn; chỉ chủ đơn pending sửa/xóa |
| Tài khoản | Tôi đang dùng tài khoản nào? | Thông tin user, phòng ban, ca được phân, vai trò và đăng xuất |

Chấm công mở từ hành động chính ở Hôm nay: quét/dán QR → nêu rõ dữ liệu sẽ dùng → xác nhận → lấy GPS một lần và gửi. Không xin quyền camera/GPS khi vừa mở app. Lỗi hoặc kết quả chưa rõ giữ hướng xử lý an toàn hiện có; không tự đổi khóa hoặc retry.

## Cấu trúc cho admin

| Khu vực | Câu hỏi chính | Nội dung và thao tác |
|---|---|---|
| Tổng quan | Việc nào cần xử lý trước? | Đơn chờ duyệt, đường dẫn lịch sử, ca và địa điểm; số liệu lấy từ dữ liệu API |
| Nhân sự | Ai được phân ca nào? | Tab Nhân viên/Ca làm; danh sách dễ đọc, chi tiết và tạo/sửa; gán ca bằng tên ca |
| Duyệt đơn | Đơn này có đủ thông tin để quyết định? | Người gửi, loại, ngày, lý do; nhận xét bắt buộc trước duyệt/từ chối; giữ version |
| Thiết lập | Chấm công đang được cấu hình ở đâu? | Địa điểm/bán kính, QR và thời hạn; quản lý cấu hình bằng quyền hiện có |

Lịch sử toàn đội mở từ Tổng quan; không nhét thêm mục thứ năm vào thanh dưới. Tablet dùng rail có nhãn và bảng thích ứng; mobile dùng danh sách hai dòng và sheet. Không ẩn dữ liệu quan trọng chỉ để bố cục đẹp.

## Dữ liệu và trạng thái

- Dùng GET me/user, shifts, office, attendance, requests và employees hiện có; không thêm backend hoặc endpoint.
- Số đếm lấy từ dữ liệu thực đã tải; pending đếm đúng phạm vi người dùng. Không giả số, tỷ lệ hoặc thời lượng khi API thiếu.
- Ca đang mở dựa trên checkOut=null trong bản ghi của người dùng; không suy luận “đã chấm công” chỉ từ giờ thiết bị. Ca qua đêm và workDate theo server.
- Tổng hợp trên Dashboard cần tải đúng phạm vi; nếu dữ liệu thiếu/hỏng/hết phiên, có trạng thái riêng, không mặc định thành 0 hoặc coi là không có ca.
- Bộ lọc/search local chỉ áp dụng với tập dữ liệu đã tải đầy đủ. Lịch sử vẫn dùng phân trang và khoảng ngày server; không gắn nhãn số liệu toàn bộ khi mới đọc một trang.
- Mỗi phần có loading, empty, error+retry, disabled, success và trạng thái chưa rõ kết quả. Dữ liệu cũ khi refresh được giữ và có thông tin phù hợp.

## Thực hiện sau khi duyệt

1. Xây khung điều hướng sau login và bộ component/token riêng cho interior. Giữ nguyên auth và API; không thêm nested navigation hoặc dependency nếu chưa cần. Kiểm tra auth không đổi và logout/401 đóng mọi màn bảo vệ.
2. Làm employee Hôm nay, chấm công, lịch sử, đơn và tài khoản theo bố cục duyệt; bổ sung dữ liệu tổng hợp từ endpoint sẵn có, giữ giới hạn và chống chấm công trùng.
3. Làm admin Tổng quan, Nhân sự/Ca làm, Duyệt đơn và Thiết lập/QR; gom form thành nhóm thông tin, giữ đầy đủ CRUD và điều kiện quyền.
4. Kiểm thử điều hướng/back, request đến muộn, 401/logout, trạng thái thật/thiếu dữ liệu, ca qua đêm; UI chữ 200%, màn hẹp/ngang, sáng/tối và giảm chuyển động. Chạy toàn bộ suite, analyze, format; kiểm tra hình ảnh bằng browser và build APK.
5. Bàn giao APK, ảnh so sánh và giới hạn chưa kiểm chứng. Chưa tự push thiết kế mới cho đến khi đã triển khai/kiểm chứng và người dùng yêu cầu hoặc duyệt việc cập nhật repository.

## Bản phác thảo

attendance-interior-design.html có ba màn nhân viên và ba màn admin, đổi vai trò/sáng tối, lọc đơn, tìm nhân viên, đổi tab ca và mô phỏng nhận xét khi duyệt. Dữ liệu trong file là minh họa: bốn tài khoản, hai ca, hai đơn admin chờ duyệt và hai đơn cá nhân; không gọi API, không camera/GPS, không thay đổi dữ liệu thật.

Đây là bản duyệt cấu trúc và phong cách, không phải app đã được sửa. Các màn auth không xuất hiện trong bản phác thảo vì thuộc phần giữ nguyên.
