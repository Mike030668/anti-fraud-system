#!/usr/bin/env bash
set -euo pipefail

log() { echo "[$(date +'%F %T')] $*"; }

# 1) Определяем источник
SOURCE_BUCKET="${SOURCE_BUCKET:-}"
if [ -z "$SOURCE_BUCKET" ]; then
  # попробуем вытащить из terraform output (если скрипт запускают из корня проекта)
  if command -v terraform >/dev/null 2>&1 && [ -f infra/terraform.tfstate -o -d .terraform ]; then
    SOURCE_BUCKET="$(terraform -chdir=infra output -raw source_bucket_name 2>/dev/null || true)"
  fi
fi
# дефолт на случай, если ничего не нашли
SOURCE_BUCKET="${SOURCE_BUCKET:-otus-mlops-source-data}"

DEST_HDFS="${DEST_HDFS:-/user/ubuntu/data}"

# 2) Параметр: имя файла (опционально)
FILE_NAME="${1:-}"

log "Using source bucket: s3a://${SOURCE_BUCKET}"
log "HDFS destination   : ${DEST_HDFS}"

# 3) Создаём каталог в HDFS
hdfs dfs -mkdir -p "${DEST_HDFS}" || true

# 4) Копирование
if [ -n "$FILE_NAME" ]; then
  log "Copying single file: ${FILE_NAME}"
  hadoop distcp "s3a://${SOURCE_BUCKET}/${FILE_NAME}" "hdfs://${DEST_HDFS}/${FILE_NAME}"
else
  log "No file specified — copying ALL objects from bucket"
  # параллельно и с перезаписью
  hadoop distcp -m 10 -overwrite "s3a://${SOURCE_BUCKET}/" "hdfs://${DEST_HDFS}"
fi

# 5) Проверка
log "Listing HDFS path:"
hdfs dfs -ls -R "${DEST_HDFS}" | head -200
log "Done."
