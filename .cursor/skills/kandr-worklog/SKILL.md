---
name: kandr-worklog
description: How work gets recorded across every Kandr project — the changelog entry format, the backlog as source of truth for what is left, release notes, and the rule against per-item time estimates in punch lists. Use at the start and end of any implementation session, when writing a changelog or release notes, when asked what changed, or when producing a task list or QA checklist.
---

# Work logging

Two files carry the record. They are complementary, not redundant:

- **`CHANGELOG.md`** — what was done, per session
- **`BACKLOG.md`** — what is left to do

Both get updated at the end of every implementation session. The exact paths and any extra
log a project keeps live in that repo's `kandr-overlay.mdc`.

---

## 1. Changelog

Append an entry after completing work in a session.

```markdown
## YYYY-MM-DD

### Summary
- Brief bullets of what was done

### Files Changed
- Key files added or modified — the meaningful ones, not every file

### Notes
- Decisions made, issues hit, follow-up items
```

Rules:

- New entries go at the **top** of the file, below the title. Newest first
- Use today's actual date
- Keep it concise — three to eight bullets per section
- Group related changes
- Do not log routine git operations as separate items
- Never log a secret, key, token, or credential value

### When to log

Log it: a feature, a bugfix, a refactor, a new script, a deploy, a rules or functions change.

Skip it: questions, architecture discussion with no file changes, read-only review.

Some projects keep an additional `docs/CODING_LOG.md` with a per-task entry. If the project
overlay names one, follow its format; the same reverse-chronological and no-secrets rules apply.

---

## 2. Backlog

`BACKLOG.md` at the repo root is the single source of truth for open work items.

**At the start of a session:** read it, and identify which items you are about to work on.
You do not need to edit it yet.

**When a plan is confirmed:** add the plan's todos to the appropriate Pending section before
implementation starts.

**At the end of a session:**

1. Move completed items from Pending into Completed, with today's date
2. Add newly discovered work to the appropriate Pending section
3. **Never delete an item — only move it.** Completed is a permanent record
4. If a later-phase item got done early, move it with a note

Format:

```
Pending:   | `item-id` | [Area] | One-line description |
Completed: | YYYY-MM-DD | `item-id` | [Area] | One-line description |
```

Area tags are per-project (`[iOS]`, `[Admin]`, `[Functions]`, `[Firebase]`, `[Scripts]`, and so on).

---

## 3. Release notes

Use Keep a Changelog conventions for versioned releases: an `Unreleased` section always exists,
changes group under `Added` / `Changed` / `Fixed` / `Removed` / `Security`, and each release
gets a dated heading. Move items out of `Unreleased` into the new version section at release time.

Release note template:

```markdown
## Summary
- ...

## Changes
- Added: ...
- Changed: ...
- Fixed: ...

## Risk / rollout
- ...

## Verification
- ...
```

**Never claim something is released without evidence** — a tag pushed, a build published, a
deploy completed. Prefer incremental releases with a short verification step over one large
release nobody can verify.

After deploying, confirm the changelog matches what actually shipped.

---

## 4. No per-item time estimates

Punch lists, QA checklists, and task lists must **not** carry per-item duration estimates —
no `~15 min`, no `(2h)` on individual bullets. They are consistently wrong, they invite
false precision, and they make a list harder to scan.

Phase-level or project-level estimates in a planning document are fine.

---

## Related skills

- `kandr-development` — plan and blueprint before the work
- `kandr-qa` — verify before recording it as done
- `kandr-deploy` — ship it before recording it as shipped
