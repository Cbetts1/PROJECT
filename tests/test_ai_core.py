#!/usr/bin/env python3
"""tests/test_ai_core.py — Unit tests for ai/core Python modules.

Run:
    python3 tests/test_ai_core.py
    # or: python3 -m pytest tests/test_ai_core.py -v
"""
import os
import sys
import unittest

# Ensure ai/core is importable regardless of working directory.
_REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(_REPO_ROOT, "ai", "core"))

from fuzzy import best_match                                # noqa: E402
from commands import CommandPlan, parse_natural_language    # noqa: E402
from llama_client import run_mock                           # noqa: E402


# ---------------------------------------------------------------------------
# fuzzy.py — best_match()
# ---------------------------------------------------------------------------

class TestBestMatch(unittest.TestCase):

    CMDS = ["fs.ls", "fs.cat", "fs.write", "fs.mkdir", "fs.rm",
            "proc.ps", "proc.kill", "net.ping", "net.ifconfig", "help", "exit"]

    def test_exact_match(self):
        self.assertEqual(best_match("help", self.CMDS), "help")

    def test_close_typo_one_char(self):
        # "hekp" is one substitution away from "help"
        result = best_match("hekp", self.CMDS)
        self.assertEqual(result, "help")

    def test_close_typo_prefix(self):
        # "exitt" vs "exit"
        result = best_match("exitt", self.CMDS)
        self.assertEqual(result, "exit")

    def test_no_match_garbage(self):
        result = best_match("xyz_totally_unknown_garbage", self.CMDS)
        self.assertEqual(result, "")

    def test_no_match_empty_candidates(self):
        result = best_match("help", [])
        self.assertEqual(result, "")

    def test_custom_cutoff_strict(self):
        # With a very high cutoff only exact matches pass
        result = best_match("hekp", self.CMDS, cutoff=0.99)
        self.assertEqual(result, "")

    def test_custom_cutoff_loose(self):
        # With a very low cutoff even distant strings can match
        result = best_match("ls", self.CMDS, cutoff=0.1)
        self.assertNotEqual(result, "")

    def test_returns_string_type(self):
        result = best_match("help", self.CMDS)
        self.assertIsInstance(result, str)


# ---------------------------------------------------------------------------
# commands.py — parse_natural_language()
# ---------------------------------------------------------------------------

class TestParseNaturalLanguage(unittest.TestCase):

    # --- Filesystem commands ---

    def test_ls_bare(self):
        plan = parse_natural_language("ls")
        self.assertEqual(plan.command, "fs.ls")
        self.assertEqual(plan.args, ["."])

    def test_list_bare(self):
        plan = parse_natural_language("list")
        self.assertEqual(plan.command, "fs.ls")

    def test_dir_bare(self):
        plan = parse_natural_language("dir")
        self.assertEqual(plan.command, "fs.ls")

    def test_ls_with_path(self):
        plan = parse_natural_language("ls /var/log")
        self.assertEqual(plan.command, "fs.ls")
        self.assertEqual(plan.args, ["/var/log"])

    def test_list_with_path(self):
        plan = parse_natural_language("list /tmp")
        self.assertEqual(plan.command, "fs.ls")
        self.assertEqual(plan.args, ["/tmp"])

    def test_cat(self):
        plan = parse_natural_language("cat /etc/passwd")
        self.assertEqual(plan.command, "fs.cat")
        self.assertEqual(plan.args, ["/etc/passwd"])

    def test_show(self):
        plan = parse_natural_language("show notes.txt")
        self.assertEqual(plan.command, "fs.cat")
        self.assertEqual(plan.args, ["notes.txt"])

    def test_read(self):
        plan = parse_natural_language("read readme.md")
        self.assertEqual(plan.command, "fs.cat")
        self.assertEqual(plan.args, ["readme.md"])

    def test_mkdir(self):
        plan = parse_natural_language("mkdir /tmp/newdir")
        self.assertEqual(plan.command, "fs.mkdir")
        self.assertEqual(plan.args, ["/tmp/newdir"])

    def test_make_dir(self):
        # split(maxsplit=1) on "make dir /tmp/x" gives "dir /tmp/x" as the path arg
        plan = parse_natural_language("make dir /tmp/x")
        self.assertEqual(plan.command, "fs.mkdir")
        self.assertEqual(plan.args, ["dir /tmp/x"])

    def test_create_dir(self):
        # split(maxsplit=1) on "create dir /foo" gives "dir /foo" as the path arg
        plan = parse_natural_language("create dir /foo")
        self.assertEqual(plan.command, "fs.mkdir")
        self.assertEqual(plan.args, ["dir /foo"])

    def test_rm(self):
        plan = parse_natural_language("rm /tmp/oldfile")
        self.assertEqual(plan.command, "fs.rm")
        self.assertEqual(plan.args, ["/tmp/oldfile"])

    def test_remove(self):
        plan = parse_natural_language("remove junk.txt")
        self.assertEqual(plan.command, "fs.rm")
        self.assertEqual(plan.args, ["junk.txt"])

    def test_delete(self):
        plan = parse_natural_language("delete old.log")
        self.assertEqual(plan.command, "fs.rm")
        self.assertEqual(plan.args, ["old.log"])

    # --- Process commands ---

    def test_ps_bare(self):
        plan = parse_natural_language("ps")
        self.assertEqual(plan.command, "proc.ps")
        self.assertEqual(plan.args, [])

    def test_processes(self):
        plan = parse_natural_language("processes")
        self.assertEqual(plan.command, "proc.ps")

    def test_show_processes(self):
        # "show " prefix matches the fs.cat rule before proc.ps literals
        plan = parse_natural_language("show processes")
        self.assertEqual(plan.command, "fs.cat")

    def test_list_processes(self):
        # "list " prefix matches the fs.ls rule before proc.ps literals
        plan = parse_natural_language("list processes")
        self.assertEqual(plan.command, "fs.ls")

    def test_kill_pid(self):
        plan = parse_natural_language("kill 1234")
        self.assertEqual(plan.command, "proc.kill")
        self.assertEqual(plan.args, ["1234"])

    def test_kill_process(self):
        # split(maxsplit=1) on "kill process 99" gives "process 99" as the pid arg
        plan = parse_natural_language("kill process 99")
        self.assertEqual(plan.command, "proc.kill")
        self.assertEqual(plan.args, ["process 99"])

    # --- Network commands ---

    def test_ping(self):
        plan = parse_natural_language("ping 8.8.8.8")
        self.assertEqual(plan.command, "net.ping")
        self.assertEqual(plan.args, ["8.8.8.8"])

    def test_ping_hostname(self):
        plan = parse_natural_language("ping example.com")
        self.assertEqual(plan.command, "net.ping")
        self.assertEqual(plan.args, ["example.com"])

    def test_ifconfig(self):
        plan = parse_natural_language("ifconfig")
        self.assertEqual(plan.command, "net.ifconfig")
        self.assertEqual(plan.args, [])

    def test_ip_addr(self):
        plan = parse_natural_language("ip addr")
        self.assertEqual(plan.command, "net.ifconfig")

    def test_network(self):
        plan = parse_natural_language("network")
        self.assertEqual(plan.command, "net.ifconfig")

    def test_interfaces(self):
        plan = parse_natural_language("interfaces")
        self.assertEqual(plan.command, "net.ifconfig")

    # --- Fallback to chat ---

    def test_chat_fallback(self):
        plan = parse_natural_language("what is the meaning of life")
        self.assertEqual(plan.command, "chat")

    def test_chat_fallback_preserves_text(self):
        text = "tell me about yourself"
        plan = parse_natural_language(text)
        self.assertEqual(plan.command, "chat")
        self.assertEqual(plan.args, [text])

    def test_empty_input_falls_to_chat(self):
        plan = parse_natural_language("   ")
        self.assertEqual(plan.command, "chat")

    # --- CommandPlan dataclass ---

    def test_command_plan_defaults(self):
        cp = CommandPlan("test")
        self.assertEqual(cp.command, "test")
        self.assertEqual(cp.args, [])

    def test_command_plan_with_args(self):
        cp = CommandPlan("fs.ls", ["/var"])
        self.assertEqual(cp.args, ["/var"])


# ---------------------------------------------------------------------------
# llama_client.py — run_mock()
# ---------------------------------------------------------------------------

class TestRunMock(unittest.TestCase):

    def test_returns_string(self):
        result = run_mock("hello")
        self.assertIsInstance(result, str)

    def test_contains_prompt(self):
        prompt = "test prompt unique 12345"
        result = run_mock(prompt)
        self.assertIn(prompt, result)

    def test_mock_prefix(self):
        result = run_mock("anything")
        self.assertIn("[MOCK AI]", result)

    def test_empty_prompt(self):
        result = run_mock("")
        self.assertIsInstance(result, str)

    def test_multiword_prompt(self):
        result = run_mock("show me the disk usage")
        self.assertIn("show me the disk usage", result)


# ---------------------------------------------------------------------------
# llama_client.py — run_llama() error path (no binary available)
# ---------------------------------------------------------------------------

class TestRunLlamaErrorPath(unittest.TestCase):

    def test_returns_error_message_when_no_binary(self):
        # In the test environment llama-cli is not installed, so
        # run_llama should return an error string, not raise.
        import importlib
        import llama_client as lc

        # Patch subprocess.run to always fail (simulates no binary in PATH)
        import subprocess
        original_run = subprocess.run

        def mock_run(cmd, **kwargs):
            class R:
                returncode = 1
                stdout = ""
            return R()

        subprocess.run = mock_run
        try:
            result = lc.run_llama("/nonexistent/model.gguf", 4096, 4, "hello")
        finally:
            subprocess.run = original_run

        self.assertIsInstance(result, str)
        self.assertIn("llama", result.lower())


# ---------------------------------------------------------------------------
# ai_backend.py — chat_response() and run_system_command() error path
# ---------------------------------------------------------------------------

class TestAIBackend(unittest.TestCase):

    def setUp(self):
        # Import here so sys.path is already set up
        import ai_backend as ab
        self.ab = ab

    def test_chat_response_returns_string(self):
        result = self.ab.chat_response("hello there")
        self.assertIsInstance(result, str)
        self.assertTrue(len(result) > 0)

    def test_chat_response_contains_input(self):
        result = self.ab.chat_response("unique test input 99887766")
        self.assertIn("unique test input 99887766", result)

    def test_run_system_command_error_on_missing_aios_sys(self):
        from commands import CommandPlan
        plan = CommandPlan("fs.ls", ["."])
        result = self.ab.run_system_command(plan, "/nonexistent/aios_root")
        self.assertIsInstance(result, str)
        self.assertIn("[ERROR]", result)

    def test_run_system_command_error_message_mentions_aios_sys(self):
        from commands import CommandPlan
        plan = CommandPlan("proc.ps", [])
        result = self.ab.run_system_command(plan, "/totally/missing")
        self.assertTrue(
            "aios-sys" in result or "ERROR" in result,
            f"Expected error message, got: {result!r}"
        )


if __name__ == "__main__":
    unittest.main(verbosity=2)
