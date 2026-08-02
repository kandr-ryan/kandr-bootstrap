---
name: kandr-images
description: Generating image assets with Google Nano Banana (Gemini Image API) instead of the built-in image tool — resolving the API key, choosing between the three models, running the generate script with or without a reference image, and prompt guidance for logos and web assets. Use whenever asked to generate, create, produce, or edit an image, logo, icon, hero, mockup, or visual asset.
---

# Image generation — Nano Banana (Gemini)

**Never use the built-in `GenerateImage` tool.** All image generation goes through the Gemini
Image API via the helper script below.

## API key

The canonical tooling key lives in GCP Secret Manager on `rlibbey-pocs`. Resolve it, never paste it:

```bash
export GEMINI_API_KEY="$(gcloud secrets versions access latest --secret=GEMINI_API_KEY --project=rlibbey-pocs)"
```

If `GEMINI_API_KEY` is already exported in the session, use it as-is and skip the fetch.

Apps that call Gemini at runtime (`kandr-crm-app`, `ak-consulting-kandr-app`, `fishon-kandr-app`,
`kandr-radio-app`, `pizzeria-pfiff-kandr`) each hold their own `GEMINI_API_KEY` on their own
project. Use the app's key for app code; use the `rlibbey-pocs` key only for agent-side asset
generation.

Never paste a key into this skill or any other tracked file.

## Models (pick by job)

| Nickname | Model ID | Use when |
|---|---|---|
| Nano Banana | `gemini-2.5-flash-image` | Default — fast, cheap, most assets |
| Nano Banana 2 | `gemini-3.1-flash-image-preview` | Better quality / editing, balanced |
| Nano Banana Pro | `gemini-3-pro-image-preview` | Text in image, logos, studio-quality |

Default to **`gemini-2.5-flash-image`** unless the user asks for higher fidelity or text-heavy
artwork.

## How to generate

```bash
export GEMINI_API_KEY="$(gcloud secrets versions access latest --secret=GEMINI_API_KEY --project=rlibbey-pocs)"

node ~/.cursor/scripts/nano-banana-generate.mjs \
  --prompt "Detailed prompt describing subject, style, colors, layout, no text unless requested" \
  --output "/absolute/path/to/output.png" \
  --model gemini-2.5-flash-image
```

**With a reference image** (edit / style match):

```bash
node ~/.cursor/scripts/nano-banana-generate.mjs \
  --prompt "Same logo but flat, no perspective, transparent-friendly" \
  --reference "/path/to/reference.png" \
  --output "/path/to/output.png"
```

## Workflow

1. Confirm the output path in the active project (e.g. `public/images/`).
2. Load `GEMINI_API_KEY` from the session env, else from Secret Manager.
3. Run `nano-banana-generate.mjs` via Shell — do not substitute other image tools.
4. Wire the saved file into the app (import path, `<img src>`, etc.).

## Prompt tips

- Be specific: subject, lighting, camera angle, color palette, background.
- For web assets: mention aspect ratio (e.g. "16:9 hero banner", "square logo").
- For logos: request flat, front-facing, no mockup perspective unless asked.

## Docs

- [Gemini Image Generation (Nano Banana)](https://ai.google.dev/gemini-api/docs/image-generation)
