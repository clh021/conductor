# Fork Maintenance

This fork carries local runtime patches for a script-heavy workflow setup. The goal is to keep the CLI behavior reproducible across upgrades, reinstalls, and machine changes without mixing personal workflow assets into the Conductor source tree.

## Scope

This fork intentionally contains only Conductor runtime changes. Personal workflow assets stay outside the repo:

- `~/.config/conductor/workflows/*.yaml`
- `~/shell/phases/*.sh`

That separation keeps upstream rebases small and avoids coupling the CLI runtime to one machine's local workflow inventory.

## Agent Runbook

For future AI-assisted upstream sync and fork cleanup work, use:

- `docs/agent-fork-update-runbook.md`

Recommended prompt:

```text
Read docs/agent-fork-update-runbook.md and execute it.
Goal: sync upstream changes into this fork, keep local runtime patches maintainable, and leave me with a clean summary of what changed.
```

## Local Patch Set

The current branch keeps four local changes:

1. Preserve UTF-8 in workflow inputs, event logs, and checkpoints instead of ASCII-escaping non-English text.
2. Print a final workflow result summary with stage-level summaries and review highlights.
3. Allow Copilot custom-routing sessions to defer startup connectivity validation until the first real request.
4. Support local standalone binary builds, including a safe `0+unknown` version fallback when package metadata is unavailable.

These patches are intentionally covered by focused tests so future rebases can detect regressions early.

## Recommended Branch Strategy

- Keep fork-specific work on a dedicated branch such as `lee/runtime-patches`.
- Rebase that branch onto upstream `main` instead of working directly on `main`.
- Keep each runtime behavior change in a small commit when possible.

Example update flow:

```bash
git checkout main
git fetch upstream
git rebase upstream/main
git checkout lee/runtime-patches
git rebase main
```

If a rebase touches any of these files, rerun the focused tests listed below before reinstalling the CLI:

- `src/conductor/cli/run.py`
- `src/conductor/cli/result_summary.py`
- `src/conductor/engine/event_log.py`
- `src/conductor/engine/checkpoint.py`
- `src/conductor/providers/copilot.py`
- `src/conductor/__init__.py`

## Local Development

Install dependencies for repo development:

```bash
uv sync --group dev
```

Run the CLI from the repo without replacing the global tool:

```bash
uv run conductor --version
```

Install the fork as the active local CLI tool:

```bash
uv tool install --force /home/lee/Projects/conductor
```

For iterative local development, an editable tool install is also valid:

```bash
cd /home/lee/Projects/conductor
uv tool install --force --editable .
```

## Binary Build

This fork also ships a local one-command binary build script:

```bash
cd /home/lee/Projects/conductor
./build.sh --clean --onefile
```

Default output:

- Single-file binary: `dist-binary/conductor`

Useful variants:

```bash
./build.sh --onedir
./build.sh --name conductor-local
```

Notes:

- The script uses PyInstaller.
- It bundles `conductor/web/static` assets for the dashboard.
- It copies `conductor-cli` package metadata so `conductor --version` works in the built binary.
- If package metadata is still unavailable at runtime, the code now falls back to version `0+unknown` instead of crashing on import.

## Focused Regression Checks

Run these before and after an upstream rebase:

```bash
cd /home/lee/Projects/conductor
uv run pytest \
  tests/test_cli/test_run.py \
  tests/test_engine/test_event_log.py \
  tests/test_engine/test_checkpoint.py \
  tests/test_providers/test_copilot_provider_routing.py
```

For a broader sanity pass:

```bash
make check
make test
```

## Reinstall and Verification

After updating the fork branch, reinstall the tool and verify the active source:

```bash
uv tool install --force /home/lee/Projects/conductor
uv tool list
```

Then verify the patched behaviors with a quick smoke check:

1. Pass Chinese input text and confirm workflow logs/checkpoints keep readable UTF-8.
2. Confirm the run output ends with `Workflow Result Summary`.
3. Run a custom-routed Copilot workflow and confirm startup no longer requires a Copilot-authorized `models.list`.
4. Build the standalone binary and confirm `--version` works even if package metadata is absent.
