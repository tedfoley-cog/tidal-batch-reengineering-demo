#!/bin/bash
# ============================================================
# archive_logs.sh — Log Archival and Cleanup Script
#
# Called by Tidal jobs ACCT_ARCHIVE and EOD_LOG_CLEANUP
# to compress and archive processed batch files and logs.
#
# Usage: archive_logs.sh <category>
#   category: ACCT | GL | PAYROLL | ALL
#
# Exit codes:
#   0 - Archive successful
#   4 - Archive with warnings (some files skipped)
#   8 - Archive failed
# ============================================================

set -euo pipefail

CATEGORY="${1:?Usage: archive_logs.sh <ACCT|GL|PAYROLL|ALL>}"
ARCHIVE_BASE="/data/archive"
RETENTION_DAYS=2555  # 7 years for SOX compliance
TODAY=$(date +%Y%m%d)
LOG_FILE="/var/log/batch/archive_${TODAY}.log"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [archive] $1" | tee -a "${LOG_FILE}"
}

archive_dir() {
    local src_dir="$1"
    local arc_dir="$2"
    local pattern="$3"

    if [[ ! -d "${src_dir}" ]]; then
        log "WARNING: Source directory not found: ${src_dir}"
        return 4
    fi

    mkdir -p "${arc_dir}"

    local count=0
    for file in "${src_dir}"/${pattern}; do
        if [[ -f "${file}" ]]; then
            local basename=$(basename "${file}")
            gzip -c "${file}" > "${arc_dir}/${basename}.gz"
            rm -f "${file}"
            count=$((count + 1))
        fi
    done

    log "Archived ${count} files from ${src_dir} to ${arc_dir}"
    return 0
}

cleanup_old() {
    local dir="$1"
    if [[ -d "${dir}" ]]; then
        local deleted=$(find "${dir}" -name "*.gz" -mtime +${RETENTION_DAYS} -delete -print | wc -l)
        log "Purged ${deleted} files older than ${RETENTION_DAYS} days from ${dir}"
    fi
}

log "=== Archive started: category=${CATEGORY}, date=${TODAY} ==="

RC=0

case "${CATEGORY}" in
    ACCT)
        archive_dir "/data/acct/extract" "${ARCHIVE_BASE}/acct/${TODAY}" "*.dat" || RC=4
        cleanup_old "${ARCHIVE_BASE}/acct"
        ;;
    GL)
        archive_dir "/data/gl/posted" "${ARCHIVE_BASE}/gl/${TODAY}" "*.dat" || RC=4
        archive_dir "/data/gl/reports" "${ARCHIVE_BASE}/gl/${TODAY}" "*.pdf" || RC=4
        cleanup_old "${ARCHIVE_BASE}/gl"
        ;;
    PAYROLL)
        archive_dir "/data/payroll/register" "${ARCHIVE_BASE}/payroll/${TODAY}" "*.dat" || RC=4
        archive_dir "/data/payroll/ach" "${ARCHIVE_BASE}/payroll/${TODAY}" "*.ach" || RC=4
        cleanup_old "${ARCHIVE_BASE}/payroll"
        ;;
    ALL)
        archive_dir "/var/log/batch" "${ARCHIVE_BASE}/logs/${TODAY}" "*.log" || RC=4
        archive_dir "/data/acct/extract" "${ARCHIVE_BASE}/acct/${TODAY}" "*.dat" || RC=4
        archive_dir "/data/gl/posted" "${ARCHIVE_BASE}/gl/${TODAY}" "*.dat" || RC=4
        cleanup_old "${ARCHIVE_BASE}/acct"
        cleanup_old "${ARCHIVE_BASE}/gl"
        cleanup_old "${ARCHIVE_BASE}/logs"
        ;;
    *)
        log "ERROR: Unknown category: ${CATEGORY}"
        RC=8
        ;;
esac

log "=== Archive completed: RC=${RC} ==="
exit ${RC}
