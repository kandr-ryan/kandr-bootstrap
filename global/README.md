# Global Cursor layer

The agent configuration that applies in **every** repo. `~/.cursor/rules`, `~/.cursor/skills`, and
`~/.cursor/scripts` are symlinks into this directory, so there is one copy and it is the one in git.

```
~/.cursor/rules   -> global/rules
~/.cursor/skills  -> global/skills
~/.cursor/scripts -> global/scripts
```

Edit either path — they are the same files. Changes show up in `git status` here immediately,
which is the entire point: the previous arrangement kept a hand-copied mirror, and it silently
drifted twice.

## Why this is not in `.cursor/`

Cursor treats a repo's `.cursor/` as **project** configuration. When the mirror lived there, opening
this repo loaded all four global rules a second time and created name collisions for all 14
`kandr-*` skills. `global/` is inert to Cursor, which is what we want for a mirror.

## What is here

| Path | Loads | Holds |
|---|---|---|
| `rules/` | every request, in every repo | The router and the standing safety rules. Keep this small — it is charged on every turn. |
| `skills/` | when the description matches | Process playbooks (`kandr-development`, `kandr-qa`, …) and service reference (`kandr-stripe`, `kandr-aws`, …) |
| `scripts/` | when a skill invokes one | `kandr-secrets.sh`, `nano-banana-generate.mjs` — referenced by skills using absolute `~/.cursor/scripts/` paths |

Only four rules are always-on, totalling ~134 lines. Anything that is reference data belongs in a
skill; anything that must fire without a trigger belongs in `rules/kandr-router.mdc`. See
`docs/instruction-architecture.md` for the full four-layer model.

## Setting this up on a new machine

```bash
git clone https://github.com/kandr-ryan/kandr-bootstrap.git ~/Apps/kandr-bootstrap
~/Apps/kandr-bootstrap/scripts/link-global-cursor.sh
```

The script refuses to clobber real directories — if `~/.cursor/rules` already exists as a
directory, it backs it up first and tells you where.

## Secrets

Nothing in this directory may contain a credential value. Secrets resolve from GCP Secret Manager
at runtime via `kandr-secrets`; only project IDs and secret *names* belong here. This repo is
public-adjacent — treat it as if it were public.
