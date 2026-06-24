# Agent Fork Update Runbook

This document is the operational runbook for an AI agent maintaining this fork.

Use it when the goal is:

- sync local branches with the latest upstream changes
- rebase or merge fork patches onto the latest `main`
- keep local patches small and easy to maintain
- avoid unnecessary history damage

## What To Tell The Agent

Use this exact instruction next time:

```text
Read docs/agent-fork-update-runbook.md and execute it.
Goal: sync upstream changes into this fork, keep local runtime patches maintainable, and leave me with a clean summary of what changed.
```

If you want the agent to also run validation:

```text
Read docs/agent-fork-update-runbook.md and execute it.
After syncing and reorganizing the fork branch, run the validation steps from the document and tell me which failures are new versus pre-existing.
```

## Repository Branch Model

Treat these branches as canonical unless the user explicitly says otherwise:

- `main`: local mirror of upstream `main`
- `lee/runtime-patches`: the active fork branch with local patches
- `backup/lee-runtime-patches-before-cleanup`: optional local safety backup before history rewriting

In this clone, `origin/main` is the current upstream source of truth.
If an `upstream` remote is added later, prefer `upstream/main` for upstream sync and keep `origin` as the fork remote.

## Local Patch Set

The fork branch currently preserves these behaviors:

1. UTF-8 is preserved in workflow inputs, event logs, and checkpoints.
2. The CLI prints a local final workflow result summary.
3. Copilot custom routing defers startup connectivity validation.
4. Local standalone binary packaging is supported.

The current fork branch also includes one cleanup-only commit:

- `chore: satisfy local lint cleanup`

## Safety Rules

The agent must follow these rules:

1. Never destroy history without a backup branch first when rewriting `lee/runtime-patches`.
2. Never use plain `git push --force`; use `git push --force-with-lease`.
3. Never delete the backup branch unless the user explicitly asks.
4. Never assume full test suite failures are caused by the fork changes; distinguish new failures from existing baseline failures.
5. Do not rewrite `main`; fast-forward it only.
6. If the fork branch can be cleaned up by rebuilding a smaller patch stack from `main`, prefer that over stacking merges forever.

## Standard Procedure

### 1. Inspect Current State

Run:

```bash
git status --short --branch
git remote -v
git branch -vv
git branch -r
git fetch --prune origin
```

If an `upstream` remote exists, also run:

```bash
git fetch --prune upstream
```

### 2. Sync `main`

If `upstream/main` exists:

```bash
git checkout main
git merge --ff-only upstream/main
```

Otherwise:

```bash
git checkout main
git merge --ff-only origin/main
```

Do not create a merge commit on `main`.

### 3. Return To Fork Branch

```bash
git checkout lee/runtime-patches
```

Decide whether the branch only needs a normal rebase or should be restacked into a cleaner patch series.

### 4. Choose Rebase Strategy

Use a plain rebase when:

- the existing patch stack is already clean
- commit boundaries are still useful
- there is no obvious dead or redundant patch

Use a rebuild/restack when:

- the fork branch contains merge commits from old upstream syncs
- local changes are mixed together in large commits
- a patch is now redundant because upstream behavior already covers it
- the branch would be easier to maintain as a few small topical commits

### 5. Before Rewriting Fork History

Create a safety branch:

```bash
git branch backup/lee-runtime-patches-before-cleanup
```

If that branch already exists, either reuse it or create a dated backup branch instead.

### 6. Preferred Restack Shape

When rebuilding the fork branch, prefer a small linear patch stack like this:

1. `feat: preserve utf8 and add local result summaries`
2. `fix: defer validation for custom copilot routing`
3. `build: add local standalone binary packaging`
4. `chore: satisfy local lint cleanup`

Do not reintroduce the old `script-only workflow skips provider initialization` patch unless the current codebase truly needs it again.

### 7. Validation

Run focused regression checks first:

```bash
uv run pytest \
  tests/test_cli/test_run.py \
  tests/test_engine/test_event_log.py \
  tests/test_engine/test_checkpoint.py \
  tests/test_providers/test_copilot_provider_routing.py
```

Then run the broader checks when requested or when the change is significant:

```bash
make check
make test
```

When reporting failures:

- identify whether they are in touched files or untouched areas
- identify whether they look pre-existing versus newly introduced
- do not silently ignore failures

## Push Policy

If the fork branch history was rewritten:

```bash
git push --force-with-lease origin lee/runtime-patches
```

If the fork branch was only fast-forwarded or received new normal commits:

```bash
git push origin lee/runtime-patches
```

Do not push the backup branch unless the user asks.

## Expected End State

The agent should leave the repo in this state:

- `main` matches the latest upstream mainline source
- `lee/runtime-patches` is clean, linear, and easier to maintain
- working tree is clean
- remote branch matches the intended local fork branch
- the user receives a short summary of:
  - which branches changed
  - whether history was rewritten
  - which validations passed
  - which failures remain and whether they appear pre-existing

## Suggested Final Report Format

The agent should report something like:

```text
Updated `main` to the latest upstream state and rebased/restacked `lee/runtime-patches`.
Created or refreshed a local backup branch before rewriting history.
Pushed the cleaned fork branch with `--force-with-lease`.

Validation:
- Focused fork regression tests: passed
- `make check`: passed / failed with pre-existing issue at ...
- `make test`: passed / failed with pre-existing failures in ...
```

## File Hotspots

If conflicts happen, inspect these files first:

- `src/conductor/cli/run.py`
- `src/conductor/cli/result_summary.py`
- `src/conductor/engine/checkpoint.py`
- `src/conductor/engine/event_log.py`
- `src/conductor/providers/copilot.py`
- `src/conductor/__init__.py`
- `tests/test_cli/test_run.py`
- `docs/fork-maintenance.md`

## Related Document

See also:

- `docs/fork-maintenance.md`
