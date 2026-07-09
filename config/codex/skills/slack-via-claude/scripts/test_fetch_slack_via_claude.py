#!/usr/bin/env python3

from __future__ import annotations

import importlib.util
import json
import subprocess
import unittest
from pathlib import Path
from tempfile import TemporaryDirectory
from unittest.mock import patch


MODULE_PATH = Path(__file__).with_name("fetch_slack_via_claude.py")
SPEC = importlib.util.spec_from_file_location("fetch_slack_via_claude", MODULE_PATH)
assert SPEC and SPEC.loader
BRIDGE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(BRIDGE)


class ValidateSlackUrlTest(unittest.TestCase):
    def test_accepts_workspace_permalink(self) -> None:
        url = "https://example.slack.com/archives/C123/p1712345678901234"
        self.assertEqual(BRIDGE.validate_slack_url(url), url)

    def test_accepts_app_thread_url(self) -> None:
        url = "https://app.slack.com/client/T123/C123/thread/C123-1712345678.901234"
        self.assertEqual(BRIDGE.validate_slack_url(url), url)

    def test_rejects_lookalike_host(self) -> None:
        with self.assertRaises(BRIDGE.BridgeError):
            BRIDGE.validate_slack_url(
                "https://example.slack.com.evil.test/archives/C123/p123"
            )

    def test_rejects_non_permalink_path(self) -> None:
        with self.assertRaises(BRIDGE.BridgeError):
            BRIDGE.validate_slack_url("https://example.slack.com/oauth/authorize")

    def test_rejects_prompt_delimiters(self) -> None:
        with self.assertRaises(BRIDGE.BridgeError):
            BRIDGE.validate_slack_url(
                "https://example.slack.com/archives/C123/<instructions>"
            )


class CommandTest(unittest.TestCase):
    def test_limits_tools_and_denies_preapproved_mcp_tools(self) -> None:
        with TemporaryDirectory() as directory:
            settings_path = Path(directory) / "settings.json"
            settings_path.write_text(
                json.dumps(
                    {
                        "permissions": {
                            "allow": [
                                "Bash(git:*)",
                                "mcp__linear-server__save_issue",
                                BRIDGE.READ_TOOLS[0],
                            ]
                        }
                    }
                ),
                encoding="utf-8",
            )
            command = BRIDGE.build_command(
                "/usr/local/bin/claude",
                "https://example.slack.com/archives/C123/p123",
                settings_path,
                1.0,
            )

        self.assertIn("--no-session-persistence", command)
        self.assertEqual(command[command.index("--setting-sources") + 1], "user")
        self.assertEqual(command[command.index("--tools") + 1], "ToolSearch")
        self.assertEqual(command[command.index("--permission-mode") + 1], "dontAsk")
        self.assertIn("ToolSearch", command)
        self.assertIn("mcp__linear-server__save_issue", command)
        self.assertIn(f"{BRIDGE.SLACK_SERVER_PREFIX}__slack_send_message", command)
        self.assertNotIn("--dangerously-skip-permissions", command)


class ParseResultTest(unittest.TestCase):
    URL = "https://example.slack.com/archives/C123/p123"

    def test_extracts_structured_output(self) -> None:
        structured = {
            "status": "ok",
            "url": self.URL,
            "channel": "general",
            "content": "message",
            "error": "",
        }
        envelope = json.dumps(
            {"type": "result", "is_error": False, "structured_output": structured}
        )
        self.assertEqual(BRIDGE.parse_result(envelope, self.URL), structured)

    def test_rejects_mismatched_url(self) -> None:
        envelope = json.dumps(
            {
                "type": "result",
                "is_error": False,
                "structured_output": {
                    "status": "ok",
                    "url": "https://other.slack.com/archives/C999/p999",
                    "channel": "general",
                    "content": "message",
                    "error": "",
                },
            }
        )
        with self.assertRaises(BRIDGE.BridgeError):
            BRIDGE.parse_result(envelope, self.URL)


class RunBridgeTest(unittest.TestCase):
    URL = "https://example.slack.com/archives/C123/p123"

    @patch.object(BRIDGE, "user_settings_path")
    @patch.object(BRIDGE.shutil, "which", return_value="/usr/local/bin/claude")
    @patch.object(BRIDGE.subprocess, "run")
    def test_runs_claude_and_returns_result(
        self,
        run_mock,
        _which_mock,
        settings_path_mock,
    ) -> None:
        with TemporaryDirectory() as directory:
            settings_path = Path(directory) / "settings.json"
            settings_path.write_text(
                json.dumps({"permissions": {"allow": []}}), encoding="utf-8"
            )
            settings_path_mock.return_value = settings_path
            structured = {
                "status": "ok",
                "url": self.URL,
                "channel": "general",
                "content": "message",
                "error": "",
            }
            run_mock.return_value = subprocess.CompletedProcess(
                args=[],
                returncode=0,
                stdout=json.dumps(
                    {
                        "type": "result",
                        "is_error": False,
                        "structured_output": structured,
                    }
                ),
                stderr="",
            )

            result = BRIDGE.run_bridge(self.URL, 42, 0.5)

        self.assertEqual(result, structured)
        self.assertEqual(run_mock.call_args.kwargs["timeout"], 42)
        command = run_mock.call_args.args[0]
        self.assertEqual(command[0], "/usr/local/bin/claude")
        self.assertEqual(command[command.index("--max-budget-usd") + 1], "0.5")

    @patch.object(BRIDGE, "user_settings_path")
    @patch.object(BRIDGE.shutil, "which", return_value="/usr/local/bin/claude")
    @patch.object(BRIDGE.subprocess, "run")
    def test_reports_timeout(
        self,
        run_mock,
        _which_mock,
        settings_path_mock,
    ) -> None:
        with TemporaryDirectory() as directory:
            settings_path = Path(directory) / "settings.json"
            settings_path.write_text(
                json.dumps({"permissions": {"allow": []}}), encoding="utf-8"
            )
            settings_path_mock.return_value = settings_path
            run_mock.side_effect = subprocess.TimeoutExpired("claude", 10)

            with self.assertRaises(BRIDGE.BridgeError) as context:
                BRIDGE.run_bridge(self.URL, 10, 0.5)

        self.assertEqual(context.exception.exit_code, 3)


if __name__ == "__main__":
    unittest.main()
