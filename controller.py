#!/usr/bin/env python3
"""
controller.py – Multi-Agent Orchestrator for the AIOS Repository
=================================================================
Manages a set of named agents, each restricted to a specific set of
directories/files.  Runs agents in a fixed priority order, detects
scope violations and cross-agent file conflicts, logs everything with
timestamps, and prints a summary report after every cycle.

Quick-start
-----------
Run one cycle (dry-run, no LLM calls):
    python3 controller.py --cycles 1 --dry-run

Run three improvement cycles with OpenAI back-end:
    OPENAI_API_KEY=sk-... python3 controller.py --cycles 3

Add a new agent at runtime:
    See "Adding a new agent" section at the bottom of this file, or
    pass --agent-config path/to/extra_agents.json on the CLI.

Log files are written to  logs/controller_<ISO-timestamp>.log
"""

from __future__ import annotations

import argparse
import json
import logging
import os
import pathlib
import sys
import time
from datetime import datetime, timezone
from typing import Any

# ──────────────────────────────────────────────────────────────────────────────
# 1.  AGENT REGISTRY
#     Each entry defines:
#       name       – human-readable label
#       scope      – list of paths (files or directories) the agent may touch
#       prompt     – instruction sent to the LLM (or printed in dry-run mode)
#       run_order  – lower number runs first; ties are broken alphabetically
#                    by agent name (duplicate values are allowed)
# ──────────────────────────────────────────────────────────────────────────────

DEFAULT_AGENTS: list[dict[str, Any]] = [
    {
        "name": "Architect Agent",
        "run_order": 1,
        "scope": ["."],           # top-level layout only; enforced in code
        "scope_notes": (
            "May read any file but may only WRITE to top-level config/layout "
            "files (README.md, ROADMAP.md, directory structure). "
            "Must NOT modify implementation code."
        ),
        "prompt": (
            "You are the Architect Agent for the AIOS repository. "
            "Review the overall file tree and module separation. "
            "Propose or apply improvements to repository structure, naming "
            "conventions, and module boundaries. "
            "Do NOT modify implementation code inside bin/, OS/, ai/, or scripts/."
        ),
    },
    {
        "name": "Core Engine Agent",
        "run_order": 2,
        "scope": ["bin", "OS"],
        "scope_notes": "Owns bin/ and OS/ – launcher, bootloader, kernel, init.",
        "prompt": (
            "You are the Core Engine Agent for the AIOS repository. "
            "Your scope is bin/ and OS/. "
            "Fix and improve the launcher (bin/aios), bootloader, kernel, and "
            "init scripts inside OS/. Ensure clean startup and shutdown sequences."
        ),
    },
    {
        "name": "AI Shell Agent",
        "run_order": 3,
        "scope": ["ai"],
        "scope_notes": "Owns ai/ – interactive shell, command parsing, AI fallback.",
        "prompt": (
            "You are the AI Shell Agent for the AIOS repository. "
            "Your scope is ai/. "
            "Build and improve the interactive AI shell, command parsing pipeline, "
            "intent engine, and LLM fallback responses inside ai/core/."
        ),
    },
    {
        "name": "DevOps Agent",
        "run_order": 4,
        "scope": ["scripts", "install.sh", "run.sh", "update.sh"],
        "scope_notes": (
            "Owns scripts/ plus install.sh, run.sh, update.sh at repo root. "
            "Sets permissions, installs dependencies, cleans execution."
        ),
        "prompt": (
            "You are the DevOps Agent for the AIOS repository. "
            "Your scope is scripts/, install.sh, run.sh, and update.sh. "
            "Ensure install.sh sets correct permissions, installs all dependencies, "
            "run.sh boots the system cleanly, and update.sh pulls latest changes safely."
        ),
    },
    {
        "name": "Docs Agent",
        "run_order": 5,
        "scope": ["README.md", "CHANGELOG.md"],
        "scope_notes": "Owns README.md and CHANGELOG.md only.",
        "prompt": (
            "You are the Docs Agent for the AIOS repository. "
            "Your scope is README.md and CHANGELOG.md. "
            "Update documentation to accurately reflect the current system state, "
            "new features, and any changes made by other agents in this cycle."
        ),
    },
]


# ──────────────────────────────────────────────────────────────────────────────
# 2.  SCOPE ENFORCEMENT HELPERS
# ──────────────────────────────────────────────────────────────────────────────

def _resolve_scope(repo_root: pathlib.Path, scope: list[str]) -> list[pathlib.Path]:
    """Return a list of resolved absolute paths for an agent's scope."""
    resolved: list[pathlib.Path] = []
    for entry in scope:
        p = (repo_root / entry).resolve()
        resolved.append(p)
    return resolved


def is_in_scope(file_path: str | pathlib.Path,
                scope_paths: list[pathlib.Path]) -> bool:
    """
    Return True if *file_path* falls within at least one entry in *scope_paths*.
    A scope entry may be a directory (matches anything underneath it) or a
    specific file (exact match only).
    """
    target = pathlib.Path(file_path).resolve()
    for sp in scope_paths:
        if sp.is_dir():
            # Accept target == sp (the directory itself) or any descendant
            try:
                target.relative_to(sp)
                return True
            except ValueError:
                pass
        else:
            if target == sp:
                return True
    return False


def check_scope_violation(agent: dict[str, Any],
                          proposed_files: list[str],
                          scope_paths: list[pathlib.Path],
                          logger: logging.Logger) -> list[str]:
    """
    Validate that every file in *proposed_files* is within the agent's scope.
    Returns a list of violating file paths (empty list = all OK).
    """
    violations: list[str] = []
    for f in proposed_files:
        if not is_in_scope(f, scope_paths):
            msg = (
                f"[SCOPE VIOLATION] Agent '{agent['name']}' attempted to "
                f"modify '{f}' which is outside its scope {agent['scope']}"
            )
            logger.warning(msg)
            violations.append(f)
    return violations


# ──────────────────────────────────────────────────────────────────────────────
# 3.  CONFLICT DETECTION
#     Track which agent last "touched" a file across a single cycle.
# ──────────────────────────────────────────────────────────────────────────────

class ConflictTracker:
    """Records file→agent ownership within one cycle and reports conflicts."""

    def __init__(self) -> None:
        # maps resolved file path → name of agent that claimed it first
        self._claims: dict[str, str] = {}
        self.conflicts: list[dict[str, str]] = []

    def claim(self, agent_name: str, files: list[str]) -> list[str]:
        """
        Register *files* as claimed by *agent_name*.
        Returns a list of files that were already claimed by another agent
        (i.e., real conflicts).
        """
        conflicts_found: list[str] = []
        for f in files:
            key = str(pathlib.Path(f).resolve())
            if key in self._claims and self._claims[key] != agent_name:
                conflict = {
                    "file": key,
                    "first_agent": self._claims[key],
                    "second_agent": agent_name,
                }
                self.conflicts.append(conflict)
                conflicts_found.append(f)
            else:
                self._claims[key] = agent_name
        return conflicts_found

    def reset(self) -> None:
        self._claims.clear()
        self.conflicts.clear()


# ──────────────────────────────────────────────────────────────────────────────
# 4.  LLM BACK-END  (optional – set OPENAI_API_KEY to enable)
# ──────────────────────────────────────────────────────────────────────────────

def call_llm(prompt: str, model: str = "gpt-4o", dry_run: bool = False) -> str:
    """
    Send *prompt* to the configured LLM and return the text response.
    Falls back gracefully when the openai package is unavailable or
    OPENAI_API_KEY is not set, and when dry_run=True skips the call entirely.
    """
    if dry_run:
        return f"[DRY-RUN] Would send prompt ({len(prompt)} chars) to {model}."

    api_key = os.environ.get("OPENAI_API_KEY")
    if not api_key:
        return "[SKIPPED] OPENAI_API_KEY not set. Set it to enable LLM execution."

    try:
        import openai  # type: ignore[import]
    except ImportError:
        return (
            "[SKIPPED] openai package not installed. "
            "Run: pip install openai"
        )

    client = openai.OpenAI(api_key=api_key)
    response = client.chat.completions.create(
        model=model,
        messages=[{"role": "user", "content": prompt}],
    )
    return response.choices[0].message.content or ""


# ──────────────────────────────────────────────────────────────────────────────
# 5.  LOGGING SETUP
# ──────────────────────────────────────────────────────────────────────────────

def setup_logger(log_dir: pathlib.Path) -> logging.Logger:
    """
    Create a logger that writes to both stdout and a timestamped log file.
    Returns the configured logger instance.
    """
    log_dir.mkdir(parents=True, exist_ok=True)
    timestamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    log_file = log_dir / f"controller_{timestamp}.log"

    logger = logging.getLogger("aios_controller")
    logger.setLevel(logging.DEBUG)

    fmt = logging.Formatter(
        fmt="%(asctime)s  %(levelname)-8s  %(message)s",
        datefmt="%Y-%m-%dT%H:%M:%SZ",
    )
    fmt.converter = time.gmtime  # use UTC in log lines

    # File handler (DEBUG and above)
    fh = logging.FileHandler(log_file, encoding="utf-8")
    fh.setLevel(logging.DEBUG)
    fh.setFormatter(fmt)
    logger.addHandler(fh)

    # Console handler (INFO and above)
    ch = logging.StreamHandler(sys.stdout)
    ch.setLevel(logging.INFO)
    ch.setFormatter(fmt)
    logger.addHandler(ch)

    logger.info("Log file: %s", log_file)
    return logger


# ──────────────────────────────────────────────────────────────────────────────
# 6.  SINGLE-AGENT RUNNER
# ──────────────────────────────────────────────────────────────────────────────

def run_agent(
    agent: dict[str, Any],
    repo_root: pathlib.Path,
    conflict_tracker: ConflictTracker,
    logger: logging.Logger,
    dry_run: bool,
    llm_model: str,
) -> dict[str, Any]:
    """
    Execute a single agent and return a result dictionary with keys:
        agent, status, llm_response, scope_violations, conflicts, duration_s
    """
    start = time.monotonic()
    agent_name = agent["name"]
    logger.info("══ Starting: %s", agent_name)
    logger.debug("  Scope: %s", agent["scope"])
    logger.debug("  Prompt: %s", agent["prompt"][:120] + "…")

    # Resolve scope to absolute paths
    scope_paths = _resolve_scope(repo_root, agent["scope"])

    # ── Call the LLM (or dry-run stub) ───────────────────────────────────────
    llm_response = call_llm(agent["prompt"], model=llm_model, dry_run=dry_run)
    logger.info("  LLM response (%d chars): %s",
                len(llm_response),
                llm_response[:200].replace("\n", " ") + ("…" if len(llm_response) > 200 else ""))

    # ── Parse proposed file changes from LLM response ────────────────────────
    # Convention: the LLM is expected to list modified/created files in a JSON
    # block tagged  ```json\n{ "files": ["path/a", "path/b"] }\n```
    # In dry-run mode no files are proposed, so we skip both checks.
    proposed_files = _parse_proposed_files(llm_response, logger)
    logger.debug("  Proposed files: %s", proposed_files)

    # ── Scope enforcement ────────────────────────────────────────────────────
    scope_violations = check_scope_violation(
        agent, proposed_files, scope_paths, logger
    )
    allowed_files = [f for f in proposed_files if f not in scope_violations]

    # ── Conflict detection ───────────────────────────────────────────────────
    conflicts = conflict_tracker.claim(agent_name, allowed_files)
    if conflicts:
        for c_entry in conflict_tracker.conflicts:
            if c_entry["second_agent"] == agent_name:
                logger.warning(
                    "  [CONFLICT] '%s' already claimed by '%s'",
                    c_entry["file"],
                    c_entry["first_agent"],
                )

    duration = time.monotonic() - start
    status = "ok" if not scope_violations and not conflicts else "warnings"

    logger.info("  Done in %.2fs  status=%s  violations=%d  conflicts=%d",
                duration, status, len(scope_violations), len(conflicts))

    return {
        "agent": agent_name,
        "status": status,
        "llm_response": llm_response,
        "proposed_files": proposed_files,
        "scope_violations": scope_violations,
        "conflicts": conflicts,
        "duration_s": round(duration, 3),
    }


def _parse_proposed_files(llm_response: str, logger: logging.Logger) -> list[str]:
    """
    Extract the list of files the LLM claims to have modified/created.
    Looks for a JSON block of the form:
        ```json
        { "files": ["path/a", "path/b"] }
        ```
    Returns an empty list if no such block is found.
    """
    import re
    pattern = r"```json\s*(\{.*?\"files\"\s*:.*?\})\s*```"
    match = re.search(pattern, llm_response, re.DOTALL | re.IGNORECASE)
    if not match:
        return []
    try:
        data = json.loads(match.group(1))
        files = data.get("files", [])
        if isinstance(files, list):
            return [str(f) for f in files]
    except json.JSONDecodeError as exc:
        logger.debug("  Could not parse proposed-files JSON: %s", exc)
    return []


# ──────────────────────────────────────────────────────────────────────────────
# 7.  CYCLE RUNNER
# ──────────────────────────────────────────────────────────────────────────────

def run_cycle(
    agents: list[dict[str, Any]],
    repo_root: pathlib.Path,
    logger: logging.Logger,
    dry_run: bool,
    llm_model: str,
    cycle_num: int,
) -> dict[str, Any]:
    """
    Run all agents in run_order sequence.
    Returns a cycle-level summary dictionary.
    """
    logger.info("")
    logger.info("╔══════════════════════════════════════════╗")
    logger.info("║  CYCLE %d  started at %s  ║",
                cycle_num,
                datetime.now(timezone.utc).strftime("%H:%M:%SZ"))
    logger.info("╚══════════════════════════════════════════╝")

    conflict_tracker = ConflictTracker()
    ordered = sorted(agents, key=lambda a: (a["run_order"], a["name"]))

    results: list[dict[str, Any]] = []
    for agent in ordered:
        result = run_agent(
            agent, repo_root, conflict_tracker, logger, dry_run, llm_model
        )
        results.append(result)

    summary = _build_cycle_summary(cycle_num, results, conflict_tracker)
    _print_summary(summary, logger)
    return summary


def _build_cycle_summary(
    cycle_num: int,
    results: list[dict[str, Any]],
    conflict_tracker: ConflictTracker,
) -> dict[str, Any]:
    total_files = sum(len(r["proposed_files"]) for r in results)
    total_violations = sum(len(r["scope_violations"]) for r in results)
    total_conflicts = len(conflict_tracker.conflicts)
    total_duration = sum(r["duration_s"] for r in results)

    return {
        "cycle": cycle_num,
        "timestamp_utc": datetime.now(timezone.utc).isoformat(),
        "agent_results": results,
        "totals": {
            "agents_run": len(results),
            "files_proposed": total_files,
            "scope_violations": total_violations,
            "file_conflicts": total_conflicts,
            "duration_s": round(total_duration, 3),
        },
        "cross_agent_conflicts": conflict_tracker.conflicts,
    }


def _print_summary(summary: dict[str, Any], logger: logging.Logger) -> None:
    t = summary["totals"]
    logger.info("")
    logger.info("┌─ CYCLE %d SUMMARY ─────────────────────────────────────────┐",
                summary["cycle"])
    logger.info("│  Agents run        : %d", t["agents_run"])
    logger.info("│  Files proposed    : %d", t["files_proposed"])
    logger.info("│  Scope violations  : %d", t["scope_violations"])
    logger.info("│  File conflicts    : %d", t["file_conflicts"])
    logger.info("│  Total duration    : %.2fs", t["duration_s"])
    logger.info("│")
    for r in summary["agent_results"]:
        logger.info("│  %-22s  status=%-8s  files=%d  viol=%d  conf=%d",
                    r["agent"], r["status"],
                    len(r["proposed_files"]),
                    len(r["scope_violations"]),
                    len(r["conflicts"]))
    if summary["cross_agent_conflicts"]:
        logger.info("│")
        logger.info("│  ⚠  Cross-agent conflicts:")
        for c in summary["cross_agent_conflicts"]:
            logger.info("│      %s  ← claimed by '%s' then '%s'",
                        c["file"], c["first_agent"], c["second_agent"])
    logger.info("└──────────────────────────────────────────────────────────────┘")


# ──────────────────────────────────────────────────────────────────────────────
# 8.  AGENT REGISTRY LOADER  (supports external JSON config)
# ──────────────────────────────────────────────────────────────────────────────

def load_agents(extra_config: str | None) -> list[dict[str, Any]]:
    """
    Load the default agent registry and optionally merge in agents from an
    external JSON file.  The JSON file must be a list of agent objects with
    at least the keys: name, run_order, scope, prompt.
    """
    agents = list(DEFAULT_AGENTS)  # shallow copy

    if extra_config:
        path = pathlib.Path(extra_config)
        if not path.exists():
            print(f"[WARN] --agent-config file not found: {path}", file=sys.stderr)
            return agents
        with path.open(encoding="utf-8") as fh:
            extra = json.load(fh)
        if not isinstance(extra, list):
            print("[WARN] --agent-config must contain a JSON array.", file=sys.stderr)
            return agents
        existing_names = {a["name"] for a in agents}
        added = 0
        for entry in extra:
            required = {"name", "run_order", "scope", "prompt"}
            missing = required - entry.keys()
            if missing:
                print(f"[WARN] Skipping agent with missing keys: {missing}",
                      file=sys.stderr)
                continue
            if entry["name"] in existing_names:
                print(f"[WARN] Duplicate agent name '{entry['name']}' – skipping.",
                      file=sys.stderr)
                continue
            agents.append(entry)
            existing_names.add(entry["name"])
            added += 1
        print(f"[INFO] Loaded {added} extra agent(s) from {path}")

    return agents


# ──────────────────────────────────────────────────────────────────────────────
# 9.  CLI
# ──────────────────────────────────────────────────────────────────────────────

def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="controller.py",
        description="AIOS Multi-Agent Orchestrator",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples
--------
  # One dry-run cycle (no LLM calls, safe to run any time):
  python3 controller.py --cycles 1 --dry-run

  # Three live cycles using gpt-4o:
  OPENAI_API_KEY=sk-... python3 controller.py --cycles 3 --model gpt-4o

  # Use a custom agent JSON file:
  python3 controller.py --cycles 1 --dry-run --agent-config extra_agents.json

Adding a new agent
------------------
  Option A – edit DEFAULT_AGENTS in this file and add a new dict entry.
  Option B – create a JSON file:
    [
      {
        "name":      "Security Agent",
        "run_order": 6,
        "scope":     ["security", ".github/workflows"],
        "prompt":    "You are the Security Agent …"
      }
    ]
  Then run: python3 controller.py --agent-config my_agents.json
""",
    )
    parser.add_argument(
        "--cycles", type=int, default=1, metavar="N",
        help="Number of improvement cycles to run (default: 1).",
    )
    parser.add_argument(
        "--dry-run", action="store_true",
        help="Skip real LLM calls; print what would happen.",
    )
    parser.add_argument(
        "--model", default="gpt-4o", metavar="MODEL",
        help="OpenAI model name (default: gpt-4o).",
    )
    parser.add_argument(
        "--agent-config", metavar="FILE",
        help="Path to a JSON file containing extra agent definitions.",
    )
    parser.add_argument(
        "--log-dir", default="logs", metavar="DIR",
        help="Directory for log files (default: logs/).",
    )
    parser.add_argument(
        "--repo-root", default=".", metavar="DIR",
        help="Path to the repository root (default: current directory).",
    )
    return parser


# ──────────────────────────────────────────────────────────────────────────────
# 10.  MAIN ENTRY POINT
# ──────────────────────────────────────────────────────────────────────────────

def main() -> None:
    args = build_parser().parse_args()

    repo_root = pathlib.Path(args.repo_root).resolve()
    log_dir = pathlib.Path(args.log_dir)
    logger = setup_logger(log_dir)

    logger.info("AIOS Controller starting")
    logger.info("  Repository root : %s", repo_root)
    logger.info("  Cycles          : %d", args.cycles)
    logger.info("  Dry-run         : %s", args.dry_run)
    logger.info("  LLM model       : %s", args.model)

    agents = load_agents(args.agent_config)
    logger.info("  Agents loaded   : %d", len(agents))
    for a in sorted(agents, key=lambda x: x["run_order"]):
        logger.info("    [%d] %s  scope=%s", a["run_order"], a["name"], a["scope"])

    all_summaries: list[dict[str, Any]] = []

    for cycle_num in range(1, args.cycles + 1):
        summary = run_cycle(
            agents=agents,
            repo_root=repo_root,
            logger=logger,
            dry_run=args.dry_run,
            llm_model=args.model,
            cycle_num=cycle_num,
        )
        all_summaries.append(summary)

        # Persist the summary JSON next to the log file
        timestamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
        summary_path = log_dir / f"cycle_{cycle_num}_{timestamp}.json"
        with summary_path.open("w", encoding="utf-8") as fh:
            json.dump(summary, fh, indent=2)
        logger.info("Cycle %d summary saved to %s", cycle_num, summary_path)

    logger.info("")
    logger.info("All %d cycle(s) complete.", args.cycles)


if __name__ == "__main__":
    main()


# ──────────────────────────────────────────────────────────────────────────────
# ADDING A NEW AGENT  (developer reference)
# ──────────────────────────────────────────────────────────────────────────────
# 1. Open this file and locate DEFAULT_AGENTS.
# 2. Append a new dict to the list:
#
#    {
#        "name":       "Security Agent",       # unique display name
#        "run_order":  6,                       # where in the sequence it runs
#        "scope":      ["security", ".github"], # dirs/files it may touch
#        "scope_notes": "Brief human description of what it owns.",
#        "prompt": (
#            "You are the Security Agent. Your scope is security/ and "
#            ".github/. Review for vulnerabilities and harden configs."
#        ),
#    },
#
# 3. Save and run:  python3 controller.py --cycles 1 --dry-run
#
# Alternatively supply --agent-config pointing to a JSON array of agents;
# no changes to this source file required.
#
# ──────────────────────────────────────────────────────────────────────────────
# EXAMPLE LOG OUTPUT (dry-run)
# ──────────────────────────────────────────────────────────────────────────────
#
# 2026-04-04T13:41:05Z  INFO      Log file: logs/controller_20260404T134105Z.log
# 2026-04-04T13:41:05Z  INFO      AIOS Controller starting
# 2026-04-04T13:41:05Z  INFO        Repository root : /home/user/PROJECT
# 2026-04-04T13:41:05Z  INFO        Cycles          : 1
# 2026-04-04T13:41:05Z  INFO        Dry-run         : True
# 2026-04-04T13:41:05Z  INFO        LLM model       : gpt-4o
# 2026-04-04T13:41:05Z  INFO        Agents loaded   : 5
# 2026-04-04T13:41:05Z  INFO          [1] Architect Agent   scope=['.']
# 2026-04-04T13:41:05Z  INFO          [2] Core Engine Agent scope=['bin', 'OS']
# 2026-04-04T13:41:05Z  INFO          [3] AI Shell Agent    scope=['ai']
# 2026-04-04T13:41:05Z  INFO          [4] DevOps Agent      scope=['scripts', ...]
# 2026-04-04T13:41:05Z  INFO          [5] Docs Agent        scope=['README.md', ...]
# 2026-04-04T13:41:05Z  INFO
# 2026-04-04T13:41:05Z  INFO      ╔══════════════════════════════════════════╗
# 2026-04-04T13:41:05Z  INFO      ║  CYCLE 1  started at 13:41:05Z  ║
# 2026-04-04T13:41:05Z  INFO      ╚══════════════════════════════════════════╝
# 2026-04-04T13:41:05Z  INFO      ══ Starting: Architect Agent
# 2026-04-04T13:41:05Z  INFO        LLM response (52 chars): [DRY-RUN] Would send prompt …
# 2026-04-04T13:41:05Z  INFO        Done in 0.00s  status=ok  violations=0  conflicts=0
# ...
# 2026-04-04T13:41:05Z  INFO      ┌─ CYCLE 1 SUMMARY ──────────────────────────┐
# 2026-04-04T13:41:05Z  INFO      │  Agents run        : 5
# 2026-04-04T13:41:05Z  INFO      │  Files proposed    : 0
# 2026-04-04T13:41:05Z  INFO      │  Scope violations  : 0
# 2026-04-04T13:41:05Z  INFO      │  File conflicts    : 0
# 2026-04-04T13:41:05Z  INFO      │  Total duration    : 0.01s
# 2026-04-04T13:41:05Z  INFO      └────────────────────────────────────────────┘
# 2026-04-04T13:41:05Z  INFO      All 1 cycle(s) complete.
