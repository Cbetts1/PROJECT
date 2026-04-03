#!/usr/bin/env python3
"""tests/test_python_modules.py — Unit tests for AIOS Python AI Core modules.

Tests:
  - intent_engine.py: classify() returns correct IntentType and sub_intent
  - router.py:        Router instantiates, dispatches CHAT without crashing
  - bots.py:          BotRunner lists bots; HealthBot/LogBot/RepairBot run

Run:
    python3 tests/test_python_modules.py
or via unit-tests.sh:
    AIOS_HOME=$(pwd) OS_ROOT=$(pwd)/OS bash tests/unit-tests.sh
"""
import os
import sys
import tempfile

# ---------------------------------------------------------------------------
# Path setup — ensure ai/core is importable
# ---------------------------------------------------------------------------
_REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
_AI_CORE   = os.path.join(_REPO_ROOT, "ai", "core")
sys.path.insert(0, _AI_CORE)

PASS = 0
FAIL = 0


def ok(label: str) -> None:
    global PASS
    PASS += 1
    print(f"[PASS] {label}")


def fail(label: str, detail: str = "") -> None:
    global FAIL
    FAIL += 1
    msg = f"[FAIL] {label}"
    if detail:
        msg += f" — {detail}"
    print(msg)


# ===========================================================================
# intent_engine tests
# ===========================================================================
print("\n=== intent_engine tests ===")

from intent_engine import classify, IntentType  # noqa: E402


def _check(label: str, text: str, expected_type: IntentType, expected_sub: str = "") -> None:
    intent = classify(text)
    if intent.type != expected_type:
        fail(label, f"type={intent.type!r}, want {expected_type!r}")
        return
    if expected_sub and intent.sub_intent != expected_sub:
        fail(label, f"sub_intent={intent.sub_intent!r}, want {expected_sub!r}")
        return
    ok(label)


_check("intent: ls → COMMAND fs.ls",               "ls /etc",              IntentType.COMMAND,  "fs.ls")
_check("intent: list → COMMAND fs.ls",             "list /var/log",        IntentType.COMMAND,  "fs.ls")
_check("intent: cat → COMMAND fs.cat",             "cat /etc/os-release",  IntentType.COMMAND,  "fs.cat")
_check("intent: mkdir → COMMAND fs.mkdir",         "mkdir /tmp/test",      IntentType.COMMAND,  "fs.mkdir")
_check("intent: rm → COMMAND fs.rm",               "rm /tmp/test",         IntentType.COMMAND,  "fs.rm")
_check("intent: ps → COMMAND proc.ps",             "ps",                   IntentType.COMMAND,  "proc.ps")
_check("intent: kill → COMMAND proc.kill",         "kill 1234",            IntentType.COMMAND,  "proc.kill")
_check("intent: ping → COMMAND net.ping",          "ping 8.8.8.8",         IntentType.COMMAND,  "net.ping")
_check("intent: status → QUERY sys.status",        "status",               IntentType.QUERY,    "sys.status")
_check("intent: health → QUERY sys.health",        "health",               IntentType.QUERY,    "sys.health")
_check("intent: sysinfo → QUERY sys.sysinfo",      "sysinfo",              IntentType.QUERY,    "sys.sysinfo")
_check("intent: uptime → QUERY sys.uptime",        "uptime",               IntentType.QUERY,    "sys.uptime")
_check("intent: start svc → ACTION svc.start",     "start nginx",          IntentType.ACTION,   "svc.start")
_check("intent: stop svc → ACTION svc.stop",       "stop nginx",           IntentType.ACTION,   "svc.stop")
_check("intent: restart → ACTION svc.restart",     "restart nginx",        IntentType.ACTION,   "svc.restart")
_check("intent: fix → REPAIR repair.auto",         "fix the broken service", IntentType.REPAIR, "repair.auto")
_check("intent: error → REPAIR repair.auto",       "there is an error",    IntentType.REPAIR,   "repair.auto")
_check("intent: deploy → WORKFLOW",                "deploy the app",       IntentType.WORKFLOW, "workflow.run")
_check("intent: chat fallback",                    "hello there",          IntentType.CHAT,     "")

# Confidence is between 0 and 1
i = classify("ls /etc")
if 0.0 <= i.confidence <= 1.0:
    ok("intent: confidence in [0, 1]")
else:
    fail("intent: confidence out of range", str(i.confidence))

# Entities are extracted
i = classify("cat /etc/os-release")
if i.entities.get("path") == "/etc/os-release":
    ok("intent: entity extraction (path)")
else:
    fail("intent: entity extraction", f"entities={i.entities}")

# JSON output path (CLI mode)
import subprocess  # noqa: E402
import json  # noqa: E402
res = subprocess.run(
    [sys.executable, os.path.join(_AI_CORE, "intent_engine.py"),
     "--input", "ls /tmp", "--json"],
    capture_output=True, text=True
)
if res.returncode == 0:
    data = json.loads(res.stdout)
    if data.get("type") == "command" and data.get("sub_intent") == "fs.ls":
        ok("intent_engine: CLI --json output correct")
    else:
        fail("intent_engine: CLI --json output wrong", str(data))
else:
    fail("intent_engine: CLI --json failed", res.stderr[:200])


# ===========================================================================
# router tests
# ===========================================================================
print("\n=== router tests ===")

from router import Router, RouterContext, IntentType as _IT  # noqa: E402
from intent_engine import Intent, IntentType as ITE           # noqa: E402

# Router instantiates without error
try:
    ctx = RouterContext(os_root="", aios_root="")
    r = Router(ctx)
    ok("router: instantiation")
except Exception as exc:
    fail("router: instantiation", str(exc))

# CHAT dispatch does not raise
try:
    resp = r.route("hello there")
    if resp.intent_type == "chat":
        ok("router: CHAT dispatch sets intent_type")
    else:
        fail("router: CHAT dispatch intent_type wrong", resp.intent_type)
    if resp.output:
        ok("router: CHAT dispatch returns non-empty output")
    else:
        fail("router: CHAT dispatch returned empty output")
except Exception as exc:
    fail("router: CHAT dispatch raised", str(exc))

# Custom handler override
custom_called = []

def _custom_handler(intent, ctx):
    from router import SubsystemResponse
    custom_called.append(intent.raw)
    return SubsystemResponse(success=True, output="custom", subsystem="test")

r.register(ITE.QUERY, _custom_handler)
try:
    resp = r.route("status")
    if custom_called and resp.output == "custom":
        ok("router: register() overrides handler")
    else:
        fail("router: register() override not called", str(resp))
except Exception as exc:
    fail("router: register() raised", str(exc))


# ===========================================================================
# bots tests
# ===========================================================================
print("\n=== bots tests ===")

from bots import BotRunner, HealthBot, LogBot, RepairBot, BaseBot  # noqa: E402

# BotRunner.list_bots() returns at least the three built-in bots
listed = BotRunner.list_bots()
names  = [l.split(":")[0] for l in listed]
for expected in ("health", "log", "repair"):
    if expected in names:
        ok(f"bots: {expected} bot registered")
    else:
        fail(f"bots: {expected} bot not in registry", str(names))

# Use a temp dir as OS_ROOT so bots don't touch the real tree
with tempfile.TemporaryDirectory() as tmpdir:
    os.makedirs(os.path.join(tmpdir, "var", "log"), exist_ok=True)
    os.makedirs(os.path.join(tmpdir, "var", "service"), exist_ok=True)

    runner = BotRunner(os_root=tmpdir, aios_root=_REPO_ROOT)

    # HealthBot — no PID files → all healthy
    res = runner.run("health")
    if res.success:
        ok("bots: HealthBot runs successfully (no services)")
    else:
        fail("bots: HealthBot unexpected failure", res.message)

    # HealthBot — dead PID file detected
    with open(os.path.join(tmpdir, "var", "service", "fake-svc.pid"), "w") as f:
        f.write("99999999\n")
    res = runner.run("health")
    if not res.success and any("fake-svc" in a for a in res.actions_taken):
        ok("bots: HealthBot detects dead service")
    else:
        fail("bots: HealthBot did not detect dead service", str(res))

    # LogBot — no rotation needed (empty logs)
    res = runner.run("log")
    if res.success:
        ok("bots: LogBot runs on empty log dir")
    else:
        fail("bots: LogBot failed on empty log dir", res.message)

    # LogBot — rotation triggered
    big_log = os.path.join(tmpdir, "var", "log", "os.log")
    with open(big_log, "w") as f:
        for i in range(1100):
            f.write(f"line {i}\n")
    res = runner.run("log")
    if res.success and any("rotated" in a for a in res.actions_taken):
        ok("bots: LogBot rotates large log file")
    else:
        fail("bots: LogBot did not rotate large log file", str(res))

    # RepairBot — no errors in empty log
    aura_log = os.path.join(tmpdir, "var", "log", "aura.log")
    open(aura_log, "w").close()
    res = runner.run("repair")
    if res.success:
        ok("bots: RepairBot finds no errors in empty log")
    else:
        fail("bots: RepairBot unexpected failure on empty log", res.message)

    # RepairBot — detects ERROR in log
    with open(aura_log, "w") as f:
        f.write("[2026-01-01T00:00:00Z] [kernel] ERROR: dead service: fake-svc (pid=99)\n")
    res = runner.run("repair")
    if not res.success and res.actions_taken:
        ok("bots: RepairBot detects errors and generates actions")
    else:
        fail("bots: RepairBot did not detect seeded error", str(res))

# Custom bot registration
class _TestBot(BaseBot):
    name = "testbot"
    description = "Test-only bot."
    def run_once(self):
        from bots import BotResult
        return BotResult(bot_name=self.name, success=True, message="ok")

if "testbot" in BaseBot._registry:
    ok("bots: custom BaseBot subclass auto-registered")
else:
    fail("bots: custom BaseBot subclass not auto-registered")


# ===========================================================================
# Summary
# ===========================================================================
print()
print("=" * 40)
print(f"Results: {PASS} passed, {FAIL} failed")
if FAIL > 0:
    sys.exit(1)
print("All tests passed.")
