#!/bin/bash

PID=$1
JCMD="/tech/java/openjdk17.0.7.7/bin/jcmd"

if [ -z "$PID" ] || ! ps -p "$PID" >/dev/null 2>&1; then
  echo 0
  exit 0
fi

LINE=$($JCMD "$PID" GC.heap_info 2>/dev/null | sed -n '2p')

TOTAL=$(echo "$LINE" | awk '{for(i=1;i<=NF;i++) if($i=="total") {gsub(/K,|M,/, "", $(i+1)); print $(i+1)}}')
USED=$(echo "$LINE"  | awk '{for(i=1;i<=NF;i++) if($i=="used")  {gsub(/K|M/, "", $(i+1)); print $(i+1)}}')

if [ -z "$TOTAL" ] || [ -z "$USED" ] || [ "$TOTAL" -eq 0 ]; then
  echo 0
  exit 0
fi

echo $(( USED * 100 / TOTAL ))

