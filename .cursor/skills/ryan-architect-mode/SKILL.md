---
name: ryan-architect-mode
description: >-
  How to use an architect agent before implementation: gather requirements, scan existing
  patterns, propose file-level changes, and produce an execution sequence. Use when work is
  large/ambiguous, spans many files/systems, or needs a clear blueprint before coding.
---

# Architect mode (before coding)

## When to switch into architect mode

Use architect mode when:
- there are multiple valid implementations with real trade-offs
- the change crosses frontend/backend/infrastructure boundaries
- you need a sequence (migrations, releases, rollout plan)

## Output requirements

Produce a blueprint that includes:
- key decisions + chosen defaults
- files to create/modify (by path)
- data flow (if applicable)
- verification plan (lint/tests/manual checks)
- rollout plan (if risky)

## Implementation sequence

Provide an ordered build sequence so execution is straightforward:
- scaffold
- implement core logic
- wire UI/API
- add verification
- ship

