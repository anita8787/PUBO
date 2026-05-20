# ── Stage 1: Build image ──────────────────────────────────────────────────────
FROM python:3.12-slim

# 設定工作目錄
WORKDIR /app

# 安裝系統依賴（psycopg2 需要 libpq）
RUN apt-get update && apt-get install -y \
    libpq-dev \
    gcc \
    && rm -rf /var/lib/apt/lists/*

# 先複製 requirements 以利用 Docker layer cache
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# 複製整個後端程式碼
COPY . .

# Cloud Run 預設使用 PORT 環境變數（預設 8080）
ENV PORT=8080

# 啟動指令
CMD uvicorn app.main:app --host 0.0.0.0 --port $PORT
