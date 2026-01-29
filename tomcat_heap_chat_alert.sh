#!/bin/bash
# ============================================================
# Project : JVM Watchtower
# Purpose : Agentless JVM monitoring with automated diagnostics
# Author  : odazu
# Version : 1.0
# ============================================================

set -euo pipefail

export PATH=/usr/local/bin:/usr/bin:/bin

# ================= CONFIG =================
WEBHOOK_URL="https://chat.googleapis.com/v1/spaces/AAQA0PQ5NbQ/messages?key=AIzaSyDdI0hCZtE6vySjMm-WEfRq3CPzqKqqsHI&token=ycxasEFwCmsOmhKMK9ixn-Q24bCBxsm0duO5ziBAqcA"

HEAP_THRESHOLD=80
OLDGEN_THRESHOLD=75
# ==========================================

HOST=$(hostname)
DATE=$(date)

ANY_BREACH=0
REPORT_TEXT=""

for PID in $(pgrep -f 'org.apache.catalina.startup.Bootstrap'); do
  NAME=$(basename "$(ps -p "$PID" -o args= | sed -n 's/.*-Dcatalina.base=\([^ ]*\).*/\1/p')")

  HEAP=$(/usr/local/bin/tomcat_heap_usage.sh "$PID" || echo 0)
  OLD=$(/usr/local/bin/tomcat_oldgen_usage.sh "$PID" || echo 0)
# ================= Thread dump on breach (once per hour) =================

THREAD_DUMP_DIR="/dr01/diag/thread_dumps"
THREAD_STATE="/tmp/thread_dump_${NAME}.state"
NOW=$(date +%s)
ONE_HOUR=3600

if [ "$HEAP" -ge "$HEAP_THRESHOLD" ] || [ "$OLD" -ge "$OLDGEN_THRESHOLD" ]; then
  if [ ! -f "$THREAD_STATE" ] || [ $((NOW - $(cat "$THREAD_STATE"))) -ge $ONE_HOUR ]; then
    /tech/java/openjdk17.0.7.7/bin/jstack "$PID" > \
      "${THREAD_DUMP_DIR}/thread_${NAME}_${PID}_$(date +%F_%H%M%S).txt"
    echo "$NOW" > "$THREAD_STATE"
  fi
fi

# ========================================================================
# ================= GC trend snapshot on breach =================

GC_TREND_DIR="/dr01/diag/gc_trends"

if [ "$HEAP" -ge "$HEAP_THRESHOLD" ] || [ "$OLD" -ge "$OLDGEN_THRESHOLD" ]; then
  GC_FILE="${GC_TREND_DIR}/gc_${NAME}_${PID}_$(date +%F_%H%M%S).txt"

  /tech/java/openjdk17.0.7.7/bin/jstat -gcutil "$PID" 1000 10 > "$GC_FILE"
fi

# =================================================================
# ================= Heap dump (CRITICAL only, once per day, disk-safe) =================

HEAP_DUMP_DIR="/dr01/diag/heap_dumps"
HEAP_STATE="/tmp/heap_dump_${NAME}.state"
NOW=$(date +%s)
ONE_DAY=86400

if [ "$HEAP" -ge 90 ] || [ "$OLD" -ge 90 ]; then
#if [ "$HEAP" -ge 1 ]; then

  # Rate limit: once per day per Tomcat
  if [ ! -f "$HEAP_STATE" ] || [ $((NOW - $(cat "$HEAP_STATE"))) -ge $ONE_DAY ]; then

    # Disk safety: require >= 10GB free
    FREE_GB=$(df -BG /dr01 | awk 'NR==2 {gsub("G","",$4); print $4}')

    if [ "$FREE_GB" -ge 10 ]; then
      /tech/java/openjdk17.0.7.7/bin/jcmd "$PID" GC.heap_dump \
        "${HEAP_DUMP_DIR}/heap_${NAME}_${PID}_$(date +%F_%H%M%S).hprof"
      echo "$NOW" > "$HEAP_STATE"
    fi

  fi
fi

# =====================================================================================

  # Build report for ALL tomcats
  REPORT_TEXT="${REPORT_TEXT}
• *Tomcat*: ${NAME}
  PID: ${PID}
  Heap: ${HEAP}%
  OldGen: ${OLD}%
"

  # Detect ANY breach
  if [ "$HEAP" -ge "$HEAP_THRESHOLD" ] || [ "$OLD" -ge "$OLDGEN_THRESHOLD" ]; then
    ANY_BREACH=1
  fi
done

# ---- Send alert ONLY if ANY tomcat breached ----
if [ "$ANY_BREACH" -eq 1 ]; then
  MESSAGE="🚨 *Tomcat JVM Memory Alert* 🚨
Host: ${HOST}
Time: ${DATE}

${REPORT_TEXT}"

  curl -s -X POST "$WEBHOOK_URL" \
    -H 'Content-Type: application/json' \
    --data-binary "$(/usr/bin/jq -n --arg text "$MESSAGE" '{text: $text}')"
fi

