## Project templates (generic)

These are “shape” templates you can apply across projects without hard-coding vendor specifics.

### Web app (React/Vite) + backend functions (serverless)

Common layout:

```text
project/
  src/
  public/
  index.html
  package.json
  functions/
    src/
    package.json
  scripts/
  .cursor/
    rules/
    skills/
```

Principles:
- Keep `functions/` its own package if your platform deploys it independently.
- Prefer scripts in `package.json` for common workflows (dev, build, deploy, emulator).
- Keep secrets in a managed secret store; do not commit `.env` with real keys.

### Cloud Run / container service

```text
service/
  src/
  Dockerfile
  package.json
  .cursor/
    rules/
```

Principles:
- Build small runtime images.
- Separate “deploy” scripts from “dev” scripts.

