#!/usr/bin/env sh
set -u

HOST="${1:-}"
PORT="${2:-10050}"
SESSION="${3:-}"

json_fail() {
  status="$1"
  response_ms="$2"
  rc="$3"
  printf '{"status":%s,"response_ms":%s,"zabbix_get_rc":%s,"sql_utc":""}\n' \
    "$status" "$response_ms" "$rc"
}

if [ -z "$HOST" ] || [ -z "$SESSION" ]; then
  json_fail 0 0 64
  exit 0
fi

if ! command -v zabbix_get >/dev/null 2>&1; then
  json_fail 0 0 127
  exit 0
fi

# Alpine/BusyBox date does not support GNU %N.
# /proc/uptime provides a monotonic clock and awk converts it to milliseconds.
now_ms() {
  awk '{printf "%.0f\n", $1 * 1000}' /proc/uptime
}

KEY="mssql.custom.query[${SESSION},,,sqlmaniak_e2e]"

start_ms="$(now_ms)"
result="$(zabbix_get -s "$HOST" -p "$PORT" -k "$KEY" 2>&1)"
rc=$?
end_ms="$(now_ms)"

elapsed_ms=$((end_ms - start_ms))
if [ "$elapsed_ms" -lt 0 ]; then
  elapsed_ms=0
fi

status=0
sql_utc=""

if [ "$rc" -eq 0 ] && printf '%s\n' "$result" | grep -q '"ok"[[:space:]]*:[[:space:]]*1'; then
  status=1
  sql_utc="$(printf '%s\n' "$result" | sed -n 's/.*"sql_utc"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n1)"
fi

printf '{"status":%d,"response_ms":%d,"zabbix_get_rc":%d,"sql_utc":"%s"}\n' \
  "$status" "$elapsed_ms" "$rc" "$sql_utc"

exit 0
