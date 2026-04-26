---
name: ryan-ops-loop
description: >-
  Ongoing operational agent loop (triage → reproduce → fix → verify → ship → record). Use for
  production support, bugfixes, CI failures, and iterative maintenance tasks.
---

# Ops loop (ongoing process)

## Loop

1. **Triage**
   - define the user-visible symptom and severity
   - identify owner system (frontend, functions, infra)
2. **Reproduce**
   - get exact steps/logs
   - reduce to minimal repro
3. **Fix**
   - smallest safe change first
4. **Verify**
   - run the narrowest check that proves correctness (tests/lint/manual)
5. **Ship**
   - deploy/release steps (as applicable)
6. **Record**
   - update `CHANGELOG.md` (or incident notes)
   - note follow-ups

## Operational safety defaults

- Prefer reversible changes.
- Avoid “big bang” refactors during incident response.
- Don’t claim success without verification evidence.

