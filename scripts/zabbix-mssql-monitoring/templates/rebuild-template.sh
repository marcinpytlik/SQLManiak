#!/usr/bin/env sh
set -eu

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
PACKED_DIR="$ROOT_DIR/packed"
OUT="$ROOT_DIR/SQLManiak_MSSQL_Zabbix_7.4_matrix_v1.6_baseline_anomaly.yaml"
EXPECTED_SHA256="2b47546f54ad8e9aaa78fb1ebec7b7f51ab044d137abedc6a0bf041cf500f40d"

cat "$PACKED_DIR"/part-*.b64 | tr -d '\r\n' | base64 -d | gzip -dc > "$OUT"

ACTUAL_SHA256="$(sha256sum "$OUT" | awk '{print $1}')"
if [ "$ACTUAL_SHA256" != "$EXPECTED_SHA256" ]; then
  echo "SHA256 mismatch" >&2
  echo "expected: $EXPECTED_SHA256" >&2
  echo "actual:   $ACTUAL_SHA256" >&2
  exit 1
fi

echo "OK: $OUT"
echo "SHA256: $ACTUAL_SHA256"
