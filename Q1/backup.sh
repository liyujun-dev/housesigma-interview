#!/bin/bash

BACKUP_DIR="/path/to/backup"
TIMESTAMP=$(date +"%Y-%m-%d")
LAST_MONTH=$(date -d "last month" +"%Y-%m")
BACKUP_FILE="$BACKUP_DIR/user_logs_$LAST_MONTH.gz"
MONGODB_URI="mongodb://localhost:27017"
DATABASE="test"
COLLECTION="user_logs"
WEBHOOK_URL="https://monitor.ipo.com/webhook/mongodb"

mkdir -p "$BACKUP_DIR"

# 备份上个月的数据
if ! mongoexport --uri="$MONGODB_URI" --db="$DATABASE" --collection="$COLLECTION" \
    --query="{\"create_on\": {\"\$gte\": {\"\$date\": \"$LAST_MONTH-01T00:00:00Z\"}, \"\$lt\": {\"\$date\": \"$LAST_MONTH-01T23:59:59Z\"}}}}" \
    --out="$BACKUP_DIR/user_logs_$LAST_MONTH.json"; then
    curl -X POST "$WEBHOOK_URL" -d '{"status": "backup_failed", "time": "'"$TIMESTAMP"'"}'
    exit 1
fi

# 打包备份文件
if ! gzip "$BACKUP_DIR/user_logs_$LAST_MONTH.json"; then
    curl -X POST "$WEBHOOK_URL" -d '{"status": "gzip_failed", "time": "'"$TIMESTAMP"'"}'
    exit 1
fi

# 通过 SFTP 传输备份文件
if ! sftp bak@bak.ipo.com:"$BACKUP_FILE" <<< "put $BACKUP_DIR/user_logs_$LAST_MONTH.gz"; then
    curl -X POST "$WEBHOOK_URL" -d '{"status": "sftp_failed", "time": "'"$TIMESTAMP"'"}'
    exit 1
fi

# 清理旧数据
if ! mongo "$MONGODB_URI/$DATABASE" --eval "db.$COLLECTION.remove({create_on: {\$lt: new Date('$LAST_MONTH-01T00:00:00Z')}})"; then
    curl -X POST "$WEBHOOK_URL" -d '{"status": "cleanup_failed", "time": "'"$TIMESTAMP"'"}'
    exit 1
fi

echo "Backup and cleanup completed successfully on $TIMESTAMP"