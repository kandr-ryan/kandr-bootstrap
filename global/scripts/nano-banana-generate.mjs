#!/usr/bin/env node
/**
 * Generate an image via Google Nano Banana (Gemini Image API).
 *
 * Usage:
 *   node ~/.cursor/scripts/nano-banana-generate.mjs \
 *     --prompt "A flat logo for a pizzeria" \
 *     --output ./public/images/hero.jpg \
 *     [--model gemini-2.5-flash-image] \
 *     [--reference /path/to/ref.png]
 *
 * Requires GEMINI_API_KEY in the environment (or loaded from the global rule / GCP).
 */

import { readFileSync, writeFileSync, mkdirSync } from "node:fs";
import { dirname, extname } from "node:path";

const DEFAULT_MODEL = "gemini-2.5-flash-image";

function parseArgs(argv) {
  const args = { model: DEFAULT_MODEL };
  for (let i = 2; i < argv.length; i++) {
    const arg = argv[i];
    if (arg === "--prompt") args.prompt = argv[++i];
    else if (arg === "--output") args.output = argv[++i];
    else if (arg === "--model") args.model = argv[++i];
    else if (arg === "--reference") args.reference = argv[++i];
    else if (arg === "--help") args.help = true;
  }
  return args;
}

function mimeFromPath(path) {
  const ext = extname(path).toLowerCase();
  if (ext === ".jpg" || ext === ".jpeg") return "image/jpeg";
  if (ext === ".webp") return "image/webp";
  return "image/png";
}

async function main() {
  const args = parseArgs(process.argv);

  if (args.help || !args.prompt || !args.output) {
    console.log(`Usage:
  node nano-banana-generate.mjs --prompt "..." --output path/to/image.png [--model MODEL] [--reference path]

Models (Nano Banana):
  gemini-2.5-flash-image              — Nano Banana (fast, default)
  gemini-3.1-flash-image-preview      — Nano Banana 2
  gemini-3-pro-image-preview          — Nano Banana Pro

Env:
  GEMINI_API_KEY — required`);
    process.exit(args.help ? 0 : 1);
  }

  const apiKey = process.env.GEMINI_API_KEY;
  if (!apiKey) {
    console.error("Error: GEMINI_API_KEY is not set.");
    console.error('Load it: export GEMINI_API_KEY="$(gcloud secrets versions access latest --secret=GEMINI_API_KEY --project=rlibbey-pocs)"');
    process.exit(1);
  }

  const parts = [{ text: args.prompt }];
  if (args.reference) {
    const data = readFileSync(args.reference).toString("base64");
    parts.push({
      inline_data: {
        mime_type: mimeFromPath(args.reference),
        data,
      },
    });
  }

  const url = `https://generativelanguage.googleapis.com/v1beta/models/${args.model}:generateContent`;

  const res = await fetch(url, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "x-goog-api-key": apiKey,
    },
    body: JSON.stringify({
      contents: [{ parts }],
      generationConfig: {
        responseModalities: ["TEXT", "IMAGE"],
      },
    }),
  });

  if (!res.ok) {
    const err = await res.text();
    console.error(`API error ${res.status}:`, err);
    process.exit(1);
  }

  const json = await res.json();
  const responseParts = json.candidates?.[0]?.content?.parts ?? [];
  const imagePart = responseParts.find((p) => p.inlineData || p.inline_data);

  if (!imagePart) {
    const text = responseParts.find((p) => p.text)?.text;
    console.error("No image in response.", text ? `Model said: ${text}` : json);
    process.exit(1);
  }

  const inline = imagePart.inlineData ?? imagePart.inline_data;
  const buffer = Buffer.from(inline.data, "base64");
  mkdirSync(dirname(args.output), { recursive: true });
  writeFileSync(args.output, buffer);
  console.log(`Saved: ${args.output} (${buffer.length} bytes, model: ${args.model})`);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
