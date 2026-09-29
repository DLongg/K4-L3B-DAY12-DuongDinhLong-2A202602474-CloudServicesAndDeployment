# ═══════════════════════════════════════════════════════════════════
# CP2 — Containerization (Multi-stage Build)
# ═══════════════════════════════════════════════════════════════════

# Stage 1: builder - cài đặt thư viện vào virtualenv
FROM python:3.11-slim AS builder

WORKDIR /app

# Tạo virtualenv riêng biệt để chứa các dependency đã cài
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Sao chép requirements.txt và cài đặt dependency trước khi sao chép mã nguồn để tối ưu cache
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Stage 2: runtime - gọn nhẹ, bảo mật với non-root user
FROM python:3.11-slim AS runtime

WORKDIR /app

# Sao chép môi trường ảo từ builder stage
COPY --from=builder /opt/venv /opt/venv

ENV PATH="/opt/venv/bin:$PATH" \
    PYTHONUNBUFFERED=1

# Tạo non-root user 'appuser'
RUN useradd --create-home --uid 10001 appuser

# Sao chép mã nguồn ứng dụng và phân quyền cho appuser
COPY . .
RUN chown -R appuser:appuser /app

# Chuyển sang user non-root
USER appuser

# Mở cổng mặc định
EXPOSE 8000

# Healthcheck kiểm tra endpoint /health sử dụng thư viện chuẩn urllib
HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
    CMD python -c "import urllib.request, os; port = os.getenv('PORT', '8000'); urllib.request.urlopen(f'http://127.0.0.1:{port}/health').read()" || exit 1

# Khởi động ứng dụng với cổng nhận từ biến môi trường PORT (mặc định 8000)
CMD ["sh", "-c", "exec uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8000}"]
