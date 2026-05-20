#!/bin/bash

echo "🚀 開始部署 Pubo API 到 Google Cloud Run..."

# 確保在 backend 目錄下執行
cd "$(dirname "$0")"

# 執行部署指令 (請確認您的服務名稱與區域是否正確)
gcloud run deploy pubo-api \
  --source . \
  --region asia-east1 \
  --allow-unauthenticated

echo "✅ 部署完成！"
