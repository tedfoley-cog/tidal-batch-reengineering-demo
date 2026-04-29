#!/bin/bash
# ============================================================
# notify_ops.sh — Operations Notification Script
#
# Called by Tidal job EOD_NOTIFY_COMPLETE to send summary
# notifications after batch processing completes.
#
# Usage: notify_ops.sh <event_type>
#   event_type: EOD_COMPLETE | PAYROLL_COMPLETE | FAILURE
# ============================================================

set -euo pipefail

EVENT_TYPE="${1:?Usage: notify_ops.sh <EOD_COMPLETE|PAYROLL_COMPLETE|FAILURE>}"
SMTP_HOST="smtp.acme-corp.internal"
SMTP_PORT=25
FROM_ADDR="batch-automation@acme-corp.internal"
LOG_FILE="/var/log/batch/notify_$(date +%Y%m%d_%H%M%S).log"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [notify] $1" | tee -a "${LOG_FILE}"
}

send_email() {
    local to="$1"
    local subject="$2"
    local body="$3"

    log "Sending to: ${to}"
    log "Subject: ${subject}"

    echo -e "Subject: ${subject}\nFrom: ${FROM_ADDR}\nTo: ${to}\n\n${body}" \
        | sendmail -t -f "${FROM_ADDR}" 2>>"${LOG_FILE}" || {
        log "WARNING: Email delivery may have failed for ${to}"
        return 4
    }
}

TODAY=$(date '+%Y-%m-%d')
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

case "${EVENT_TYPE}" in
    EOD_COMPLETE)
        SUBJECT="[BATCH] EOD Processing Complete — ${TODAY}"
        BODY="End-of-day batch processing completed successfully.\n\nTimestamp: ${TIMESTAMP}\nServer: $(hostname)\n\nJobs completed:\n- ACCT_DAILY_EXTRACT\n- ACCT_VALIDATION\n- GL_POSTING_BATCH\n- GL_REPORT_DAILY\n- EOD_RECONCILIATION\n- EOD_BACKUP\n- ACCT_ARCHIVE\n\nAll jobs completed normally. See Tidal console for details."
        send_email "batch-ops@acme-corp.internal,finance-mgr@acme-corp.internal" "${SUBJECT}" "${BODY}"
        ;;
    PAYROLL_COMPLETE)
        SUBJECT="[BATCH] Payroll Processing Complete — ${TODAY}"
        BODY="Payroll batch processing completed.\n\nTimestamp: ${TIMESTAMP}\n\nACH file staged for bank transmission.\nSee payroll register report for details."
        send_email "payroll-ops@acme-corp.internal,payroll-mgr@acme-corp.internal,treasury@acme-corp.internal" "${SUBJECT}" "${BODY}"
        ;;
    FAILURE)
        SUBJECT="[ALERT] Batch Job Failure — ${TODAY}"
        BODY="A batch job has failed. Check Tidal console for details.\n\nTimestamp: ${TIMESTAMP}\nServer: $(hostname)\n\nImmediate action required."
        send_email "batch-ops@acme-corp.internal" "${SUBJECT}" "${BODY}"
        ;;
    *)
        log "ERROR: Unknown event type: ${EVENT_TYPE}"
        exit 8
        ;;
esac

log "Notification sent for ${EVENT_TYPE}"
exit 0
