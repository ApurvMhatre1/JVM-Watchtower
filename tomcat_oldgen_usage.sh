#!/bin/bash

PID=$1
JSTAT="/tech/java/openjdk17.0.7.7/bin/jstat"

if [ -z "$PID" ] || ! ps -p "$PID" >/dev/null 2>&1; then
  echo 0
  exit 0
fi

$JSTAT -gcutil "$PID" 2>/dev/null | tail -1 | awk '{print int($4)}'

