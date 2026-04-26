---
name: ryan-changelog-release
description: Release discipline + changelog workflow (Keep a Changelog style) and how to ship safely. Use when the user asks for a release, version bump, changelog update, deployment summary, or “what changed?” notes.
---

# Changelog + release workflow

## Default changelog standard

Use **Keep a Changelog** conventions:
- `Unreleased` section exists at all times
- Group changes under `Added`, `Changed`, `Fixed`, `Removed`, `Security`
- Each release gets a dated heading

## Workflow (PR/branch level)

1. **Before coding**: decide where changelog entries live
   - preferred: root `CHANGELOG.md`
   - acceptable: package-level changelogs if monorepo
2. **During coding**: append short bullets to `Unreleased`
3. **Before merge/release**:
   - move items from `Unreleased` into a new version section
   - include any migration notes / breaking changes
4. **After deploy**: ensure the changelog matches what shipped

## Release note template (copy/paste)

```markdown
## Summary
- …

## Changes
- Added: …
- Changed: …
- Fixed: …

## Risk / rollout
- …

## Verification
- …
```

## Safety defaults

- Never claim “released” unless there is evidence (tag pushed, build published, deploy completed).
- Prefer incremental releases with a short verification step.

