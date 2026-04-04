#!/usr/bin/env python3
"""tests/test_python_modules.py — Unit tests for the AIOS Python AI core.

Tests: intent_engine, router, bots, commands, fuzzy, llama_client.

Run standalone:
    python3 tests/test_python_modules.py

Or via the shell test harness:
    AIOS_HOME=$(pwd) OS_ROOT=$(pwd)/OS bash tests/unit-tests.sh
"""
import importlib
import importlib.util
import os
import shutil
import sys
import tempfile
import unittest
import unittest.mock

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

# Path to the filesystem module (OS/lib/filesystem.py)
_FS_PY = os.path.join(_REPO_ROOT, "OS", "lib", "filesystem.py")


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

    def test_mock_includes_prompt_in_fallback(self):
        # Unrecognised input → default fallback should include the original text
        out = llama_client.run_mock("test prompt")
        self.assertIn("test prompt", out)

    def test_mock_greeting_response(self):
        out = llama_client.run_mock("hello")
        self.assertIn("AURA", out)
        self.assertGreater(len(out), 30)

    def test_mock_help_response(self):
        out = llama_client.run_mock("help")
        self.assertIn("ls", out)

    def test_mock_model_guidance(self):
        out = llama_client.run_mock("how do I set up the llm model")
        self.assertIn("gguf", out.lower())

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
# llama_client.py — extended coverage
# ===========================================================================

class TestLlamaClientExtended(unittest.TestCase):
    """Additional coverage for run_mock variants, streaming, and binary search."""

    def test_run_mock_how_to_install(self):
        out = llama_client.run_mock("how do I install AIOS")
        self.assertIn("install.sh", out)

    def test_run_mock_how_to_use(self):
        out = llama_client.run_mock("how do I use this")
        self.assertIn("commands", out.lower())

    def test_run_mock_how_bridge(self):
        out = llama_client.run_mock("how to bridge android")
        self.assertIn("bridge", out.lower())

    def test_run_mock_what_is_aios(self):
        out = llama_client.run_mock("what is AIOS")
        self.assertIn("operating system", out.lower())

    def test_run_mock_what_is_aura(self):
        out = llama_client.run_mock("what is AURA")
        self.assertIn("cognitive", out.lower())

    def test_run_mock_what_commands(self):
        out = llama_client.run_mock("what commands are there")
        self.assertIn("ls", out)

    def test_run_mock_install_topic(self):
        out = llama_client.run_mock("install AIOS")
        self.assertIn("install", out.lower())

    def test_run_mock_model_topic(self):
        out = llama_client.run_mock("how do I set up the gguf model")
        self.assertIn("gguf", out.lower())

    def test_stream_mock_yields_lines(self):
        chunks = list(llama_client.stream_mock("hello"))
        self.assertGreater(len(chunks), 0)
        full = "".join(chunks)
        self.assertIn("AURA", full)

    def test_stream_mock_help_content(self):
        chunks = list(llama_client.stream_mock("help"))
        full = "".join(chunks)
        self.assertIn("ls", full)

    def test_stream_mock_ends_with_newline(self):
        chunks = list(llama_client.stream_mock("hello"))
        full = "".join(chunks)
        self.assertTrue(full.endswith("\n"))

    def test_run_llama_no_binary(self):
        with unittest.mock.patch("llama_client._find_llama_bin", return_value=None):
            out = llama_client.run_llama("/fake/model.gguf", 4096, 4, "hello")
        self.assertIn("not found", out.lower())

    def test_stream_llama_no_binary(self):
        with unittest.mock.patch("llama_client._find_llama_bin", return_value=None):
            chunks = list(llama_client.stream_llama("/fake/model.gguf", 4096, 4, "hello"))
        full = "".join(chunks)
        self.assertIn("not found", full.lower())

    def test_find_llama_bin_returns_none_or_str(self):
        result = llama_client._find_llama_bin()
        self.assertTrue(result is None or isinstance(result, str))


# ===========================================================================
# bots.py — BaseBot helpers and extended bot tests
# ===========================================================================

class TestBaseBotHelpers(TestBotsBase):
    """Tests for BaseBot utility methods."""

    def test_log_path_default(self):
        bot = bots.BaseBot(os_root=self.tmpdir)
        expected = os.path.join(self.tmpdir, "var", "log", "os.log")
        self.assertEqual(bot._log_path(), expected)

    def test_log_path_named(self):
        bot = bots.BaseBot(os_root=self.tmpdir)
        expected = os.path.join(self.tmpdir, "var", "log", "aura.log")
        self.assertEqual(bot._log_path("aura.log"), expected)

    def test_read_file_existing(self):
        bot = bots.BaseBot(os_root=self.tmpdir)
        path = os.path.join(self.tmpdir, "var", "log", "test.log")
        with open(path, "w") as fh:
            fh.write("line1\nline2\nline3\n")
        out = bot._read_file("var/log/test.log")
        self.assertIn("line1", out)
        self.assertIn("line3", out)

    def test_read_file_max_lines(self):
        bot = bots.BaseBot(os_root=self.tmpdir)
        path = os.path.join(self.tmpdir, "var", "log", "big.log")
        with open(path, "w") as fh:
            for i in range(100):
                fh.write(f"line{i}\n")
        out = bot._read_file("var/log/big.log", max_lines=5)
        lines = out.strip().split("\n")
        self.assertLessEqual(len(lines), 5)

    def test_read_file_missing(self):
        bot = bots.BaseBot(os_root=self.tmpdir)
        out = bot._read_file("var/log/nonexistent.log")
        self.assertIn("not found", out.lower())

    def test_run_valid_command(self):
        bot = bots.BaseBot(os_root=self.tmpdir)
        out = bot._run(["echo", "hello-from-bot"])
        self.assertIn("hello-from-bot", out)

    def test_run_invalid_command(self):
        bot = bots.BaseBot(os_root=self.tmpdir)
        out = bot._run(["/nonexistent/binary/xyz_aios"])
        self.assertIn("failed", out.lower())

    def test_can_handle_base_returns_false(self):
        bot = bots.BaseBot(os_root=self.tmpdir)
        i = self._intent("anything", "any_action")
        self.assertFalse(bot.can_handle(i))


class TestHealthBotExtended(TestBotsBase):
    """Extended HealthBot coverage."""

    def test_can_handle_system_category(self):
        bot = bots.HealthBot(os_root=self.tmpdir)
        i = self._intent("system", "uptime")
        self.assertTrue(bot.can_handle(i))

    def test_can_handle_sysinfo_action(self):
        bot = bots.HealthBot(os_root=self.tmpdir)
        i = self._intent("command", "sysinfo")
        self.assertTrue(bot.can_handle(i))

    def test_can_handle_services_action(self):
        bot = bots.HealthBot(os_root=self.tmpdir)
        i = self._intent("system", "services")
        self.assertTrue(bot.can_handle(i))

    def test_handle_services_no_binary(self):
        bot = bots.HealthBot(os_root=self.tmpdir)
        i = self._intent("system", "services")
        out = bot.handle(i)
        self.assertIsInstance(out, str)
        self.assertGreater(len(out), 0)

    def test_full_status_includes_section_header(self):
        bot = bots.HealthBot(os_root=self.tmpdir)
        i = self._intent("health", "check")
        out = bot.handle(i)
        self.assertIn("HealthBot", out)

    def test_full_status_includes_os_state(self):
        state_file = os.path.join(self.tmpdir, "proc", "os.state")
        with open(state_file, "w") as fh:
            fh.write("kernel_pid=42\nos_version=1.0\n")
        bot = bots.HealthBot(os_root=self.tmpdir)
        i = self._intent("health", "status")
        out = bot.handle(i)
        self.assertIn("kernel_pid", out)


class TestLogBotExtended(TestBotsBase):
    """Extended LogBot coverage."""

    def test_write_empty_message(self):
        bot = bots.LogBot(os_root=self.tmpdir)
        i = self._intent("log", "write", {"message": ""})
        out = bot.handle(i)
        self.assertIn("Logged", out)

    def test_read_with_log_prefix_in_source(self):
        bot = bots.LogBot(os_root=self.tmpdir)
        wi = self._intent("log", "write", {"message": "prefix-strip-test"})
        bot.handle(wi)
        ri = self._intent("log", "read", {"source": "log os.log"})
        out = bot.handle(ri)
        self.assertIn("prefix-strip-test", out)

    def test_multiple_writes_accumulate(self):
        bot = bots.LogBot(os_root=self.tmpdir)
        for msg in ["first-entry", "second-entry", "third-entry"]:
            i = self._intent("log", "write", {"message": msg})
            bot.handle(i)
        ri = self._intent("log", "read", {"source": "os.log"})
        content = bot.handle(ri)
        self.assertIn("first-entry", content)
        self.assertIn("second-entry", content)
        self.assertIn("third-entry", content)

    def test_read_default_source(self):
        bot = bots.LogBot(os_root=self.tmpdir)
        wi = self._intent("log", "write", {"message": "default-source-msg"})
        bot.handle(wi)
        ri = self._intent("log", "read", {})
        out = bot.handle(ri)
        self.assertIn("default-source-msg", out)

    def test_cannot_handle_health(self):
        bot = bots.LogBot(os_root=self.tmpdir)
        i = self._intent("health", "check")
        self.assertFalse(bot.can_handle(i))


class TestRepairBotExtended(TestBotsBase):
    """Extended RepairBot coverage."""

    def test_reinstall_without_install_sh(self):
        bot = bots.RepairBot(os_root=self.tmpdir)
        i = self._intent("repair", "reinstall", {"target": "all"})
        out = bot.handle(i)
        self.assertIn("install.sh not found", out)

    def test_self_repair_creates_required_files(self):
        repair_bot_test_dir = tempfile.mkdtemp()
        os.makedirs(os.path.join(repair_bot_test_dir, "var", "log"), exist_ok=True)
        try:
            bot = bots.RepairBot(os_root=repair_bot_test_dir)
            i = self._intent("repair", "self-repair")
            bot.handle(i)
            self.assertTrue(os.path.isfile(os.path.join(repair_bot_test_dir, "var", "log", "os.log")))
            self.assertTrue(os.path.isfile(os.path.join(repair_bot_test_dir, "var", "log", "aura.log")))
        finally:
            shutil.rmtree(repair_bot_test_dir, ignore_errors=True)

    def test_self_repair_reports_repaired_count(self):
        repair_test_dir = tempfile.mkdtemp()
        try:
            bot = bots.RepairBot(os_root=repair_test_dir)
            i = self._intent("repair", "self-repair")
            out = bot.handle(i)
            self.assertIn("Repaired", out)
        finally:
            shutil.rmtree(repair_test_dir, ignore_errors=True)

    def test_cannot_handle_log(self):
        bot = bots.RepairBot(os_root=self.tmpdir)
        i = self._intent("log", "write")
        self.assertFalse(bot.can_handle(i))


# ===========================================================================
# router.py — extended coverage
# ===========================================================================

class TestRouterExtended(unittest.TestCase):
    def setUp(self):
        self.tmpdir = tempfile.mkdtemp()
        os.makedirs(os.path.join(self.tmpdir, "var", "log"), exist_ok=True)
        os.makedirs(os.path.join(self.tmpdir, "proc"), exist_ok=True)

    def _intent(self, category, action, entities=None):
        return intent_engine.Intent(
            category=category, action=action,
            entities=entities or {}, raw=""
        )

    def test_init_sets_os_root(self):
        r = router.Router(os_root=self.tmpdir, aios_root=self.tmpdir)
        self.assertEqual(r.os_root, self.tmpdir)

    def test_init_bots_creates_three_bots(self):
        r = router.Router(os_root=self.tmpdir, aios_root=self.tmpdir)
        self.assertEqual(len(r._bots), 3)

    def test_registered_bot_has_highest_priority(self):
        class AlwaysBot(bots.BaseBot):
            name = "AlwaysBot"
            def can_handle(self, intent): return True
            def handle(self, intent): return "always-matched"

        r = router.Router(os_root=self.tmpdir)
        r.register_bot(AlwaysBot())
        i = intent_engine.Intent("health", "check", raw="health")
        out = r.dispatch(i)
        self.assertEqual(out, "always-matched")

    def test_dispatch_returns_none_for_unmatched_category(self):
        r = router.Router(os_root=self.tmpdir)
        i = intent_engine.Intent("unknown_category", "unknown_action", raw="xyz")
        out = r.dispatch(i)
        self.assertIsNone(out)


# ===========================================================================
# ai_backend.py — chat_response and run_system_command
# ===========================================================================

class TestAiBackendFunctions(unittest.TestCase):
    def setUp(self):
        spec = importlib.util.spec_from_file_location(
            "ai_backend", os.path.join(_AI_CORE, "ai_backend.py")
        )
        self.mod = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(self.mod)
        self.tmpdir = tempfile.mkdtemp()

    def test_chat_response_returns_string(self):
        out = self.mod.chat_response("hello")
        self.assertIsInstance(out, str)
        self.assertGreater(len(out), 0)

    def test_chat_response_contains_aura(self):
        out = self.mod.chat_response("hello")
        self.assertIn("AURA", out)

    def test_run_system_command_no_binary(self):
        import types
        plan = types.SimpleNamespace(command="fs.ls", args=["."])
        out = self.mod.run_system_command(plan, self.tmpdir)
        self.assertIn("ERROR", out)
        self.assertIn("aios-sys", out)


# ===========================================================================
# commands.py — extended coverage
# ===========================================================================

class TestCommandsExtended(unittest.TestCase):
    def _p(self, text):
        return commands.parse_natural_language(text)

    def test_mkdir(self):
        p = self._p("mkdir /tmp/newdir")
        self.assertEqual(p.command, "fs.mkdir")
        self.assertIn("/tmp/newdir", p.args)

    def test_rm(self):
        p = self._p("rm /tmp/test")
        self.assertEqual(p.command, "fs.rm")
        self.assertIn("/tmp/test", p.args)

    def test_kill(self):
        p = self._p("kill 1234")
        self.assertEqual(p.command, "proc.kill")
        self.assertIn("1234", p.args)

    def test_ifconfig(self):
        p = self._p("ifconfig")
        self.assertEqual(p.command, "net.ifconfig")
        self.assertEqual(p.args, [])

    def test_dir_alias(self):
        p = self._p("dir")
        self.assertEqual(p.command, "fs.ls")

    def test_show(self):
        p = self._p("show /etc/hosts")
        self.assertEqual(p.command, "fs.cat")
        self.assertIn("/etc/hosts", p.args)

    def test_remove_alias(self):
        p = self._p("remove /tmp/old")
        self.assertEqual(p.command, "fs.rm")

    def test_processes_alias(self):
        p = self._p("processes")
        self.assertEqual(p.command, "proc.ps")


# ===========================================================================
# intent_engine.py — extended coverage
# ===========================================================================

class TestIntentEngineExtended(unittest.TestCase):
    def setUp(self):
        self.ie = intent_engine.IntentEngine()

    def _c(self, text):
        return self.ie.classify(text)

    def test_mkdir_action_and_entity(self):
        i = self._c("mkdir /tmp/newdir")
        self.assertEqual(i.action, "fs.mkdir")
        self.assertEqual(i.entities.get("path"), "/tmp/newdir")

    def test_rm_action_and_entity(self):
        i = self._c("rm /tmp/file")
        self.assertEqual(i.action, "fs.rm")
        self.assertEqual(i.entities.get("path"), "/tmp/file")

    def test_kill_action_and_entity(self):
        i = self._c("kill 9999")
        self.assertEqual(i.action, "proc.kill")
        self.assertEqual(i.entities.get("pid"), "9999")

    def test_disk(self):
        i = self._c("disk")
        self.assertEqual(i.category, "system")
        self.assertEqual(i.action, "disk")

    def test_services(self):
        i = self._c("services")
        self.assertEqual(i.category, "system")
        self.assertEqual(i.action, "services")

    def test_reboot(self):
        i = self._c("reboot")
        self.assertEqual(i.category, "system")
        self.assertEqual(i.action, "reboot")

    def test_shutdown(self):
        i = self._c("shutdown")
        self.assertEqual(i.category, "system")
        self.assertEqual(i.action, "shutdown")

    def test_log_write(self):
        i = self._c("log.write Hello world")
        self.assertEqual(i.category, "log")
        self.assertEqual(i.action, "write")

    def test_mem_get(self):
        i = self._c("mem.get mykey")
        self.assertEqual(i.category, "memory")
        self.assertEqual(i.action, "mem.get")

    def test_recall_alias(self):
        i = self._c("recall mykey")
        self.assertEqual(i.category, "memory")
        self.assertEqual(i.action, "mem.get")

    def test_ifconfig(self):
        i = self._c("ifconfig")
        self.assertEqual(i.action, "net.ifconfig")

    def test_raw_preserved(self):
        i = self._c("ls /tmp")
        self.assertEqual(i.raw, "ls /tmp")

    def test_chat_fallback_confidence_low(self):
        i = self._c("tell me a random story")
        self.assertEqual(i.category, "chat")
        self.assertLess(i.confidence, 1.0)

    def test_sem_set(self):
        i = self._c("sem.set key val")
        self.assertEqual(i.category, "memory")
        self.assertEqual(i.action, "sem.set")

    def test_reinstall(self):
        i = self._c("reinstall all")
        self.assertEqual(i.category, "repair")
        self.assertEqual(i.action, "reinstall")


# ===========================================================================
# fuzzy.py — extended coverage
# ===========================================================================

class TestFuzzyExtended(unittest.TestCase):
    CMDS = ["ask", "recall", "sysinfo", "uptime", "disk", "ls", "services",
            "status", "help", "exit", "start", "stop"]

    def _m(self, term, cutoff=0.6):
        return fuzzy.best_match(term, self.CMDS, cutoff)

    def test_exact_match(self):
        self.assertEqual(self._m("ls"), "ls")

    def test_exact_match_longer(self):
        self.assertEqual(self._m("sysinfo"), "sysinfo")

    def test_empty_input_does_not_crash(self):
        result = self._m("")
        self.assertIsInstance(result, str)

    def test_custom_candidates(self):
        result = fuzzy.best_match("querry", ["query", "quit", "quota"])
        self.assertEqual(result, "query")

    def test_low_cutoff_allows_more_matches(self):
        result = fuzzy.best_match("hlp", self.CMDS, cutoff=0.3)
        self.assertIsInstance(result, str)

    def test_high_cutoff_rejects_poor_match(self):
        result = fuzzy.best_match("xyz", self.CMDS, cutoff=0.9)
        self.assertEqual(result, "")


# ===========================================================================
# OS/lib/filesystem.py — Python API tests
# ===========================================================================

class TestFilesystem(unittest.TestCase):
    """Direct unit tests for the filesystem.py Python API."""

    def setUp(self):
        self.tmpdir = tempfile.mkdtemp()
        from pathlib import Path
        spec = importlib.util.spec_from_file_location("_filesystem_mod", _FS_PY)
        self.fs = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(self.fs)
        # Patch the module-level OS_ROOT to use our temp dir
        self.fs._OS_ROOT = Path(self.tmpdir).resolve()

    def tearDown(self):
        shutil.rmtree(self.tmpdir, ignore_errors=True)

    def test_ts_format(self):
        ts = self.fs._ts()
        import re
        self.assertRegex(ts, r"\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z")

    def test_resolve_relative_stays_inside(self):
        p = self.fs._resolve("var/log/os.log")
        self.assertTrue(str(p).startswith(self.tmpdir))

    def test_resolve_absolute_strips_leading_slash(self):
        p = self.fs._resolve("/var/log/os.log")
        self.assertTrue(str(p).startswith(self.tmpdir))

    def test_resolve_traversal_raises_permission_error(self):
        with self.assertRaises(PermissionError):
            self.fs._resolve("../../etc/passwd")

    def test_fs_write_and_read(self):
        self.fs.fs_write("hello.txt", "hello world")
        content = self.fs.fs_read("hello.txt")
        self.assertEqual(content, "hello world")

    def test_fs_write_creates_parent_dirs(self):
        self.fs.fs_write("deep/nested/dir/file.txt", "nested")
        content = self.fs.fs_read("deep/nested/dir/file.txt")
        self.assertEqual(content, "nested")

    def test_fs_append_and_read(self):
        self.fs.fs_append("append.txt", "line1\n")
        self.fs.fs_append("append.txt", "line2\n")
        content = self.fs.fs_read("append.txt")
        self.assertIn("line1", content)
        self.assertIn("line2", content)

    def test_fs_list_returns_entries(self):
        self.fs.fs_write("listdir/file.txt", "x")
        entries = self.fs.fs_list("listdir")
        names = [e["name"] for e in entries]
        self.assertIn("file.txt", names)

    def test_fs_list_entry_has_required_keys(self):
        self.fs.fs_write("keytest/f.txt", "y")
        entries = self.fs.fs_list("keytest")
        self.assertTrue(len(entries) > 0)
        for e in entries:
            self.assertIn("name", e)
            self.assertIn("type", e)
            self.assertIn("size", e)

    def test_fs_list_not_a_directory(self):
        self.fs.fs_write("plainfile.txt", "x")
        with self.assertRaises(NotADirectoryError):
            self.fs.fs_list("plainfile.txt")

    def test_fs_exists_true(self):
        self.fs.fs_write("exists_yes.txt", "x")
        self.assertTrue(self.fs.fs_exists("exists_yes.txt"))

    def test_fs_exists_false(self):
        self.assertFalse(self.fs.fs_exists("definitely_not_here_xyzzy.txt"))

    def test_fs_exists_outside_returns_false(self):
        # Traversal path should return False (not raise)
        self.assertFalse(self.fs.fs_exists("../../etc/passwd"))

    def test_fs_stat_isfile(self):
        self.fs.fs_write("statfile.txt", "hello")
        info = self.fs.fs_stat("statfile.txt")
        self.assertTrue(info["isfile"])
        self.assertFalse(info["isdir"])
        self.assertGreater(info["size"], 0)

    def test_fs_stat_isdir(self):
        os.makedirs(os.path.join(self.tmpdir, "statdir"), exist_ok=True)
        info = self.fs.fs_stat("statdir")
        self.assertTrue(info["isdir"])
        self.assertFalse(info["isfile"])

    def test_fs_stat_missing_raises(self):
        with self.assertRaises(FileNotFoundError):
            self.fs.fs_stat("no_such_thing_xyz.txt")

    def test_fs_log_appends_timestamp_and_message(self):
        self.fs.fs_log("events.log", "a test log entry")
        content = self.fs.fs_read("events.log")
        self.assertIn("a test log entry", content)
        import re
        self.assertRegex(content, r"\d{4}-\d{2}-\d{2}T")

    def test_fs_read_nonexistent_raises(self):
        with self.assertRaises(FileNotFoundError):
            self.fs.fs_read("no_such_file_abc.txt")


# ===========================================================================
# Main
# ===========================================================================

if __name__ == "__main__":
    loader = unittest.TestLoader()
    suite  = loader.loadTestsFromModule(sys.modules[__name__])
    runner = unittest.TextTestRunner(verbosity=2)
    result = runner.run(suite)
    sys.exit(0 if result.wasSuccessful() else 1)
