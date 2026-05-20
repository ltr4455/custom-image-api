# Custom Image API Skill

Codex skill for generating or editing raster images through a user-provided
HTTP image model API instead of the built-in image generation tool.

The skill is useful when an image endpoint is exposed through a local proxy,
OpenAI-compatible API, nonstandard provider, or private gateway.

## Repository Layout

```text
.
├── SKILL.md
├── agents/
│   └── openai.yaml
├── references/
│   ├── api-contract.md
│   └── runtime-environment.md
└── scripts/
    ├── check_project.sh
    ├── invoke_custom_image_api.ps1
    └── invoke_custom_image_api.sh
```

## Install

Clone or copy this repository so that `SKILL.md` is directly inside the skill
directory:

```bash
mkdir -p ~/.codex/skills
git clone <repo-url> ~/.codex/skills/custom-image-api
```

Restart Codex after installation if the skill is not discovered immediately.

## Configure

Prefer environment variables in the shell that launches Codex:

```bash
export CUSTOM_IMAGE_API_URL="https://your-provider.example/v1/images/generations"
export CUSTOM_IMAGE_API_KEY="your-api-key"
export CUSTOM_IMAGE_MODEL="gpt-image-2"
```

For image editing, use an edit endpoint:

```bash
export CUSTOM_IMAGE_API_URL="https://your-provider.example/v1/images/edits"
```

For local development, copy `.env.example` to `.env`. The `.env` file is
ignored by Git and should never be committed.

## Usage

Generation:

```bash
scripts/invoke_custom_image_api.sh \
  --mode generate \
  --endpoint "$CUSTOM_IMAGE_API_URL" \
  --model "$CUSTOM_IMAGE_MODEL" \
  --prompt "A clean product photo of a ceramic mug on a walnut desk." \
  --out outputs/mug.png
```

Editing:

```bash
scripts/invoke_custom_image_api.sh \
  --mode edit \
  --endpoint "$CUSTOM_IMAGE_API_URL" \
  --model "$CUSTOM_IMAGE_MODEL" \
  --image input.png \
  --prompt "Improve lighting while preserving composition and object identity." \
  --out outputs/input-edited.png
```

If the endpoint is passed as a port number, the helper expands it to
`http://127.0.0.1:<port>/v1/images/generations` or
`http://127.0.0.1:<port>/v1/images/edits` based on the selected mode.

## API Compatibility

The helper accepts common OpenAI-compatible response shapes, including:

- `data[0].b64_json`
- `data[0].url`
- `image`
- `b64_json`
- `base64`
- `output[0].result`

See `references/api-contract.md` before adapting the helper to a provider with
a different request or response shape.

## Development

Run the project checks before committing:

```bash
scripts/check_project.sh
```

The check verifies required files, validates `SKILL.md` frontmatter basics, and
runs Bash syntax checks for the shell helpers.

