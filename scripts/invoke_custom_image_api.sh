#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
ENV_FILE="${SKILL_DIR}/.env"
if [[ -f "$ENV_FILE" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "$ENV_FILE"
  set +a
fi

MODE="generate"
ENDPOINT="${CUSTOM_IMAGE_API_URL:-}"
API_KEY="${CUSTOM_IMAGE_API_KEY:-${OPENAI_API_KEY:-}}"
MODEL="${CUSTOM_IMAGE_MODEL:-}"
PROMPT=""
IMAGE=""
OUT=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode) MODE="$2"; shift 2 ;;
    --endpoint) ENDPOINT="$2"; shift 2 ;;
    --api-key) API_KEY="$2"; shift 2 ;;
    --model) MODEL="$2"; shift 2 ;;
    --prompt) PROMPT="$2"; shift 2 ;;
    --image) IMAGE="$2"; shift 2 ;;
    --out) OUT="$2"; shift 2 ;;
    *) echo "Unknown argument: $1" >&2; exit 2 ;;
  esac
done

if [[ -z "$ENDPOINT" ]]; then
  if [[ -n "${OPENAI_BASE_URL:-}" ]]; then
    if [[ "$MODE" == "edit" ]]; then route="edits"; else route="generations"; fi
    ENDPOINT="${OPENAI_BASE_URL%/}/images/${route}"
  else
    echo "Endpoint is required. Set CUSTOM_IMAGE_API_URL, OPENAI_BASE_URL, or pass --endpoint." >&2
    exit 2
  fi
fi
if [[ "$ENDPOINT" =~ ^[0-9]+$ ]]; then
  if [[ "$MODE" == "edit" ]]; then route="edits"; else route="generations"; fi
  ENDPOINT="http://127.0.0.1:${ENDPOINT}/v1/images/${route}"
fi
if [[ -z "$MODEL" ]]; then MODEL="image-model"; fi
if [[ -z "$PROMPT" ]]; then echo "Prompt is required." >&2; exit 2; fi
if [[ -z "$OUT" ]]; then echo "Output path is required." >&2; exit 2; fi
if [[ "$MODE" == "edit" && ! -f "$IMAGE" ]]; then
  echo "Image not found: $IMAGE" >&2
  exit 2
fi

mkdir -p "$(dirname "$OUT")"
response_file="$(mktemp)"
trap 'rm -f "$response_file"' EXIT

auth_args=()
if [[ -n "$API_KEY" ]]; then
  auth_args=(-H "Authorization: Bearer ${API_KEY}")
fi

if [[ "$MODE" == "edit" ]]; then
  curl -sS -X POST "$ENDPOINT" \
    "${auth_args[@]}" \
    -F "model=${MODEL}" \
    -F "prompt=${PROMPT}" \
    -F "image=@${IMAGE}" \
    -o "$response_file"
else
  curl -sS -X POST "$ENDPOINT" \
    "${auth_args[@]}" \
    -H "Content-Type: application/json" \
    -d "$(MODEL="$MODEL" PROMPT="$PROMPT" python3 -c 'import json, os; print(json.dumps({"model": os.environ["MODEL"], "prompt": os.environ["PROMPT"]}))')" \
    -o "$response_file"
fi

python3 - "$response_file" "$OUT" "$API_KEY" <<'PY'
import base64
import json
import shutil
import subprocess
import sys
import urllib.request

response_path, out_path, api_key = sys.argv[1], sys.argv[2], sys.argv[3]
with open(response_path, "r", encoding="utf-8") as f:
    raw = f.read()

try:
    data = json.loads(raw)
except json.JSONDecodeError as exc:
    raise SystemExit(f"API response is not JSON: {exc}\n{raw[:500]}")

def get(path):
    cur = data
    for part in path:
        if isinstance(cur, list):
            try:
                cur = cur[int(part)]
            except (ValueError, IndexError):
                return None
        elif isinstance(cur, dict):
            cur = cur.get(part)
        else:
            return None
    return cur

for path in [
    ("data", "0", "b64_json"),
    ("data", "0", "base64"),
    ("data", "0", "image"),
    ("b64_json",),
    ("base64",),
    ("image",),
    ("output", "0", "result"),
]:
    value = get(path)
    if value:
        if value.startswith("data:image/"):
            value = value.split(",", 1)[1]
        with open(out_path, "wb") as f:
            f.write(base64.b64decode(value))
        print(f"Saved image: {out_path}")
        raise SystemExit(0)

url = get(("data", "0", "url"))
if url:
    curl = shutil.which("curl")
    if curl:
        cmd = [curl, "-fsSL", url, "-o", out_path]
        if api_key:
            cmd[1:1] = ["-H", f"Authorization: Bearer {api_key}"]
        subprocess.run(cmd, check=True)
    else:
        urllib.request.urlretrieve(url, out_path)
    print(f"Saved image: {out_path}")
    raise SystemExit(0)

err = data.get("error") if isinstance(data, dict) else None
raise SystemExit(f"Could not find an image payload in the API response. Error: {err or raw[:500]}")
PY

echo "Endpoint: $ENDPOINT"
echo "Model: $MODEL"
