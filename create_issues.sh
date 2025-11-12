#!/usr/bin/env bash
# Bulk create GitHub issues from JSON (idempotent, Windows-safe)

set -euo pipefail

# === DEPENDENCY CHECKS ===
for cmd in jq curl; do
  if ! command -v "$cmd" &> /dev/null; then
    echo "❌ Missing required command: $cmd"
    echo "  Windows: choco install $cmd -y"
    echo "  macOS:  brew install $cmd"
    echo "  Linux:  sudo apt install $cmd -y"
    exit 1
  fi
done

# === HELP / USAGE ===
if [ $# -lt 1 ]; then
  echo "Usage: $0 <path-to-issues.json>"
  exit 1
fi
ISSUE_FILE="$1"

# === LOAD ENVIRONMENT ===
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
ENV_PATH="${REPO_ROOT}/.env"

if [ ! -f "$ENV_PATH" ]; then
  echo "❌ Missing .env file at: $ENV_PATH"
  exit 1
fi

echo "📂 Loading environment from: $ENV_PATH"
while IFS='=' read -r key value; do
  [[ "$key" =~ ^#.*$ || -z "$key" ]] && continue
  key=$(echo "$key" | tr -d '[:space:]')
  value=$(echo "$value" | sed 's/\r$//' | sed 's/^ *//;s/ *$//' | sed 's/^"//;s/"$//')
  export "$key=$value"
done < <(sed 's/\r$//' "$ENV_PATH")

# === VALIDATION ===
: "${GITHUB_TOKEN:?❌ Missing GITHUB_TOKEN in .env}"
: "${REPO_OWNER:?❌ Missing REPO_OWNER in .env}"
: "${REPO_NAME:?❌ Missing REPO_NAME in .env}"
[ -f "$ISSUE_FILE" ] || { echo "❌ JSON file not found: $ISSUE_FILE"; exit 1; }

echo "📜 Creating issues from: $ISSUE_FILE"
echo "📦 Target repo: ${REPO_OWNER}/${REPO_NAME}"
echo ""

# === NORMALIZE FILE (CRLF → LF) ===
ISSUE_FILE_UNIX="$(mktemp)"
tr -d '\r' < "$ISSUE_FILE" > "$ISSUE_FILE_UNIX"
ISSUE_FILE="$ISSUE_FILE_UNIX"

# === VERIFY JSON STRUCTURE ===
jq 'if type=="array" then . else error("Root must be array") end' "$ISSUE_FILE" >/dev/null

# === TOKEN TYPE ===
if [[ $GITHUB_TOKEN == github_pat_* ]]; then
  echo "🔑 Detected fine-grained PAT (adding API version header)"
  API_HEADER="X-GitHub-Api-Version: 2022-11-28"
else
  echo "🔑 Detected classic PAT"
  API_HEADER=""
fi

# === CURL DEFAULTS ===
CURL_OPTS=(
  --silent --show-error --fail-with-body
  --http1.1
  --connect-timeout 10
  --max-time 40
  --retry 3
  --retry-all-errors
)

# === FETCH EXISTING ISSUES (PAGINATED, WINDOWS SAFE) ===
echo "📥 Fetching existing open issues..."
page=1
all_issues_file="$(mktemp)"
echo "[]" > "$all_issues_file"

while :; do
  resp_file="$(mktemp)"
  curl "${CURL_OPTS[@]}" \
    -H "Authorization: Bearer ${GITHUB_TOKEN}" \
    -H "Accept: application/vnd.github+json" \
    -H "${API_HEADER:-X-GitHub-Api-Version: 2022-11-28}" \
    "https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}/issues?state=open&per_page=100&page=${page}" \
    -o "$resp_file" || echo "[]" > "$resp_file"

  count=$(jq 'length' "$resp_file")
  if [ "$count" -eq 0 ]; then
    rm -f "$resp_file"
    break
  fi

  tmp_merge="$(mktemp)"
  jq -s 'add' "$all_issues_file" "$resp_file" > "$tmp_merge"
  mv "$tmp_merge" "$all_issues_file"
  rm -f "$resp_file"
  page=$((page + 1))
done

existing_titles=$(jq -r '.[].title' "$all_issues_file" | sort | uniq)
echo "📄 Found $(echo "$existing_titles" | wc -l | awk '{print $1}') open issues"

# === CREATE ISSUES ===
issue_count=0
total=$(jq length "$ISSUE_FILE")

for i in $(jq -r 'range(0; length)' "$ISSUE_FILE"); do
  title=$(jq -r ".[$i].title" "$ISSUE_FILE")
  echo "📌 Processing: $title"

  if echo "$existing_titles" | grep -Fxq "$title"; then
    echo "🔁 Skipping — already exists"
    continue
  fi

  # --- Write payload to file to avoid JSON quoting issues ---
  payload_file="$(mktemp)"
  jq -c ".[$i] | {title, body: (.body | gsub(\"\\\\n\"; \"\n\")), labels}" "$ISSUE_FILE" > "$payload_file"

  resp_file="$(mktemp)"
  http_code="$(
    curl "${CURL_OPTS[@]}" -X POST \
      -H "Authorization: Bearer ${GITHUB_TOKEN}" \
      -H "Accept: application/vnd.github+json" \
      -H "${API_HEADER:-X-GitHub-Api-Version: 2022-11-28}" \
      "https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}/issues" \
      --data-binary @"$payload_file" \
      -o "$resp_file" -w '%{http_code}' || true
  )"

  rm -f "$payload_file"

  if [ "$http_code" -ge 200 ] && [ "$http_code" -lt 300 ]; then
    issue_url=$(jq -r '.html_url // empty' "$resp_file" 2>/dev/null || true)
    if [ -n "$issue_url" ]; then
      echo "✅ Created: $issue_url"
      issue_count=$((issue_count + 1))
      existing_titles="$(printf '%s\n%s' "$existing_titles" "$title" | sort | uniq)"
    fi
  else
    echo "❌ HTTP $http_code while creating '$title'"
    jq -r '.message // empty' "$resp_file" 2>/dev/null || cat "$resp_file"
  fi
  rm -f "$resp_file"
done

echo ""
if [ "$issue_count" -gt 0 ]; then
  echo "🎉 Successfully created $issue_count new issues!"
else
  echo "ℹ️  No new issues created (all existed or failed)."
fi
