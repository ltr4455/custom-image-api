#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

require_file() {
  local path="$1"
  if [[ ! -f "${ROOT_DIR}/${path}" ]]; then
    echo "Missing required file: ${path}" >&2
    exit 1
  fi
}

require_file "SKILL.md"
require_file "README.md"
require_file "LICENSE"
require_file ".env.example"
require_file "scripts/invoke_custom_image_api.sh"
require_file "scripts/invoke_custom_image_api.ps1"
require_file "references/api-contract.md"
require_file "references/runtime-environment.md"

if ! grep -q '^name: custom-image-api$' "${ROOT_DIR}/SKILL.md"; then
  echo "SKILL.md is missing the expected name frontmatter." >&2
  exit 1
fi

if ! grep -q '^description: ' "${ROOT_DIR}/SKILL.md"; then
  echo "SKILL.md is missing description frontmatter." >&2
  exit 1
fi

bash -n "${ROOT_DIR}/scripts/invoke_custom_image_api.sh"
bash -n "${ROOT_DIR}/scripts/check_project.sh"

echo "Project checks passed."

