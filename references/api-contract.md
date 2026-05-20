# Custom Image API Contract

The helper script sends either JSON or multipart form-data.

Generation JSON body:

```json
{
  "model": "model-name",
  "prompt": "prompt text"
}
```

Edit multipart fields:

- `model`
- `prompt`
- `image`: file upload

Authorization:

- If `CUSTOM_IMAGE_API_KEY` or `-ApiKey` is set, send `Authorization: Bearer <key>`.

Expected responses:

- OpenAI-compatible: `{ "data": [{ "b64_json": "..." }] }`
- URL response: `{ "data": [{ "url": "https://..." }] }`
- Simple base64: `{ "image": "..." }`, `{ "base64": "..." }`, or `{ "b64_json": "..." }`
- Nested output: `{ "output": [{ "result": "..." }] }`

For other response shapes, inspect the JSON and update `Extract-ImagePayload` in the script.
