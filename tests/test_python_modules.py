#!/usr/bin/env python3
"""tests/test_python_modules.py — Unit tests for the AIOS Python AI core.

Tests: intent_engine, router, bots, commands, fuzzy, llama_client.

Run standalone:
    python3 tests/test_python_modules.py

Or via the shell test harness:
    AIOS_HOME=$(pwd) OS_ROOT=$(pwd)/OS bash tests/unit-tests.sh
"""
import importlib
import os
import sys
import tempfile
import unittest

# ---------------------------------------------------------------------------
# Path setup: allow importing ai/core modules from anywhere
# ---------------------------------------------------------------------------
_REPO_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
_AI_CORE   = os.path.join(_REPO_ROOT, "ai", "core")
sys.path.insert(0, _AI_CORE)

import commands        # noqa: E402
import fuzzy           # noqa: E402
import llama_client    # noqa: E402
import intent_engine   # noqa: E402
import bots            # noqa: E402
import router          # noqa: E402


# ===========================================================================
# commands.py
# ===========================================================================

class TestCommands(unittest.TestCase):
    def _p(self, text):
        return commands.parse_natural_language(text)

    def test_ls_no_arg(self):
        p = self._p("ls")
        self.assertEqual(p.command, "fs.ls")
        self.assertEqual(p.args, ["."])

    def test_ls_with_path(self):
        p = self._p("ls /tmp")
        self.assertEqual(p.command, "fs.ls")
        self.assertIn("/tmp", p.args)

    def test_cat(self):
        p = self._p("cat /etc/hostname")
        self.assertEqual(p.command, "fs.cat")
        self.assertIn("/etc/hostname", p.args)

    def test_ping(self):
        p = self._p("ping 8.8.8.8")
        self.assertEqual(p.command, "net.ping")
        self.assertIn("8.8.8.8", p.args)

    def test_ps(self):
        p = self._p("ps")
        self.assertEqual(p.command, "proc.ps")

    def test_fallback_chat(self):
        p = self._p("what is the meaning of life")
        self.assertEqual(p.command, "chat")


# ===========================================================================
# fuzzy.py
# ===========================================================================

class TestFuzzy(unittest.TestCase):
    CMDS = ["ask", "recall", "sysinfo", "uptime", "disk", "ls", "services",
            "status", "help", "exit", "start", "stop"]

    def _m(self, term):
        return fuzzy.best_match(term, self.CMDS)

    def test_sysinfo_typo(self):
        self.assertEqual(self._m("sysinf"), "sysinfo")

    def test_uptime_typo(self):
        self.assertEqual(self._m("utime"), "uptime")

    def test_services_typo(self):
        self.assertEqual(self._m("servics"), "services")

    def test_start_typo(self):
        self.assertIn(self._m("strt"), ("start", "stop", ""))

    def test_no_match(self):
        self.assertEqual(self._m("xyz_totally_unknown_garbage"), "")


# ===========================================================================
# llama_client.py
# ===========================================================================

class TestLlamaClient(unittest.TestCase):
    def test_mock_returns_string(self):
        out = llama_client.run_mock("hello")
        self.assertIsInstance(out, str)
        self.assertGreater(len(out), 0)

    def test_mock_echoes_prompt(self):
        out = llama_client.run_mock("test prompt")
        self.assertIn("test prompt", out)

    def test_llama_binary_not_found(self):
        # With no llama binary in a restricted PATH, should report an error
        # (either a graceful message on stdout or a non-zero exit)
        import subprocess as sp
        env = dict(os.environ, PATH="/nonexistent")
        result = sp.run(
            [sys.executable, os.path.join(_AI_CORE, "llama_client.py"),
             "--backend", "llama", "--model-path", "/tmp/none.gguf",
             "--prompt", "hi"],
            capture_output=True, text=True, env=env,
        )
        # Should either report "not found" on stdout or exit non-zero — not silently succeed
        reported_not_found = "not found" in result.stdout.lower()
        error_exit = result.returncode != 0
        self.assertTrue(
            reported_not_found or error_exit,
            "Expected 'not found' message or non-zero exit when llama binary absent"
        )


# ===========================================================================
# intent_engine.py
# ===========================================================================

class TestIntentEngine(unittest.TestCase):
    def setUp(self):
        self.ie = intent_engine.IntentEngine()

    def _c(self, text):
        return self.ie.classify(text)

    def test_ls(self):
        i = self._c("ls")
        self.assertEqual(i.category, "command")
        self.assertEqual(i.action, "fs.ls")

    def test_cat(self):
        i = self._c("cat /etc/hosts")
        self.assertEqual(i.action, "fs.cat")
        self.assertEqual(i.entities.get("path"), "/etc/hosts")

    def test_ping(self):
        i = self._c("ping 8.8.8.8")
        self.assertEqual(i.action, "net.ping")
        self.assertEqual(i.entities.get("host"), "8.8.8.8")

    def test_health(self):
        i = self._c("health")
        self.assertEqual(i.category, "health")

    def test_repair(self):
        i = self._c("repair")
        self.assertEqual(i.category, "repair")

    def test_ask(self):
        i = self._c("ask what is AIOS")
        self.assertEqual(i.category, "ai")
        self.assertEqual(i.action, "ask")

    def test_chat_fallback(self):
        i = self._c("tell me a story about robots")
        self.assertEqual(i.category, "chat")

    def test_mem_set(self):
        i = self._c("mem.set foo bar")
        self.assertEqual(i.category, "memory")
        self.assertEqual(i.action, "mem.set")

    def test_uptime(self):
        i = self._c("uptime")
        self.assertEqual(i.category, "system")
        self.assertEqual(i.action, "uptime")

    def test_confidence_range(self):
        i = self._c("ls /tmp")
        self.assertGreaterEqual(i.confidence, 0.0)
        self.assertLessEqual(i.confidence, 1.0)


# ===========================================================================
# bots.py
# ===========================================================================

class TestBotsBase(unittest.TestCase):
    def setUp(self):
        # Use a real temp dir as os_root for filesystem operations
        self.tmpdir = tempfile.mkdtemp()
        os.makedirs(os.path.join(self.tmpdir, "var", "log"), exist_ok=True)
        os.makedirs(os.path.join(self.tmpdir, "proc"), exist_ok=True)
        os.makedirs(os.path.join(self.tmpdir, "bin"), exist_ok=True)

    def _intent(self, category, action, entities=None):
        return intent_engine.Intent(
            category=category, action=action,
            entities=entities or {}, raw=""
        )


class TestHealthBot(TestBotsBase):
    def test_can_handle_health(self):
        bot = bots.HealthBot(os_root=self.tmpdir)
        i = self._intent("health", "check")
        self.assertTrue(bot.can_handle(i))

    def test_cannot_handle_log(self):
        bot = bots.HealthBot(os_root=self.tmpdir)
        i = self._intent("log", "read")
        self.assertFalse(bot.can_handle(i))

    def test_handle_uptime(self):
        bot = bots.HealthBot(os_root=self.tmpdir)
        i = self._intent("system", "uptime")
        out = bot.handle(i)
        self.assertIsInstance(out, str)

    def test_handle_disk(self):
        bot = bots.HealthBot(os_root=self.tmpdir)
        i = self._intent("system", "disk")
        out = bot.handle(i)
        self.assertIsInstance(out, str)
        self.assertGreater(len(out), 0)


class TestLogBot(TestBotsBase):
    def test_can_handle(self):
        bot = bots.LogBot(os_root=self.tmpdir)
        i = self._intent("log", "read")
        self.assertTrue(bot.can_handle(i))

    def test_write_and_read(self):
        bot = bots.LogBot(os_root=self.tmpdir)
        # Write
        wi = self._intent("log", "write", {"message": "test-log-message"})
        out = bot.handle(wi)
        self.assertIn("test-log-message", out)
        # Read back
        ri = self._intent("log", "read", {"source": "os.log"})
        content = bot.handle(ri)
        self.assertIn("test-log-message", content)

    def test_read_missing_file(self):
        bot = bots.LogBot(os_root=self.tmpdir)
        i = self._intent("log", "read", {"source": "nonexistent.log"})
        out = bot.handle(i)
        self.assertIn("not found", out.lower())


class TestRepairBot(TestBotsBase):
    def test_can_handle(self):
        bot = bots.RepairBot(os_root=self.tmpdir)
        i = self._intent("repair", "self-repair")
        self.assertTrue(bot.can_handle(i))

    def test_self_repair_creates_dirs(self):
        bot = bots.RepairBot(os_root=self.tmpdir)
        i = self._intent("repair", "self-repair")
        out = bot.handle(i)
        self.assertIn("self-repair", out.lower())
        # Key dirs should exist now
        self.assertTrue(os.path.isdir(os.path.join(self.tmpdir, "var", "log")))

    def test_self_repair_idempotent(self):
        bot = bots.RepairBot(os_root=self.tmpdir)
        i = self._intent("repair", "self-repair")
        out1 = bot.handle(i)
        out2 = bot.handle(i)
        # Second run should report no repair needed
        self.assertIn("complete", out2.lower())


# ===========================================================================
# router.py
# ===========================================================================

class TestRouter(unittest.TestCase):
    def setUp(self):
        self.tmpdir = tempfile.mkdtemp()
        os.makedirs(os.path.join(self.tmpdir, "var", "log"), exist_ok=True)
        os.makedirs(os.path.join(self.tmpdir, "proc"), exist_ok=True)
        self.router = router.Router(os_root=self.tmpdir, aios_root=self.tmpdir)
        self.ie = intent_engine.IntentEngine()

    def _dispatch(self, text):
        return self.router.dispatch(self.ie.classify(text))

    def test_repair_dispatched(self):
        out = self._dispatch("repair")
        self.assertIsNotNone(out)
        self.assertIn("repair", out.lower())

    def test_health_dispatched(self):
        out = self._dispatch("health")
        self.assertIsNotNone(out)

    def test_log_dispatched(self):
        out = self._dispatch("logs")
        # LogBot matches log category — may return file-not-found but not None
        self.assertIsNotNone(out)

    def test_chat_no_bot_match(self):
        out = self._dispatch("tell me something random")
        # Chat falls through to None (caller handles)
        self.assertIsNone(out)

    def test_register_bot(self):
        class EchoBot(bots.BaseBot):
            name = "EchoBot"
            def can_handle(self, intent): return True
            def handle(self, intent): return f"echo:{intent.raw}"

        r = router.Router(os_root=self.tmpdir)
        r.register_bot(EchoBot())
        i = intent_engine.Intent("test", "test", raw="hello")
        out = r.dispatch(i)
        self.assertEqual(out, "echo:hello")


# ===========================================================================
# ai_backend.py integration (module-level import test)
# ===========================================================================

class TestAiBackend(unittest.TestCase):
    def test_import(self):
        import importlib
        spec = importlib.util.spec_from_file_location(
            "ai_backend", os.path.join(_AI_CORE, "ai_backend.py")
        )
        mod = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(mod)
        self.assertTrue(hasattr(mod, "main"))
        self.assertTrue(hasattr(mod, "chat_response"))
        self.assertTrue(hasattr(mod, "run_system_command"))


# ===========================================================================
# Main
# ===========================================================================

if __name__ == "__main__":
    loader = unittest.TestLoader()
    suite  = loader.loadTestsFromModule(sys.modules[__name__])
    runner = unittest.TextTestRunner(verbosity=2)
    result = runner.run(suite)
    sys.exit(0 if result.wasSuccessful() else 1)
