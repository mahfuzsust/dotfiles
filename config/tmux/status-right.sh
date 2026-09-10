#!/bin/sh
# macOS status line: CPU and memory usage percentages.

cpu=$(top -l 1 -s 0 -n 0 2>/dev/null | awk '/CPU usage/ {gsub(/%/, "", $3); gsub(/%/, "", $5); printf "%.0f", $3 + $5}')
cpu=${cpu:-0}

if command -v memory_pressure >/dev/null 2>&1; then
  free_pct=$(memory_pressure 2>/dev/null | awk '/System-wide memory free percentage/ {gsub(/%/, "", $5); print $5}')
  mem=$((100 - free_pct))
else
  page_size=$(pagesize 2>/dev/null || echo 4096)
  mem_total=$(sysctl -n hw.memsize 2>/dev/null || echo 0)
  vm=$(vm_stat 2>/dev/null)
  pages_active=$(echo "$vm" | awk '/Pages active/ {gsub(/\./, "", $3); print $3}')
  pages_wired=$(echo "$vm" | awk '/Pages wired down/ {gsub(/\./, "", $3); print $3}')
  pages_compressed=$(echo "$vm" | awk '/Pages occupied by compressor/ {gsub(/\./, "", $3); print $3}')
  used=$(( (pages_active + pages_wired + pages_compressed) * page_size ))
  mem=$((used * 100 / mem_total))
fi

printf 'CPU %s%% MEM %s%%' "$cpu" "$mem"
