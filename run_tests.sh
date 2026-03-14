#!/usr/bin/env bash
set -euo pipefail

PORT_BASE="${PORT_BASE:-8090}"
PB_BIN="${PB_BIN:-./pocketbase}"
PB_ZIP_URL="${PB_ZIP_URL:-https://github.com/pocketbase/pocketbase/releases/download/v0.36.6/pocketbase_0.36.6_linux_amd64.zip}"
SCHEMA_FILE="./pb_schema_for_tests.json"

PB_ADMIN_EMAIL="${PB_ADMIN_EMAIL:-test_admin@example.com}"
PB_ADMIN_PASSWORD="${PB_ADMIN_PASSWORD:-password}"

PB_ROOT_TMP="$(mktemp -d)"
TEST_BACKUP_DIR="$(mktemp -d)"

PB_PID=""
PB_DIR=""
LOG=""
AUTH_RESP=""

if [[ ! -x "$PB_BIN" ]]; then
  echo "PocketBase binary not found at $PB_BIN; downloading from release zip..."

  if ! command -v curl >/dev/null 2>&1; then
    echo "curl is required to download PocketBase"
    exit 1
  fi

  if ! command -v unzip >/dev/null 2>&1; then
    echo "unzip is required to extract PocketBase"
    exit 1
  fi

  PB_BIN_DIR="$(dirname "$PB_BIN")"
  mkdir -p "$PB_BIN_DIR"

  PB_ZIP_FILE="$(mktemp --suffix=.zip)"
  trap 'rm -f "$PB_ZIP_FILE"' EXIT

  curl -fsSL "$PB_ZIP_URL" -o "$PB_ZIP_FILE"
  unzip -p "$PB_ZIP_FILE" pocketbase > "$PB_BIN_DIR/pocketbase"
  chmod +x "$PB_BIN_DIR/pocketbase"

  if [[ "$PB_BIN" != "$PB_BIN_DIR/pocketbase" ]]; then
    cp -f "$PB_BIN_DIR/pocketbase" "$PB_BIN"
    chmod +x "$PB_BIN"
  fi

  rm -f "$PB_ZIP_FILE"
  trap - EXIT
fi

if [[ ! -x "$PB_BIN" ]]; then
  echo "PocketBase binary not executable after setup: $PB_BIN"
  exit 1
fi

if [[ ! -f "$SCHEMA_FILE" ]]; then
  echo "Schema file not found: $SCHEMA_FILE"
  exit 1
fi

cp test/*.gleam "$TEST_BACKUP_DIR/"

free_port() {
  local port="$1"
  if ss -tlnp 2>/dev/null | grep -q ":${port} "; then
    echo "Port ${port} already in use, attempting to free it..."
    fuser -k "${port}/tcp" 2>/dev/null || true
    sleep 0.5
  fi
}

restore_test_files() {
  cp "$TEST_BACKUP_DIR"/*.gleam test/
}

stop_pocketbase() {
  if [[ -n "${PB_PID:-}" ]]; then
    kill "$PB_PID" 2>/dev/null || true
    PB_PID=""
  fi
}

cleanup() {
  stop_pocketbase
  restore_test_files || true
  rm -rf "$PB_ROOT_TMP" "$TEST_BACKUP_DIR"
  if [[ -n "${LOG:-}" ]]; then rm -f "$LOG"; fi
  if [[ -n "${AUTH_RESP:-}" ]]; then rm -f "$AUTH_RESP"; fi
}
trap cleanup EXIT

start_fresh_pocketbase() {
  local port="$1"

  stop_pocketbase

  PB_DIR="$(mktemp -d -p "$PB_ROOT_TMP")"
  LOG="$(mktemp -p "$PB_ROOT_TMP")"
  AUTH_RESP="$(mktemp -p "$PB_ROOT_TMP")"

  free_port "$port"

  "$PB_BIN" superuser upsert "$PB_ADMIN_EMAIL" "$PB_ADMIN_PASSWORD" --dir "$PB_DIR"

  "$PB_BIN" serve --http="127.0.0.1:${port}" --dir "$PB_DIR" >"$LOG" 2>&1 &
  PB_PID=$!

  for i in {1..100}; do
    if ! kill -0 "$PB_PID" 2>/dev/null; then
      echo "PocketBase process exited unexpectedly"
      cat "$LOG"
      exit 1
    fi
    if curl -fsS "http://127.0.0.1:${port}/api/health" >/dev/null 2>&1; then
      break
    fi
    sleep 0.2
    if [[ "$i" -eq 100 ]]; then
      echo "PocketBase failed to start (timed out)"
      cat "$LOG"
      exit 1
    fi
  done

  curl -sS "http://127.0.0.1:${port}/api/collections/_superusers/auth-with-password" \
    -H "content-type: application/json" \
    -d "{\"identity\":\"${PB_ADMIN_EMAIL}\",\"password\":\"${PB_ADMIN_PASSWORD}\"}" \
    -o "$AUTH_RESP"

  local token=""
  if [[ "$(<"$AUTH_RESP")" =~ \"token\"[[:space:]]*:[[:space:]]*\"([^\"]+)\" ]]; then
    token="${BASH_REMATCH[1]}"
  fi

  if [[ -z "$token" || "$token" == "null" ]]; then
    echo "Failed to obtain superuser token"
    cat "$AUTH_RESP"
    exit 1
  fi

  local import_payload
  import_payload="$(mktemp -p "$PB_ROOT_TMP")"
  cat > "$import_payload" <<EOF
{"collections": $(cat "$SCHEMA_FILE"), "deleteMissing": false}
EOF

  curl -fsS "http://127.0.0.1:${port}/api/collections/import" \
    -X PUT \
    -H "authorization: Bearer ${token}" \
    -H "content-type: application/json" \
    --data @"$import_payload" >/dev/null

  rm -f "$import_payload"

  curl -fsS "http://127.0.0.1:${port}/api/collections/animals/records" \
    -X POST \
    -H "authorization: Bearer ${token}" \
    -H "content-type: application/json" \
    -d '{"id":"p7m2ga6mbkciygd","name":"lion"}' >/dev/null

  curl -fsS "http://127.0.0.1:${port}/api/collections/animals/records" \
    -X POST \
    -H "authorization: Bearer ${token}" \
    -H "content-type: application/json" \
    -d '{"name":"bear"}' >/dev/null

  curl -fsS "http://127.0.0.1:${port}/api/collections/animals/records" \
    -X POST \
    -H "authorization: Bearer ${token}" \
    -H "content-type: application/json" \
    -d '{"name":"tiger"}' >/dev/null

  curl -fsS "http://127.0.0.1:${port}/api/collections/users/records" \
    -X POST \
    -H "authorization: Bearer ${token}" \
    -H "content-type: application/json" \
    -d '{"email":"test@example.com","password":"password","passwordConfirm":"password","name":"test"}' >/dev/null
}

disable_all_tests() {
  sed -E -i 's/^([[:space:]]*pub fn[[:space:]]+[A-Za-z0-9_]+_test)([[:space:]]*\()/\1_disabled\2/' test/*.gleam
}

enable_test() {
  local file="$1"
  local fn_name="$2"
  sed -E -i "s/^([[:space:]]*pub fn[[:space:]]+)${fn_name}_disabled([[:space:]]*\\()/\\1${fn_name}\\2/" "$file"
}

mapfile -t TEST_CASES < <(
  grep -RHPn '^\s*pub fn\s+[A-Za-z0-9_]+_test\s*\(' test/*.gleam \
  | sed -E 's#^([^:]+):[0-9]+:.*pub fn ([A-Za-z0-9_]+_test)\s*\(.*$#\1::\2#' \
  | sort
)

if [[ "${#TEST_CASES[@]}" -eq 0 ]]; then
  echo "No _test functions found under test/"
  exit 1
fi

echo "Running ${#TEST_CASES[@]} isolated test(s) with fresh PocketBase DB per test..."

for index in "${!TEST_CASES[@]}"; do
  entry="${TEST_CASES[$index]}"
  test_file="${entry%%::*}"
  test_name="${entry##*::}"
  run_no="$((index + 1))"
  port="$PORT_BASE"

  echo
  echo "==> [${run_no}/${#TEST_CASES[@]}] ${test_name} (${test_file}) on port ${port}"

  restore_test_files
  disable_all_tests
  enable_test "$test_file" "$test_name"

  start_fresh_pocketbase "$port"

  if ! gleam test; then
    echo "Isolated test failed: ${test_name} (${test_file})"
    exit 1
  fi
done

echo
echo "All isolated tests passed."