# Runtime Environment Notes

These notes describe the environment where this skill was created and tested.

## Tested Windows Environment

- OS/user path shape: Windows, `C:\Users\Administrator\...`
- Workspace used during creation: `C:\Users\Administrator\Documents\New project 3`
- Skill install path: `C:\Users\Administrator\.codex\skills\custom-image-api`
- Shell: PowerShell
- Network: enabled
- Image API endpoint tested through an OpenAI-compatible `/v1` service
- Model list check succeeded against `/v1/models`
- Image edit request succeeded against `/v1/images/edits`
- Tested model id: `gpt-image-2`

## Important Local Tooling Details

- `curl.exe` was available and used for multipart image uploads.
- PowerShell's `Invoke-RestMethod -Form` was not available in this environment.
- The script therefore prefers `curl.exe` for edit mode and falls back to manual multipart upload only if `curl.exe` is missing.
- `python` resolved to the WindowsApps placeholder at `C:\Users\Administrator\AppData\Local\Microsoft\WindowsApps\python.exe`, so Python scripts were not usable here.
- No API key or fixed provider URL is stored in the skill.

## Primary Target: Mac Migration Notes

Install by placing the folder here:

```bash
~/.codex/skills/custom-image-api
```

Set environment variables in the shell that launches Codex:

```bash
export CUSTOM_IMAGE_API_URL="https://your-provider.example/v1/images/edits"
export CUSTOM_IMAGE_API_KEY="your-api-key"
export CUSTOM_IMAGE_MODEL="gpt-image-2"
```

For generation, use a generation endpoint:

```bash
export CUSTOM_IMAGE_API_URL="https://your-provider.example/v1/images/generations"
```

Mac troubleshooting checks:

```bash
which curl
curl --version
curl "$OPENAI_BASE_URL/models" -H "Authorization: Bearer $OPENAI_API_KEY"
```

If Codex does not discover the skill after copying it, restart Codex and confirm the folder contains `SKILL.md` directly at:

```bash
~/.codex/skills/custom-image-api/SKILL.md
```

Prefer the Bash helper on Mac:

```bash
chmod +x ~/.codex/skills/custom-image-api/scripts/invoke_custom_image_api.sh
~/.codex/skills/custom-image-api/scripts/invoke_custom_image_api.sh \
  --mode edit \
  --endpoint "$CUSTOM_IMAGE_API_URL" \
  --model "$CUSTOM_IMAGE_MODEL" \
  --image "/path/to/input.png" \
  --prompt "Enhance this image while preserving composition." \
  --out "/path/to/output.png"
```

The Bash helper depends on common macOS tools:

- `curl`
- `python3`

macOS usually includes `curl`. If `python3` is missing, install Command Line Tools or Python from python.org/Homebrew.

## Common Failure Modes

- `model` appears empty on the server: multipart form upload is not being parsed correctly. Prefer `curl` upload.
- `This token has no access to model`: the key, provider account, or model id is not authorized.
- `Could not find an image payload`: the provider returned a nonstandard JSON shape. Inspect the raw response and update `Extract-ImagePayload` in `scripts/invoke_custom_image_api.ps1`.
- Edit endpoint fails but generation works: verify the provider supports image editing for that model, not only image generation.
