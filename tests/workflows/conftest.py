import json
from pathlib import Path
import subprocess
import sys

import pytest

from workflows.pi import RECORDS, RunSpec


@pytest.fixture
def spec(tmp_path, monkeypatch):
    repo = tmp_path / "repo with spaces"
    repo.mkdir()
    def git(*args):
        subprocess.run(["git", "-C", str(repo), "-c", "user.name=Fixture",
                        "-c", "user.email=fixture@example.invalid", "-c", "commit.gpgsign=false",
                        "-c", "core.hooksPath=NUL" if sys.platform == "win32" else "core.hooksPath=/dev/null",
                        *args], check=True, capture_output=True)
    git("init", "-b", "main")
    (repo / "README.md").write_text("# Fixture\n", encoding="utf-8")
    (repo / ".gitignore").write_text("/.deming/\n", encoding="utf-8")
    git("add", ".")
    git("commit", "-m", "Fixture baseline")
    git("switch", "-c", "deming/001-test")
    cycle = repo / ".deming" / "cycles" / "001-test"
    cycle.mkdir(parents=True)
    for name in RECORDS.values():
        (cycle / name).write_text("Status: pending\n", encoding="utf-8")
    auth = tmp_path / "auth.json"
    auth.write_text(json.dumps({"github-copilot": {"type": "api_key", "key": "fixture-secret"},
                                "other": {"key": "unrelated-secret"}}), encoding="utf-8")
    monkeypatch.delenv("COPILOT_GITHUB_TOKEN", raising=False)
    return RunSpec(cycle=str(cycle), request="One local fixture change", scope_confirmed=True,
                   auth_file=str(auth), timeout_seconds=5,
                   pi_command=[sys.executable, str(Path(__file__).with_name("fake_pi.py")), "success"])
