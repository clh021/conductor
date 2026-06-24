"""Helpers for rendering final workflow result summaries."""

from __future__ import annotations

import json
from typing import Any, Protocol


class SummaryPrinter(Protocol):
    """Callable used to emit summary lines."""

    def __call__(self, text: str = "", *, style: str | None = None) -> None: ...


def _extract_script_result_summary(output: Any) -> str | None:
    """Extract a concise summary from a script agent's stored output."""
    if not isinstance(output, dict):
        return None

    summary: str | None = None
    if isinstance(output.get("summary"), str) and output.get("summary"):
        summary = output["summary"]

    stdout = output.get("stdout")
    if isinstance(stdout, str) and stdout.strip():
        for line in reversed(stdout.splitlines()):
            candidate = line.strip()
            if not candidate:
                continue
            if candidate.startswith("{") and candidate.endswith("}"):
                try:
                    parsed = json.loads(candidate)
                except json.JSONDecodeError:
                    break
                if isinstance(parsed, dict) and isinstance(parsed.get("summary"), str):
                    summary = parsed["summary"]
                break
    return summary


def _extract_review_highlights(output: Any, *, max_lines: int = 6) -> list[str]:
    """Extract high-signal review lines from script stdout for final reporting."""
    if not isinstance(output, dict):
        return []

    stdout = output.get("stdout")
    if not isinstance(stdout, str) or not stdout.strip():
        return []

    patterns = (
        "审查结果",
        "阻塞性",
        "不建议直接发布",
        "必须在发布前修复",
        "建议修复",
        "总结：",
        "总结:",
    )
    highlights: list[str] = []
    seen: set[str] = set()
    for raw_line in stdout.splitlines():
        line = raw_line.strip()
        if not line:
            continue
        if any(token in line for token in patterns):
            if line not in seen:
                seen.add(line)
                highlights.append(line)
            if len(highlights) >= max_lines:
                break
    return highlights


def emit_workflow_result_summary(
    result: dict[str, Any] | None,
    execution_summary: dict[str, Any] | None,
    print_line: SummaryPrinter,
) -> None:
    """Emit a concise final workflow summary with stage-level results."""
    print_line()
    print_line("=" * 60, style="dim")
    print_line("[bold cyan]Workflow Result Summary[/bold cyan]")

    if result:
        pipeline_result = result.get("pipeline_result")
        final_status = result.get("final_status")
        if pipeline_result is not None:
            print_line(f"  pipeline_result: {pipeline_result}", style="dim")
        if final_status is not None:
            print_line(f"  final_status: {final_status}", style="dim")

    agent_outputs: dict[str, Any] = {}
    if execution_summary and isinstance(execution_summary.get("agent_outputs"), dict):
        agent_outputs = execution_summary["agent_outputs"]

    if not agent_outputs:
        return

    print_line()
    print_line("[bold cyan]Stage Summaries:[/bold cyan]")
    for agent_name, output in agent_outputs.items():
        if not isinstance(output, dict):
            continue
        exit_code = output.get("exit_code")
        summary = _extract_script_result_summary(output)
        if summary or exit_code is not None:
            parts = [agent_name]
            if exit_code is not None:
                parts.append(f"exit={exit_code}")
            if summary:
                parts.append(summary)
            print_line(f"  - {' | '.join(parts)}", style="dim")

    review_agents = ("reasonix_review", "retry_reasonix", "codex_review")
    review_lines: list[str] = []
    seen_lines: set[str] = set()
    for agent_name in review_agents:
        output = agent_outputs.get(agent_name)
        if output is None:
            continue
        for line in _extract_review_highlights(output):
            tag = f"{agent_name}: {line}"
            if tag not in seen_lines:
                seen_lines.add(tag)
                review_lines.append(tag)
    if not review_lines:
        return

    print_line()
    print_line("[bold cyan]Review Highlights:[/bold cyan]")
    for line in review_lines:
        print_line(f"  - {line}", style="dim")
