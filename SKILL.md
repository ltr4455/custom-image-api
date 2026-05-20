---
name: custom-image-api
description: Generate or edit raster images through a user-provided HTTP image model API instead of the built-in image generation tool. Use when the user mentions a custom image endpoint, local proxy, request port, OpenAI-compatible image API, nonstandard image model API, or says they cannot directly call image-2/gpt-image but can provide an API URL, key, model, or port for image generation or image editing.
---

# Custom Image API

Use this skill when the user wants image generation or image editing through their own API endpoint.

## Configuration

Prefer environment variables unless the user provides explicit values in the request:

- `CUSTOM_IMAGE_API_URL`: full endpoint URL, for example `http://127.0.0.1:3000/v1/images/edits`
- `CUSTOM_IMAGE_API_KEY`: bearer token, if required
- `CUSTOM_IMAGE_MODEL`: model name, for example `gpt-image-1.5`, `gpt-image-2`, or a proxy-specific model id

If an endpoint is only provided as a port, infer `http://127.0.0.1:<port>/v1/images/generations` for generation and `http://127.0.0.1:<port>/v1/images/edits` for edits unless the user states a different route.

## Workflow

1. Decide whether the user asks for generation or editing.
2. For editing, inspect the target image first if it is only a local path.
3. Use `scripts/invoke_custom_image_api.ps1` instead of the built-in image tool when the user wants the custom endpoint.
4. Preserve source images by default. Save outputs next to the source image or under the current workspace unless the user names a destination.
5. Keep prompts explicit about invariants for edits: preserve identity, pose, composition, outfit, and background unless the user asked to change them.
6. Report the saved output path and the endpoint/model used. Do not print API keys.

## Script

On macOS/Linux, prefer the Bash helper:

```bash
"<skill>/scripts/invoke_custom_image_api.sh" \
  --mode edit \
  --endpoint "http://127.0.0.1:3000/v1/images/edits" \
  --model "model-name" \
  --image "input.png" \
  --prompt "..." \
  --out "output.png"
```

On Windows, use the PowerShell helper:

```powershell
powershell -ExecutionPolicy Bypass -File "<skill>/scripts/invoke_custom_image_api.ps1" `
  -Mode edit `
  -Endpoint "http://127.0.0.1:3000/v1/images/edits" `
  -Model "model-name" `
  -Image "input.png" `
  -Prompt "..." `
  -Out "output.png"
```

For generation, omit `-Image` and use `-Mode generate`.

The script supports common OpenAI-compatible JSON responses containing `data[0].b64_json`, `data[0].url`, `image`, `b64_json`, `base64`, or `output[0].result`.

Read `references/api-contract.md` only when adapting to a non-compatible API shape.
Read `references/runtime-environment.md` when migrating the skill to Mac or troubleshooting platform differences.
