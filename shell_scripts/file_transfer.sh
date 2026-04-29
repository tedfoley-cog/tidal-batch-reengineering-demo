#!/bin/bash
# ============================================================
# file_transfer.sh — SFTP File Transfer Script
#
# Called by Tidal jobs FTP_GL_DOWNSTREAM and FTP_REG_SUBMIT
# to transfer batch output files to downstream systems.
#
# Usage: file_transfer.sh <local_file> <remote_host> <remote_dir>
#
# Exit codes:
#   0 - Transfer successful
#   4 - Transfer successful with warnings (retried)
#   8 - Transfer failed after retries
#  12 - Configuration error
# ============================================================

set -euo pipefail

LOCAL_FILE="${1:?Usage: file_transfer.sh <local_file> <remote_host> <remote_dir>}"
REMOTE_HOST="${2:?Missing remote host}"
REMOTE_DIR="${3:?Missing remote directory}"

MAX_RETRIES=3
RETRY_DELAY=30
SSH_KEY="/opt/tidal/keys/batch_transfer_rsa"
SFTP_USER="batchxfer"
LOG_DIR="/var/log/batch/transfers"
LOG_FILE="${LOG_DIR}/transfer_$(date +%Y%m%d_%H%M%S).log"

mkdir -p "${LOG_DIR}"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [file_transfer] $1" | tee -a "${LOG_FILE}"
}

if [[ ! -f "${LOCAL_FILE}" ]]; then
    log "ERROR: Source file not found: ${LOCAL_FILE}"
    exit 12
fi

if [[ ! -f "${SSH_KEY}" ]]; then
    log "ERROR: SSH key not found: ${SSH_KEY}"
    exit 12
fi

FILE_SIZE=$(stat -c %s "${LOCAL_FILE}" 2>/dev/null || echo "unknown")
FILE_MD5=$(md5sum "${LOCAL_FILE}" | awk '{print $1}')

log "Starting transfer"
log "  Source:  ${LOCAL_FILE} (${FILE_SIZE} bytes, md5=${FILE_MD5})"
log "  Target:  ${SFTP_USER}@${REMOTE_HOST}:${REMOTE_DIR}"

ATTEMPT=0
TRANSFER_RC=8

while [[ ${ATTEMPT} -lt ${MAX_RETRIES} ]]; do
    ATTEMPT=$((ATTEMPT + 1))
    log "Transfer attempt ${ATTEMPT}/${MAX_RETRIES}"

    sftp -o StrictHostKeyChecking=no \
         -o ConnectTimeout=30 \
         -i "${SSH_KEY}" \
         "${SFTP_USER}@${REMOTE_HOST}" <<EOF 2>>"${LOG_FILE}"
cd ${REMOTE_DIR}
put ${LOCAL_FILE}
bye
EOF

    if [[ $? -eq 0 ]]; then
        if [[ ${ATTEMPT} -gt 1 ]]; then
            log "Transfer successful on retry (attempt ${ATTEMPT})"
            TRANSFER_RC=4
        else
            log "Transfer successful"
            TRANSFER_RC=0
        fi
        break
    else
        log "Transfer attempt ${ATTEMPT} failed"
        if [[ ${ATTEMPT} -lt ${MAX_RETRIES} ]]; then
            log "Retrying in ${RETRY_DELAY} seconds..."
            sleep ${RETRY_DELAY}
        fi
    fi
done

if [[ ${TRANSFER_RC} -ge 8 ]]; then
    log "ERROR: Transfer failed after ${MAX_RETRIES} attempts"
fi

exit ${TRANSFER_RC}
