#!/usr/bin/env python3
"""tests/test_python_modules.py — Unit tests for AIOS Python modules.

Covers:
  - ai/core/commands.py  (parse_natural_language)
  - ai/core/fuzzy.py     (best_match)
  - ai/core/llama_client.py (run_mock, run_llama no-binary path)
  - OS/lib/filesystem.py    (full Python API, error paths, traversal)
  - aura/aura-agent.py      (handle_command all verbs, remember/recall, load_config)

Run:
    python3 tests/test_python_modules.py
    python3 -m pytest tests/test_python_modules.py -v
"""

import importlib.util
import json
import os
import shutil
import sys
import tempfile
import unittest
from pathlib import Path

# ---------------------------------------------------------------------------
# Path setup — import from ai/core/, aura/, and OS/lib/ without installation
# ---------------------------------------------------------------------------
REPO_ROOT = Path(__file__).resolve().parent.parent
AI_CORE = REPO_ROOT / "ai" / "core"
AURA_DIR = REPO_ROOT / "aura"
OS_LIB = REPO_ROOT / "OS" / "lib"

sys.path.insert(0, str(AI_CORE))


# ---------------------------------------------------------------------------
# Helper: load OS/lib/filesystem.py with a custom OS_ROOT
# ---------------------------------------------------------------------------

def _load_filesystem(os_root: str):
    """Import filesystem.py fresh with OS_ROOT set to *os_root*."""
    os.environ["OS_ROOT"] = os_root
    spec = importlib.util.spec_from_file_location(
        "filesystem_" + os_root.replace("/", "_"),
        OS_LIB / "filesystem.py",
    )
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


# ---------------------------------------------------------------------------
# Helper: load aura/aura-agent.py with temp DB and log paths
# ---------------------------------------------------------------------------

def _load_aura_agent(db_path: str, log_path: str):
    """Import aura-agent.py fresh and point it at temp files."""
    spec = importlib.util.spec_from_file_location(
        "aura_agent", AURA_DIR / "aura-agent.py"
    )
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    mod.CONFIG["db_path"] = db_path
    mod.CONFIG["log_path"] = log_path
    # Reset any cached DB connection from the fresh module
    mod._db_local.__dict__.clear()
    mod.init_db()
    return mod


# ===========================================================================
# ai/core/commands.py — parse_natural_language
# ===========================================================================

class TestParseNaturalLanguage(unittest.TestCase):
    """Tests for commands.parse_natural_language()."""

    def setUp(self):
        from commands import parse_natural_language
        self.parse = parse_natural_language

    # --- Filesystem: ls / list / dir (bare) ---

    def test_ls_bare(self):
        plan = self.parse("ls")
        self.assertEqual(plan.command, "fs.ls")
        self.assertEqual(plan.args, ["."])

    def test_list_bare(self):
        plan = self.parse("list")
        self.assertEqual(plan.command, "fs.ls")
        self.assertEqual(plan.args, ["."])

    def test_dir_bare(self):
        plan = self.parse("dir")
        self.assertEqual(plan.command, "fs.ls")
        self.assertEqual(plan.args, ["."])

    def test_ls_with_path(self):
        plan = self.parse("ls /var/log")
        self.assertEqual(plan.command, "fs.ls")
        self.assertEqual(plan.args, ["/var/log"])

    def test_list_with_path(self):
        plan = self.parse("list mydir")
        self.assertEqual(plan.command, "fs.ls")
        self.assertEqual(plan.args, ["mydir"])

    def test_dir_with_path(self):
        plan = self.parse("dir /tmp")
        self.assertEqual(plan.command, "fs.ls")
        self.assertEqual(plan.args, ["/tmp"])

    # --- Filesystem: cat / show / read ---

    def test_cat(self):
        plan = self.parse("cat /etc/passwd")
        self.assertEqual(plan.command, "fs.cat")
        self.assertEqual(plan.args, ["/etc/passwd"])

    def test_show(self):
        plan = self.parse("show notes.txt")
        self.assertEqual(plan.command, "fs.cat")
        self.assertEqual(plan.args, ["notes.txt"])

    def test_read(self):
        plan = self.parse("read config.yaml")
        self.assertEqual(plan.command, "fs.cat")
        self.assertEqual(plan.args, ["config.yaml"])

    # --- Filesystem: mkdir ---

    def test_mkdir(self):
        plan = self.parse("mkdir newdir")
        self.assertEqual(plan.command, "fs.mkdir")
        self.assertEqual(plan.args, ["newdir"])

    def test_make_dir(self):
        # "make dir mydir".split(maxsplit=1)[1] == "dir mydir"
        plan = self.parse("make dir mydir")
        self.assertEqual(plan.command, "fs.mkdir")
        self.assertEqual(plan.args, ["dir mydir"])

    def test_create_dir(self):
        # "create dir thedir".split(maxsplit=1)[1] == "dir thedir"
        plan = self.parse("create dir thedir")
        self.assertEqual(plan.command, "fs.mkdir")
        self.assertEqual(plan.args, ["dir thedir"])

    # --- Filesystem: rm / remove / delete ---

    def test_rm(self):
        plan = self.parse("rm oldfile.txt")
        self.assertEqual(plan.command, "fs.rm")
        self.assertEqual(plan.args, ["oldfile.txt"])

    def test_remove(self):
        plan = self.parse("remove garbage.log")
        self.assertEqual(plan.command, "fs.rm")
        self.assertEqual(plan.args, ["garbage.log"])

    def test_delete(self):
        plan = self.parse("delete temp")
        self.assertEqual(plan.command, "fs.rm")
        self.assertEqual(plan.args, ["temp"])

    # --- Process: ps ---

    def test_ps(self):
        plan = self.parse("ps")
        self.assertEqual(plan.command, "proc.ps")
        self.assertEqual(plan.args, [])

    def test_processes(self):
        plan = self.parse("processes")
        self.assertEqual(plan.command, "proc.ps")
        self.assertEqual(plan.args, [])

    # --- Process: kill ---

    def test_kill_pid(self):
        plan = self.parse("kill 1234")
        self.assertEqual(plan.command, "proc.kill")
        self.assertEqual(plan.args, ["1234"])

    def test_kill_process_prefix(self):
        plan = self.parse("kill process 5678")
        self.assertEqual(plan.command, "proc.kill")
        self.assertEqual(plan.args, ["process 5678"])

    # --- Network: ping ---

    def test_ping(self):
        plan = self.parse("ping google.com")
        self.assertEqual(plan.command, "net.ping")
        self.assertEqual(plan.args, ["google.com"])

    def test_ping_ip(self):
        plan = self.parse("ping 8.8.8.8")
        self.assertEqual(plan.command, "net.ping")
        self.assertEqual(plan.args, ["8.8.8.8"])

    # --- Network: ifconfig / ip addr / network / interfaces ---

    def test_ifconfig(self):
        plan = self.parse("ifconfig")
        self.assertEqual(plan.command, "net.ifconfig")
        self.assertEqual(plan.args, [])

    def test_ip_addr(self):
        plan = self.parse("ip addr")
        self.assertEqual(plan.command, "net.ifconfig")
        self.assertEqual(plan.args, [])

    def test_network(self):
        plan = self.parse("network")
        self.assertEqual(plan.command, "net.ifconfig")
        self.assertEqual(plan.args, [])

    def test_interfaces(self):
        plan = self.parse("interfaces")
        self.assertEqual(plan.command, "net.ifconfig")
        self.assertEqual(plan.args, [])

    # --- Fallback to chat ---

    def test_unknown_falls_back_to_chat(self):
        plan = self.parse("what is the weather like")
        self.assertEqual(plan.command, "chat")

    def test_empty_string_falls_back_to_chat(self):
        plan = self.parse("")
        self.assertEqual(plan.command, "chat")

    def test_whitespace_only_falls_back_to_chat(self):
        plan = self.parse("   ")
        self.assertEqual(plan.command, "chat")

    def test_chat_args_contain_stripped_input(self):
        text = "explain quantum computing"
        plan = self.parse(text)
        self.assertEqual(plan.command, "chat")
        self.assertIn(text.strip(), plan.args)

    def test_chat_response_for_question(self):
        plan = self.parse("how do I restart the daemon?")
        self.assertEqual(plan.command, "chat")

    # --- CommandPlan dataclass ---

    def test_command_plan_has_command_and_args(self):
        from commands import CommandPlan
        p = CommandPlan("fs.ls", ["subdir"])
        self.assertEqual(p.command, "fs.ls")
        self.assertEqual(p.args, ["subdir"])

    def test_command_plan_default_args_empty(self):
        from commands import CommandPlan
        p = CommandPlan("proc.ps")
        self.assertEqual(p.args, [])


# ===========================================================================
# ai/core/fuzzy.py — best_match
# ===========================================================================

class TestBestMatch(unittest.TestCase):
    """Tests for fuzzy.best_match()."""

    def setUp(self):
        from fuzzy import best_match
        self.best_match = best_match
        self.candidates = [
            "sysinfo", "uptime", "services", "start", "stop", "help", "exit",
        ]

    def test_exact_match(self):
        self.assertEqual(self.best_match("sysinfo", self.candidates), "sysinfo")

    def test_exact_match_short(self):
        self.assertEqual(self.best_match("help", self.candidates), "help")

    def test_close_match_one_char_off(self):
        result = self.best_match("sysinf", self.candidates)
        self.assertEqual(result, "sysinfo")

    def test_close_match_uptime(self):
        result = self.best_match("uptme", self.candidates)
        self.assertEqual(result, "uptime")

    def test_no_match_garbage(self):
        result = self.best_match("xyz_totally_unknown", self.candidates)
        self.assertEqual(result, "")

    def test_empty_input_no_match(self):
        result = self.best_match("", self.candidates)
        self.assertEqual(result, "")

    def test_empty_candidates(self):
        result = self.best_match("sysinfo", [])
        self.assertEqual(result, "")

    def test_custom_cutoff_strict_no_match(self):
        # cutoff=1.0 means only exact matches qualify
        result = self.best_match("sysinf", self.candidates, cutoff=1.0)
        self.assertEqual(result, "")

    def test_custom_cutoff_strict_exact_still_matches(self):
        result = self.best_match("help", self.candidates, cutoff=1.0)
        self.assertEqual(result, "help")

    def test_returns_string_type(self):
        result = self.best_match("stop", self.candidates)
        self.assertIsInstance(result, str)

    def test_single_candidate_match(self):
        result = self.best_match("sysinfo", ["sysinfo"])
        self.assertEqual(result, "sysinfo")

    def test_single_candidate_no_match(self):
        result = self.best_match("zzz", ["sysinfo"])
        self.assertEqual(result, "")


# ===========================================================================
# ai/core/llama_client.py — run_mock, run_llama (no-binary path)
# ===========================================================================

class TestLlamaClient(unittest.TestCase):
    """Tests for llama_client module."""

    def setUp(self):
        from llama_client import run_mock, run_llama
        self.run_mock = run_mock
        self.run_llama = run_llama

    # --- run_mock ---

    def test_run_mock_returns_string(self):
        result = self.run_mock("hello")
        self.assertIsInstance(result, str)

    def test_run_mock_contains_prompt(self):
        result = self.run_mock("test prompt")
        self.assertIn("test prompt", result)

    def test_run_mock_nonempty(self):
        result = self.run_mock("anything")
        self.assertTrue(len(result) > 0)

    def test_run_mock_empty_prompt(self):
        result = self.run_mock("")
        self.assertIsInstance(result, str)

    def test_run_mock_multi_word_prompt(self):
        result = self.run_mock("what is the time now")
        self.assertIn("what is the time now", result)

    # --- run_llama (no binary present in CI) ---

    def test_run_llama_no_binary_returns_error_string(self):
        # In the test environment llama-cli is not installed.
        result = self.run_llama("/nonexistent/model.gguf", 512, 1, "hello")
        self.assertIsInstance(result, str)
        self.assertTrue(len(result) > 0)

    def test_run_llama_no_binary_mentions_not_found(self):
        result = self.run_llama("/nonexistent/model.gguf", 512, 1, "hello")
        self.assertIn("not found", result.lower())

    def test_run_llama_does_not_raise(self):
        # Must return a string, not raise an exception
        try:
            result = self.run_llama("/nonexistent/model.gguf", 512, 1, "hello")
            self.assertIsInstance(result, str)
        except Exception as exc:  # noqa: BLE001
            self.fail(f"run_llama raised unexpectedly: {exc}")


# ===========================================================================
# OS/lib/filesystem.py — Python API
# ===========================================================================

class TestFilesystemPythonAPI(unittest.TestCase):
    """Tests for filesystem.py public Python API.

    Each test method gets a fresh temporary OS_ROOT so tests are isolated
    and do not touch the real repository filesystem.
    """

    def setUp(self):
        self._tmpdir = tempfile.mkdtemp()
        self.fs = _load_filesystem(self._tmpdir)

    def tearDown(self):
        shutil.rmtree(self._tmpdir, ignore_errors=True)

    # --- fs_write / fs_read roundtrip ---

    def test_write_read_roundtrip(self):
        self.fs.fs_write("test.txt", "hello world")
        self.assertEqual(self.fs.fs_read("test.txt"), "hello world")

    def test_write_creates_parent_dirs(self):
        self.fs.fs_write("deep/nested/file.txt", "nested content")
        self.assertEqual(self.fs.fs_read("deep/nested/file.txt"), "nested content")

    def test_write_overwrites_existing(self):
        self.fs.fs_write("over.txt", "first")
        self.fs.fs_write("over.txt", "second")
        self.assertEqual(self.fs.fs_read("over.txt"), "second")

    def test_write_empty_content(self):
        self.fs.fs_write("empty.txt", "")
        self.assertEqual(self.fs.fs_read("empty.txt"), "")

    # --- fs_read errors ---

    def test_read_nonexistent_raises_file_not_found(self):
        with self.assertRaises(FileNotFoundError):
            self.fs.fs_read("no_such_file.txt")

    def test_read_traversal_blocked(self):
        with self.assertRaises(PermissionError):
            self.fs.fs_read("../../etc/passwd")

    def test_read_absolute_path_uses_chroot_semantics(self):
        # Absolute paths are re-routed inside OS_ROOT (chroot-style).
        # /subdir/file.txt → OS_ROOT/subdir/file.txt — no escape is possible.
        self.fs.fs_write("/subdir/chroot_test.txt", "chroot content")
        result = self.fs.fs_read("/subdir/chroot_test.txt")
        self.assertEqual(result, "chroot content")

    # --- fs_append ---

    def test_append_creates_file(self):
        self.fs.fs_append("newfile.txt", "line1\n")
        content = self.fs.fs_read("newfile.txt")
        self.assertIn("line1", content)

    def test_append_accumulates(self):
        self.fs.fs_append("acc.txt", "alpha\n")
        self.fs.fs_append("acc.txt", "beta\n")
        content = self.fs.fs_read("acc.txt")
        self.assertIn("alpha", content)
        self.assertIn("beta", content)

    def test_append_traversal_blocked(self):
        with self.assertRaises(PermissionError):
            self.fs.fs_append("../../tmp/evil.txt", "injected")

    # --- fs_list ---

    def test_list_returns_entries(self):
        self.fs.fs_write("alpha.txt", "a")
        self.fs.fs_write("beta.txt", "b")
        entries = self.fs.fs_list(".")
        names = [e["name"] for e in entries]
        self.assertIn("alpha.txt", names)
        self.assertIn("beta.txt", names)

    def test_list_entry_has_required_keys(self):
        self.fs.fs_write("check.txt", "x")
        for entry in self.fs.fs_list("."):
            self.assertIn("name", entry)
            self.assertIn("type", entry)
            self.assertIn("size", entry)

    def test_list_file_type(self):
        self.fs.fs_write("afile.txt", "data")
        entries = self.fs.fs_list(".")
        file_entry = next(e for e in entries if e["name"] == "afile.txt")
        self.assertEqual(file_entry["type"], "file")

    def test_list_dir_type(self):
        os.makedirs(os.path.join(self._tmpdir, "subdir"), exist_ok=True)
        entries = self.fs.fs_list(".")
        dir_entry = next(e for e in entries if e["name"] == "subdir")
        self.assertEqual(dir_entry["type"], "dir")

    def test_list_non_directory_raises(self):
        self.fs.fs_write("notadir.txt", "data")
        with self.assertRaises(NotADirectoryError):
            self.fs.fs_list("notadir.txt")

    def test_list_traversal_blocked(self):
        with self.assertRaises(PermissionError):
            self.fs.fs_list("../../tmp")

    def test_list_is_sorted(self):
        self.fs.fs_write("z.txt", "z")
        self.fs.fs_write("a.txt", "a")
        entries = self.fs.fs_list(".")
        names = [e["name"] for e in entries]
        self.assertEqual(names, sorted(names))

    # --- fs_exists ---

    def test_exists_true_for_file(self):
        self.fs.fs_write("exists.txt", "yes")
        self.assertTrue(self.fs.fs_exists("exists.txt"))

    def test_exists_false_for_missing(self):
        self.assertFalse(self.fs.fs_exists("does_not_exist.txt"))

    def test_exists_returns_false_outside_osroot(self):
        self.assertFalse(self.fs.fs_exists("../../etc/passwd"))

    def test_exists_true_for_directory(self):
        os.makedirs(os.path.join(self._tmpdir, "mydir"), exist_ok=True)
        self.assertTrue(self.fs.fs_exists("mydir"))

    # --- fs_stat ---

    def test_stat_regular_file(self):
        self.fs.fs_write("stat_me.txt", "hello")
        info = self.fs.fs_stat("stat_me.txt")
        self.assertTrue(info["isfile"])
        self.assertFalse(info["isdir"])
        self.assertGreater(info["size"], 0)

    def test_stat_directory(self):
        os.makedirs(os.path.join(self._tmpdir, "statdir"), exist_ok=True)
        info = self.fs.fs_stat("statdir")
        self.assertTrue(info["isdir"])
        self.assertFalse(info["isfile"])

    def test_stat_nonexistent_raises(self):
        with self.assertRaises(FileNotFoundError):
            self.fs.fs_stat("no_such.txt")

    def test_stat_has_mtime(self):
        self.fs.fs_write("mtime.txt", "data")
        info = self.fs.fs_stat("mtime.txt")
        self.assertIn("mtime", info)
        self.assertIsInstance(info["mtime"], float)

    def test_stat_has_all_expected_keys(self):
        self.fs.fs_write("keys.txt", "x")
        info = self.fs.fs_stat("keys.txt")
        for key in ("path", "size", "mtime", "isdir", "isfile"):
            self.assertIn(key, info)

    # --- fs_log ---

    def test_log_appends_message(self):
        self.fs.fs_log("var/log/test.log", "test message")
        content = self.fs.fs_read("var/log/test.log")
        self.assertIn("test message", content)

    def test_log_message_has_iso_timestamp(self):
        import re
        self.fs.fs_log("var/log/ts.log", "marker entry")
        content = self.fs.fs_read("var/log/ts.log")
        self.assertRegex(content, r"\[\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z\]")

    def test_log_multiple_entries_accumulate(self):
        self.fs.fs_log("var/log/multi.log", "first")
        self.fs.fs_log("var/log/multi.log", "second")
        content = self.fs.fs_read("var/log/multi.log")
        self.assertIn("first", content)
        self.assertIn("second", content)

    # --- absolute path handling (_resolve chroot semantics) ---

    def test_absolute_path_stays_in_jail(self):
        # /subdir/abs_test.txt → OS_ROOT/subdir/abs_test.txt
        self.fs.fs_write("/subdir/abs_test.txt", "abs content")
        result = self.fs.fs_read("/subdir/abs_test.txt")
        self.assertEqual(result, "abs content")

    def test_absolute_root_slash_maps_to_osroot(self):
        # Writing to / should be OS_ROOT itself (directory)
        self.assertTrue(self.fs.fs_exists("/"))


# ===========================================================================
# aura/aura-agent.py — handle_command, remember/recall, load_config
# ===========================================================================

class TestAuraAgent(unittest.TestCase):
    """Tests for aura-agent.py command dispatcher and memory functions."""

    def setUp(self):
        self._tmpdir = tempfile.mkdtemp()
        db_path = os.path.join(self._tmpdir, "test.db")
        log_path = os.path.join(self._tmpdir, "test.log")
        self.mod = _load_aura_agent(db_path, log_path)

    def tearDown(self):
        shutil.rmtree(self._tmpdir, ignore_errors=True)

    # --- ping ---

    def test_ping_returns_pong(self):
        self.assertEqual(self.mod.handle_command("ping"), "pong")

    def test_ping_case_insensitive(self):
        self.assertEqual(self.mod.handle_command("PING"), "pong")

    # --- version ---

    def test_version_contains_agent_name(self):
        resp = self.mod.handle_command("version")
        self.assertIn("AURA", resp)

    def test_version_contains_version_number(self):
        resp = self.mod.handle_command("version")
        self.assertIn("v", resp)

    # --- help ---

    def test_help_lists_ping(self):
        self.assertIn("ping", self.mod.handle_command("help"))

    def test_help_lists_remember(self):
        self.assertIn("remember", self.mod.handle_command("help"))

    def test_help_lists_recall(self):
        self.assertIn("recall", self.mod.handle_command("help"))

    def test_help_lists_quit(self):
        self.assertIn("quit", self.mod.handle_command("help"))

    # --- quit / exit ---

    def test_quit_returns_sentinel(self):
        self.assertEqual(self.mod.handle_command("quit"), "QUIT")

    def test_exit_returns_sentinel(self):
        self.assertEqual(self.mod.handle_command("exit"), "QUIT")

    def test_q_returns_sentinel(self):
        self.assertEqual(self.mod.handle_command("q"), "QUIT")

    # --- empty / unknown ---

    def test_empty_line_returns_empty_string(self):
        self.assertEqual(self.mod.handle_command(""), "")

    def test_unknown_command_reports_unknown(self):
        resp = self.mod.handle_command("blorp")
        self.assertIn("UNKNOWN", resp.upper())

    def test_unknown_command_includes_verb(self):
        resp = self.mod.handle_command("frobnicate")
        self.assertIn("frobnicate", resp)

    # --- remember / recall roundtrip via handle_command ---

    def test_remember_recall_roundtrip(self):
        self.mod.handle_command("remember user name=Alice")
        resp = self.mod.handle_command("recall user name")
        self.assertIn("Alice", resp)

    def test_remember_ok_response(self):
        resp = self.mod.handle_command("remember session color=blue")
        self.assertIn("OK", resp)

    def test_remember_missing_equals_is_error(self):
        resp = self.mod.handle_command("remember user no_equals_here")
        self.assertIn("ERROR", resp)

    def test_remember_empty_key_is_error(self):
        resp = self.mod.handle_command("remember user =value_only")
        self.assertIn("ERROR", resp)

    def test_remember_missing_args_is_error(self):
        resp = self.mod.handle_command("remember")
        self.assertIn("ERROR", resp)

    def test_recall_not_found(self):
        resp = self.mod.handle_command("recall ghost nonexistent_key")
        self.assertIn("NOT FOUND", resp)

    def test_recall_missing_key_arg_is_error(self):
        resp = self.mod.handle_command("recall scope_only")
        self.assertIn("ERROR", resp)

    def test_recall_missing_all_args_is_error(self):
        resp = self.mod.handle_command("recall")
        self.assertIn("ERROR", resp)

    # --- recall-all via handle_command ---

    def test_recall_all_empty_scope(self):
        resp = self.mod.handle_command("recall-all empty_scope_xyz_$$")
        self.assertIn("NO ENTRIES", resp)

    def test_recall_all_with_entries(self):
        self.mod.handle_command("remember myscope foo=bar")
        self.mod.handle_command("remember myscope baz=qux")
        resp = self.mod.handle_command("recall-all myscope")
        self.assertIn("foo", resp)
        self.assertIn("bar", resp)

    def test_recall_all_missing_scope_is_error(self):
        resp = self.mod.handle_command("recall-all")
        self.assertIn("ERROR", resp)

    # --- upgrade validation ---

    def test_upgrade_invalid_flag_is_error(self):
        resp = self.mod.handle_command("upgrade --invalid")
        self.assertIn("ERROR", resp)

    def test_upgrade_valid_flags_do_not_raise(self):
        for flag in ("--check", "--status", "--apply"):
            resp = self.mod.handle_command(f"upgrade {flag}")
            self.assertIsInstance(resp, str)

    # --- remember / recall / recall_all Python API ---

    def test_remember_recall_api_roundtrip(self):
        self.mod.remember("test_scope", "mykey", "myvalue")
        result = self.mod.recall("test_scope", "mykey")
        self.assertEqual(result, "myvalue")

    def test_recall_nonexistent_returns_none(self):
        result = self.mod.recall("no_scope", "no_key")
        self.assertIsNone(result)

    def test_recall_all_api_returns_list(self):
        self.mod.remember("s1", "k1", "v1")
        self.mod.remember("s1", "k2", "v2")
        entries = self.mod.recall_all("s1")
        self.assertEqual(len(entries), 2)
        keys = [e["key"] for e in entries]
        self.assertIn("k1", keys)
        self.assertIn("k2", keys)

    def test_recall_returns_most_recent_value(self):
        self.mod.remember("s2", "key", "first")
        self.mod.remember("s2", "key", "second")
        self.assertEqual(self.mod.recall("s2", "key"), "second")

    def test_recall_all_empty_scope_returns_empty_list(self):
        entries = self.mod.recall_all("nonexistent_scope_xyz")
        self.assertEqual(entries, [])

    def test_remember_entry_has_expected_fields(self):
        self.mod.remember("scope_a", "key_a", "val_a")
        entries = self.mod.recall_all("scope_a")
        self.assertEqual(len(entries), 1)
        entry = entries[0]
        for field in ("id", "created_at", "scope", "key", "value"):
            self.assertIn(field, entry)
        self.assertEqual(entry["scope"], "scope_a")
        self.assertEqual(entry["key"], "key_a")
        self.assertEqual(entry["value"], "val_a")

    def test_cross_scope_isolation(self):
        self.mod.remember("scope_x", "key", "value_x")
        self.mod.remember("scope_y", "key", "value_y")
        self.assertEqual(self.mod.recall("scope_x", "key"), "value_x")
        self.assertEqual(self.mod.recall("scope_y", "key"), "value_y")

    # --- load_config ---

    def test_load_config_missing_file_uses_defaults(self):
        cfg = self.mod.load_config("/nonexistent/path/config.json")
        self.assertEqual(cfg["agent_name"], "AURA")
        self.assertEqual(cfg["version"], "1.1")

    def test_load_config_invalid_json_uses_defaults(self):
        with tempfile.NamedTemporaryFile(
            mode="w", suffix=".json", delete=False
        ) as fh:
            fh.write("{ invalid json }")
            tmppath = fh.name
        try:
            cfg = self.mod.load_config(tmppath)
            self.assertEqual(cfg["agent_name"], "AURA")
        finally:
            os.unlink(tmppath)

    def test_load_config_valid_json_overrides_defaults(self):
        with tempfile.NamedTemporaryFile(
            mode="w", suffix=".json", delete=False
        ) as fh:
            json.dump({"agent_name": "MYAGENT", "version": "9.9"}, fh)
            tmppath = fh.name
        try:
            cfg = self.mod.load_config(tmppath)
            self.assertEqual(cfg["agent_name"], "MYAGENT")
            self.assertEqual(cfg["version"], "9.9")
            # Other keys should still carry defaults
            self.assertIn("db_path", cfg)
        finally:
            os.unlink(tmppath)

    def test_load_config_partial_override_keeps_other_defaults(self):
        with tempfile.NamedTemporaryFile(
            mode="w", suffix=".json", delete=False
        ) as fh:
            json.dump({"agent_name": "PARTIAL"}, fh)
            tmppath = fh.name
        try:
            cfg = self.mod.load_config(tmppath)
            self.assertEqual(cfg["agent_name"], "PARTIAL")
            # version not overridden — should still be the default
            self.assertEqual(cfg["version"], "1.1")
        finally:
            os.unlink(tmppath)


# ===========================================================================
# Entry point
# ===========================================================================

if __name__ == "__main__":
    unittest.main(verbosity=2)
