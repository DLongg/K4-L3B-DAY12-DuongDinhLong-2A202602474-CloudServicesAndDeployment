# Phiếu Phản Ánh — K4 Level 3B, Ngày 12

> **Bài làm cá nhân.** Trả lời bằng lời của chính bạn, dựa trên những gì bạn
> quan sát được khi chạy code — không sao chép đáp án của người khác.
>
> Cách trả lời: điền câu trả lời trực tiếp bên dưới mỗi câu hỏi.
> `grade.py` đếm số câu đã trả lời (15 điểm cho 10 câu).
>
> Họ và tên: Dương Đình Long  Mã học viên: 2A202602474

---

### Câu 1 — Fail fast (CP1)

Trong `Settings`, `agent_api_key` không có giá trị mặc định nên app chết ngay
khi khởi động nếu thiếu biến môi trường. Hãy mô tả một tình huống cụ thể mà
việc "chết sớm" này cứu bạn, so với việc để mặc định `"changeme"`.

Tình huống cụ thể: Khi deploy ứng dụng lên Cloud (Render/Railway), tôi quên cấu hình biến môi trường `AGENT_API_KEY` trong phần Environment Variables trên dashboard. Nhờ không đặt giá trị mặc định, Pydantic ném lỗi `ValidationError` ngay lúc server khởi động, container lập tức dừng lại và dashboard báo lỗi build/deploy thất bại (Fail Fast). Nhờ vậy, tôi phát hiện ra ngay lập tức khi đang quan sát deployment logs. 
Ngược lại, nếu để giá trị mặc định là `"changeme"`, ứng dụng vẫn khởi động bình thường và báo trạng thái Live màu xanh. Khi đó dịch vụ công khai với khóa bí mật phổ biến `"changeme"` sẽ dễ dàng bị bot hoặc kẻ xấu dò ra và gọi API miễn phí, tiêu tốn toàn bộ hạn mức hoặc làm lộ thông tin nhạy cảm mà tôi chỉ phát hiện ra khi nhận hóa đơn vào cuối tháng.

---

### Câu 2 — Log cho máy đọc (CP1)

Chạy service và gọi `/ask` vài lần. Dán một dòng log JSON bạn thu được, rồi
nêu **hai** việc bạn làm được với dòng log đó mà `print("đã trả lời xong")`
không làm được.

Dòng log JSON thu được:
`{"event": "ask_completed", "level": "info", "timestamp": "2026-09-29T07:10:19.452134+00:00", "user_id": "sv-test", "tokens_in": 12, "tokens_out": 24, "cost_usd": 0.0001}`

Hai việc làm được với log JSON mà lệnh print thông thường không làm được:
1. **Lọc, truy vấn và tổng hợp định lượng tự động bằng hệ thống quản lý log (như Datadog, Grafana Loki, CloudWatch)**: Có thể viết truy vấn chính xác để lọc ra các request có `cost_usd > 0.005`, hoặc tính tổng chi phí theo từng `user_id` trong ngày để xác định user nào tiêu nhiều tiền nhất.
2. **Thiết lập cảnh báo (Alerting) thời gian thực theo ngưỡng**: Dễ dàng cấu hình bot cảnh báo (Slack/Telegram) tự động kích hoạt khi trường `level == "error"` hoặc phát hiện số lượng token/chi phí của một request tăng đột biến so với bình thường.

---

### Câu 3 — Kích thước image (CP2)

Build cả hai phiên bản và ghi lại số đo thật:

```bash
docker build -f <Dockerfile-1-stage> -t agent:single .
docker build -t agent:multi .
docker images | grep agent
```

| Bản | Dung lượng |
|-----|-----------|
| 1 stage (bản đầu) | ~460 MB |
| Multi-stage | ~195 MB |

Giải thích: phần dung lượng chênh lệch đó là những gì?

Phần dung lượng chênh lệch (~265 MB) bao gồm:
1. Các công cụ biên dịch và xây dựng gói (build tools, wheel cache, pip cache trong quá trình tải và cài đặt thư viện).
2. Các header C, file tạm thời, tài liệu package và metadata phát sinh trong quá trình cài đặt dependencies.
Trong kiến trúc Multi-stage, stage `runtime` chỉ sao chép thư mục môi trường ảo sạch `/opt/venv` từ stage `builder` sang một base image `python:3.11-slim` mới toanh, loại bỏ hoàn toàn các file rác và công cụ build thừa thãi.

---

### Câu 4 — Thứ tự lệnh trong Dockerfile (CP2)

Sửa một ký tự trong `app/main.py` rồi build lại. Với Dockerfile của bạn, những
layer nào được dùng lại từ cache, layer nào phải chạy lại? Nếu bạn đặt
`COPY . .` lên trước `RUN pip install` thì kết quả khác thế nào?

- Với Dockerfile hiện tại: Các layer từ base image, tạo thư mục, `COPY requirements.txt` và `RUN pip install` đều được Docker tái sử dụng hoàn toàn từ cache (`CACHED`). Chỉ có layer `COPY . .` và các layer cấp quyền `RUN chown` phía sau mới bị chạy lại vì mã nguồn thay đổi. Thời gian build lại chỉ mất khoảng 1 - 2 giây.
- Nếu đặt `COPY . .` lên trước `RUN pip install`: Bất kỳ thay đổi nào trong mã nguồn (kể cả sửa 1 ký tự trong `main.py`) cũng sẽ làm vô hiệu hóa (cache bust) layer `COPY . .`. Khi đó, Docker bắt buộc phải chạy lại toàn bộ lệnh `RUN pip install` từ đầu, kéo dài thời gian build lên vài phút và lãng phí băng thông mạng.

---

### Câu 5 — Vì sao không chạy bằng root (CP2)

Container mặc định chạy bằng root. Mô tả chuỗi sự kiện dẫn từ "một lỗ hổng
trong code Python của bạn" tới "kẻ tấn công có quyền cao trên máy host", và
lệnh `USER` cắt đứt chuỗi đó ở chỗ nào.

- Chuỗi sự kiện:
  1. Ứng dụng Python tồn tại lỗ hổng (ví dụ Remote Code Execution thông qua insecure deserialization hoặc upload file độc hại).
  2. Kẻ tấn công khai thác lỗ hổng và chiếm quyền thực thi shell bên trong container.
  3. Vì container mặc định chạy với user `root` (UID 0), kẻ tấn công sở hữu quyền root trong container.
  4. Nếu máy host có lỗ hổng Linux kernel hoặc container misconfiguration (như chia sẻ Docker socket `/var/run/docker.sock`, privileged mode, lỗi cgroup breakout), kẻ tấn công thực hiện container breakout để thoát ra ngoài máy host. Vì UID trong container ánh xạ trực tiếp với UID 0 trên kernel host, kẻ tấn công chiếm luôn quyền root của máy chủ vật lý.
- Lệnh `USER appuser` cắt đứt chuỗi ngay tại bước 3: Sau khi thâm nhập, kẻ tấn công chỉ có quyền của user thường không đặc quyền (`appuser` - UID 10001). User này không thể sửa các file hệ thống, không có quyền sudo và không có đủ đặc quyền kernel (capabilities như CAP_SYS_ADMIN) để thực hiện hành vi container breakout sang máy host.

---

### Câu 6 — Cửa sổ trượt (CP3)

Rate limit của bạn dùng sliding window 60 giây. Nếu thay bằng cách đếm theo
phút đồng hồ (reset lúc giây 00), một người dùng có thể gửi tối đa bao nhiêu
request trong 2 giây liên tiếp khi hạn mức là 10/phút? Giải thích cách đạt được
con số đó.

- Con số tối đa: **20 requests trong 2 giây liên tiếp**.
- Cách đạt được: 
  - Tại giây thứ 59 của phút trước (ví dụ 10:00:59), người dùng gửi dồn dập 10 requests. Toàn bộ 10 requests này đều được chấp nhận vì nằm trong quota của phút 10:00.
  - Đúng 1 giây sau, đồng hồ bước sang giây 10:01:00. Bộ đếm cố định theo phút tự động reset về 0. Người dùng lập tức gửi tiếp 10 requests nữa vào giây 10:01:00.
  - Tổng cộng từ 10:00:59 đến 10:01:00 (khoảng thời gian 2 giây), hệ thống phải nhận tới 20 requests liên tiếp (gấp đôi hạn mức thiết kế). Thuật toán Sliding Window (cửa sổ trượt 60 giây) giải quyết triệt để lỗ hổng này bằng cách luôn tính tổng số request trong đúng 60 giây gần nhất tính từ thời điểm hiện tại.

---

### Câu 7 — Rate limit và cost guard (CP3)

Hai cơ chế này khác nhau ở điểm nào? Cho một tình huống mà rate limit cho qua
nhưng cost guard phải chặn, và một tình huống ngược lại.

- Khác nhau: Rate limit kiểm soát **tốc độ và số lượng request** trong một khoảng thời gian ngắn (đơn vị: req/phút) để bảo vệ server khỏi bị quá tải hạ tầng. Cost guard kiểm soát **tổng số tiền chi tiêu tích lũy** theo chu kỳ dài (tháng) dựa trên lượng token thực tế mà LLM tiêu thụ để bảo vệ ngân sách tài chính.
- Tình huống Rate limit cho qua nhưng Cost guard chặn: Người dùng chỉ gửi 1 request trong 5 phút (tần suất rất thấp, rate limit cho qua dễ dàng), nhưng tài khoản của user đó trong tháng đã tiêu hết 10.0 USD ngân sách -> Cost guard lập tức chặn và trả về mã lỗi `402 Payment Required`.
- Tình huống Cost guard cho qua nhưng Rate limit chặn: Vào ngày đầu tiên của tháng, người dùng mới chỉ tiêu 0.05 USD / 10.0 USD (còn rất nhiều ngân sách), nhưng gửi liên tục 15 requests trong vòng 3 giây -> Rate limiter lập tức kích hoạt chặn từ request thứ 11 và trả về mã `429 Too Many Requests`.

---

### Câu 8 — /health khác /ready (CP4)

Nếu gộp hai endpoint làm một và cho nó kiểm tra Redis, chuyện gì xảy ra với cụm
3 container khi Redis mất kết nối 30 giây? Trả lời theo đúng thứ tự sự kiện.

Thứ tự sự kiện xảy ra:
1. **Giây 0**: Kết nối mạng tới Redis bị gián đoạn hoặc Redis server khởi động lại.
2. **Giây 5**: Orchestrator (Docker / Kubernetes) định kỳ gọi liveness probe `/health` tới cả 3 container. Do `/health` kiểm tra Redis và Redis đang chết, cả 3 container đều phản hồi lỗi 503 hoặc timeout.
3. **Giây 10 - 15**: Orchestrator xác định cả 3 container đều "đã hỏng" và tiến hành kill/restart đồng loạt cả cụm 3 container.
4. **Giây 15 - 30**: Cả 3 container khởi động lại từ đầu, nhưng vì Redis vẫn chưa hoàn tất hồi phục nên probe tiếp tục fail. Orchestrator lại tiếp tục kill và restart container lần nữa.
5. **Hậu quả**: Toàn bộ hệ thống rơi vào vòng lặp khởi động lại liên tục (CrashLoopBackOff), tiêu tốn tài nguyên CPU/RAM vô ích và làm mất toàn bộ các request đang phục vụ dở dang. Nếu tách biệt đúng: `/health` giúp container không bị restart, còn `/ready` chỉ ngắt lưu lượng từ Load Balancer cho đến khi Redis sẵn sàng trở lại.

---

### Câu 9 — Stateless (CP4)

Chạy `docker compose up --scale agent=3` rồi gọi `/ask` nhiều lần với cùng một
`X-User-Id`. Quan sát `history_length` trong response. Nếu lịch sử được lưu
trong một dict Python thay vì Redis, bạn sẽ thấy con số đó thay đổi thế nào?

- Khi lưu bằng Redis (Stateless): Dù request được phân bổ tới bất kỳ container nào trong số 3 container, tất cả đều truy vấn vào cùng một Redis key `history:{user_id}` tập trung. Do đó, `history_length` sẽ tăng tuần tự, liên tục và nhất quán (0, 2, 4, 6, 8...).
- Nếu lưu trong một dict Python (Stateful trong RAM process): Mỗi container chỉ lưu giữ một phần lịch sử riêng biệt trong bộ nhớ của nó. Khi Load Balancer phân phối ngẫu nhiên các request theo thuật toán Round-Robin tới container 1, container 2 rồi container 3, người dùng sẽ thấy `history_length` nhảy hỗn loạn (ví dụ: request 1 vào agent 1 thấy độ dài 0; request 2 vào agent 2 lại thấy độ dài 0; request 3 vào agent 1 thấy độ dài 2; request 4 vào agent 3 lại thấy độ dài 0). Agent sẽ bị "mất trí nhớ", không thể hiểu được ngữ cảnh các câu hỏi trước đó của cùng một user.

---

### Câu 10 — Deploy thật (CP5)

Ghi lại **một** lỗi bạn gặp khi deploy lên cloud (build fail, health check
timeout, sai REDIS_URL, app không đọc `$PORT`...): thông báo lỗi là gì, bạn
tìm ra nguyên nhân bằng cách nào, và sửa ra sao?

- **Lỗi gặp phải**: Lỗi kết nối timeout khi gọi `/ready` do chưa kết nối được Redis hoặc sai chuỗi kết nối `REDIS_URL` trên Cloud Render.
- **Thông báo lỗi**: `503 Service Unavailable` với nội dung JSON: `{"status": "not ready", "redis": false}` khi kiểm tra endpoint `/ready`.
- **Cách tìm ra nguyên nhân**: Mở tab *Logs* của service `day12-agent` trên dashboard của Render và nhận thấy thông báo lỗi timeout khi client cố gắng kết nối tới địa chỉ Redis mặc định `localhost:6379`. Nhận ra service agent trên cloud chạy trong container riêng biệt, không thể kết nối tới `localhost` để tìm Redis.
- **Cách sửa**: Sử dụng tính năng Blueprint với file `render.yaml` để Render tự động tạo đồng thời cả web service và Redis service (`day12-redis`), đồng thời liên kết biến môi trường `REDIS_URL` thông qua cú pháp `fromService: name: day12-redis, property: connectionString`. Sau khi redeploy với biến môi trường chuẩn, endpoint `/ready` lập tức trả về `200 OK` với `{"status": "ready", "redis": true}`.

