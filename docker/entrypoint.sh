#!/bin/bash
set -e

# 检查配置文件
if [ ! -f "/app/config/config.yaml" ] || [ ! -f "/app/config/frequency_words.txt" ]; then
    echo "❌ 配置文件缺失"
    exit 1
fi

case "${RUN_MODE:-cron}" in
"once")
    echo "🔄 单次执行"
    exec python -m trendradar
    ;;
"cron")
    # 采集与报告使用独立计划，避免报告时点再次采集
    COLLECT_CRON_EXPR="${CRON_SCHEDULE:-*/30 * * * *}"
    REPORT_CRON_EXPR="${REPORT_CRON_SCHEDULE:-5 8 * * *}"
    for CRON_EXPR in "$COLLECT_CRON_EXPR" "$REPORT_CRON_EXPR"; do
        if ! echo "$CRON_EXPR" | grep -qE '^[0-9*/,[:space:]-]+$'; then
            echo "❌ cron 表达式非法: $CRON_EXPR"
            exit 1
        fi
    done

    # 生成 crontab
    {
        echo "$COLLECT_CRON_EXPR cd /app && python -m trendradar --collect-only"
        echo "$REPORT_CRON_EXPR cd /app && python -m trendradar --report-only"
    } > /tmp/crontab
    
    echo "📅 生成的crontab内容:"
    cat /tmp/crontab

    if ! /usr/local/bin/supercronic -test /tmp/crontab; then
        echo "❌ crontab格式验证失败"
        exit 1
    fi

    # 立即执行一次（如果配置了）
    if [ "${IMMEDIATE_RUN:-false}" = "true" ]; then
        echo "▶️ 立即执行一次"
        python -m trendradar --collect-only
    fi

    # 启动 Web 服务器
    echo "🌐 启动 Web 服务器..."
    python manage.py start_webserver

    echo "⏰ 采集计划: $COLLECT_CRON_EXPR"
    echo "📨 报告计划: $REPORT_CRON_EXPR"
    echo "🎯 supercronic 将作为 PID 1 运行"

    exec /usr/local/bin/supercronic -passthrough-logs /tmp/crontab
    ;;
*)
    exec "$@"
    ;;
esac
