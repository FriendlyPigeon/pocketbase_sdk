#!/usr/bin/env bash
set -euo pipefail

PORT=8090
PB_BIN="${PB_BIN:-./pocketbase}"
PB_ZIP_URL="${PB_ZIP_URL:-https://github.com/pocketbase/pocketbase/releases/download/v0.36.6/pocketbase_0.36.6_linux_amd64.zip}"
PB_DIR="$(mktemp -d)"
LOG="$(mktemp)"
AUTH_RESP="$(mktemp)"
SCHEMA_FILE="./pb_schema_for_tests.json"

PB_ADMIN_EMAIL="${PB_ADMIN_EMAIL:-test_admin@example.com}"
PB_ADMIN_PASSWORD="${PB_ADMIN_PASSWORD:-password}"

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

# Kill any existing process using the port to avoid silent conflicts
if ss -tlnp 2>/dev/null | grep -q ":${PORT} "; then
  echo "Port ${PORT} already in use, attempting to free it..."
  fuser -k "${PORT}/tcp" 2>/dev/null || true
  sleep 0.5
fi

cleanup() {
  if [[ -n "${PB_PID:-}" ]]; then kill "$PB_PID" 2>/dev/null || true; fi
  rm -rf "$PB_DIR" "$LOG" "$AUTH_RESP"
}
trap cleanup EXIT

# Create superuser BEFORE starting the server to avoid SQLite write conflicts
"$PB_BIN" superuser upsert "$PB_ADMIN_EMAIL" "$PB_ADMIN_PASSWORD" --dir "$PB_DIR"

"$PB_BIN" serve --http="127.0.0.1:${PORT}" --dir "$PB_DIR" >"$LOG" 2>&1 &
PB_PID=$!

for i in {1..100}; do
  if ! kill -0 "$PB_PID" 2>/dev/null; then
    echo "PocketBase process exited unexpectedly"
    cat "$LOG"
    exit 1
  fi
  if curl -fsS "http://127.0.0.1:${PORT}/api/health" >/dev/null 2>&1; then
    break
  fi
  sleep 0.2
  if [[ "$i" -eq 100 ]]; then
    echo "PocketBase failed to start (timed out)"
    cat "$LOG"
    exit 1
  fi
done

if [[ ! -f "$SCHEMA_FILE" ]]; then
  echo "Schema file not found: $SCHEMA_FILE"
  exit 1
fi

# Auth: write response to file to avoid command substitution issues
curl -sS "http://127.0.0.1:${PORT}/api/collections/_superusers/auth-with-password" \
  -H "content-type: application/json" \
  -d "{\"identity\":\"${PB_ADMIN_EMAIL}\",\"password\":\"${PB_ADMIN_PASSWORD}\"}" \
  -o "$AUTH_RESP"

TOKEN=""
if [[ "$(<"$AUTH_RESP")" =~ \"token\"[[:space:]]*:[[:space:]]*\"([^\"]+)\" ]]; then
  TOKEN="${BASH_REMATCH[1]}"
fi

if [[ -z "$TOKEN" || "$TOKEN" == "null" ]]; then
  echo "Failed to obtain superuser token"
  cat "$AUTH_RESP"
  exit 1
fi

IMPORT_PAYLOAD="$(mktemp)"
cat > "$IMPORT_PAYLOAD" <<EOF
{"collections": $(cat "$SCHEMA_FILE"), "deleteMissing": false}
EOF

curl -fsS "http://127.0.0.1:${PORT}/api/collections/import" \
  -X PUT \
  -H "authorization: Bearer ${TOKEN}" \
  -H "content-type: application/json" \
  --data @"$IMPORT_PAYLOAD" >/dev/null

rm -f "$IMPORT_PAYLOAD"

# Seed animals — lion created first so it sorts first by created ASC (default)
curl -fsS "http://127.0.0.1:${PORT}/api/collections/animals/records" \
  -X POST \
  -H "authorization: Bearer ${TOKEN}" \
  -H "content-type: application/json" \
  -d '{"id":"p7m2ga6mbkciygd","name":"lion"}' >/dev/null

curl -fsS "http://127.0.0.1:${PORT}/api/collections/animals/records" \
  -X POST \
  -H "authorization: Bearer ${TOKEN}" \
  -H "content-type: application/json" \
  -d '{"name":"bear"}' >/dev/null

curl -fsS "http://127.0.0.1:${PORT}/api/collections/animals/records" \
  -X POST \
  -H "authorization: Bearer ${TOKEN}" \
  -H "content-type: application/json" \
  -d '{"name":"tiger"}' >/dev/null

# Seed test user for auth tests
curl -fsS "http://127.0.0.1:${PORT}/api/collections/users/records" \
  -X POST \
  -H "authorization: Bearer ${TOKEN}" \
  -H "content-type: application/json" \
  -d '{"email":"test@example.com","password":"password","passwordConfirm":"password","name":"test"}' >/dev/null

gleam test