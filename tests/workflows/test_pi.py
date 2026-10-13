import json
from pathlib import Path
import subprocess
import time

import psutil
import pytest
from pydantic import ValidationError

from workflows.pi import (PhaseResult, RunSpec, bind_run, execute_phase, isolated_profile,
                          validate_artifacts, validate_workspace)


def test_success_profile_isolation_and_no_replay(spec, monkeypatch):
    monkeypatch.setenv("OPENAI_API_KEY", "must-not-inherit")
    monkeypatch.setenv("PI_SESSION_ID", "parent-session")
    source_before = Path(spec.auth_file).read_bytes()
    result = execute_phase(spec, "study", "run-1")
    assert result["status"] == "completed"
    attempt = spec.directory / "workflow/attempts/study-1"
    observation = json.loads((attempt / "profile-observation.json").read_text())
    assert observation["providers"] == ["github-copilot"]
    assert observation["settings"]["defaultModel"] == "gpt-6.1-sol"
    assert observation["settings"]["retry"]["enabled"] is False
    assert not observation["unrelated_key_present"]
    assert not observation["parent_session_present"]
    assert not Path(observation["path"]).exists()
    assert Path(spec.auth_file).read_bytes() == source_before
    for path in attempt.rglob("*"):
        if path.is_file():
            assert b"fixture-secret" not in path.read_bytes()
    command = json.loads((attempt / "process.json").read_text())["command"]
    for flag in ("--no-context-files", "--no-extensions", "--no-skills", "--no-approve"):
        assert flag in command
    with pytest.raises(ValueError, match="Attempt already exists"):
        execute_phase(spec, "study", "run-1")


@pytest.mark.parametrize("mode,match", [
    ("error", "assistant error"), ("malformed", "Malformed"),
    ("no-settled", "settled"), ("truncated", "Truncated"),
    ("nonzero", "code 7"), ("wrong-phase", "wrong phase"),
    ("wrong-model", "unexpected provider or model"), ("bad-result", "schema"),
    ("missing-file", "Missing cycle scaffold"), ("pending-file", "pending artifact"),
    ("outside-artifact", "within the cycle"), ("cross-phase", "another phase"),
])
def test_invalid_subprocess_results_fail_closed(spec, mode, match):
    spec.pi_command[-1] = mode
    with pytest.raises(ValueError, match=match):
        execute_phase(spec, "study", "run-1")
    attempt = spec.directory / "workflow/attempts/study-1"
    assert (attempt / "failure.json").exists()
    assert not (attempt / "result.json").exists()
    observation = json.loads((attempt / "profile-observation.json").read_text())
    assert not Path(observation["path"]).exists()


@pytest.mark.parametrize("mode", ["blocked", "question"])
def test_noncompleted_outcomes_are_explicit(spec, mode):
    spec.pi_command[-1] = mode
    result = execute_phase(spec, "study", "run-1")
    assert result["status"] == ("needs_approval" if mode == "question" else "blocked")


def test_timeout_kills_parent_and_child_and_retains_guard(spec):
    spec.pi_command[-1] = "timeout"
    spec.timeout_seconds = 1
    with pytest.raises(TimeoutError):
        execute_phase(spec, "study", "run-1")
    attempt = spec.directory / "workflow/attempts/study-1"
    parent = json.loads((attempt / "process.json").read_text())["pid"]
    child = int((attempt / "child-pid.txt").read_text())
    time.sleep(0.2)
    assert not psutil.pid_exists(parent)
    assert not psutil.pid_exists(child)
    with pytest.raises(ValueError, match="Attempt already exists"):
        execute_phase(spec, "study", "run-1")


def test_run_binding_rejects_competitors_changed_request_and_branch(spec):
    bind_run(spec, "one")
    bind_run(spec, "one")
    with pytest.raises(ValueError, match="another run"):
        bind_run(spec, "two")
    changed = spec.model_copy(update={"request": "different"})
    with pytest.raises(ValueError, match="changed inputs"):
        bind_run(changed, "one")
    subprocess.run(["git", "-C", str(spec.repo), "switch", "main"], check=True, capture_output=True)
    with pytest.raises(ValueError, match="branch"):
        validate_workspace(spec)


def test_credentials_environment_and_cleanup(spec, monkeypatch):
    monkeypatch.setenv("COPILOT_GITHUB_TOKEN", "environment-fixture-secret")
    spec.auth_file = "does-not-exist"
    with isolated_profile(spec) as env:
        path = Path(env["PI_CODING_AGENT_DIR"])
        assert env["COPILOT_GITHUB_TOKEN"] == "environment-fixture-secret"
        assert not (path / "auth.json").exists()
    assert not path.exists()


def test_missing_credentials_and_wrong_profile_are_clear(spec):
    Path(spec.auth_file).write_text("{}")
    with pytest.raises(ValueError, match="no github-copilot"):
        with isolated_profile(spec):
            pass


def test_output_limit(spec, monkeypatch):
    monkeypatch.setattr("workflows.pi.MAX_OUTPUT", 10)
    with pytest.raises(ValueError, match="output exceeded"):
        execute_phase(spec, "study", "run-1")


def test_process_is_stopped_if_metadata_write_fails(spec, monkeypatch):
    import workflows.pi as adapter
    original_spawn = adapter.subprocess.Popen
    original_write = adapter.write_json
    processes = []
    def spawn(*args, **kwargs):
        process = original_spawn(*args, **kwargs)
        if kwargs.get("stdin") is not None:
            processes.append(process)
        return process
    def fail_metadata(path, value):
        if path.name == "process.json":
            raise OSError("fixture disk write failure")
        original_write(path, value)
    monkeypatch.setattr(adapter.subprocess, "Popen", spawn)
    monkeypatch.setattr(adapter, "write_json", fail_metadata)
    with pytest.raises(OSError, match="disk write"):
        execute_phase(spec, "study", "run-1")
    assert len(processes) == 1
    assert processes[0].poll() is not None


def test_attempt_bound_requires_answer(spec):
    with pytest.raises(ValueError, match="explicit human input"):
        execute_phase(spec, "study", "run-1", attempt_number=2)
    with pytest.raises(ValueError, match="attempt bound"):
        execute_phase(spec, "study", "run-1", attempt_number=3)


def test_result_and_scope_contract():
    with pytest.raises(ValidationError):
        RunSpec(cycle="anything", request="task", scope_confirmed=False)
    with pytest.raises(ValidationError):
        PhaseResult(phase="study", status="needs_approval", summary="Question", artifacts=[])
    with pytest.raises(ValidationError):
        PhaseResult(phase="act", status="completed", summary="Done", artifacts=["act.md"])


def test_artifact_references_required(spec):
    result = PhaseResult(phase="study", status="completed", summary="Done", artifacts=[])
    with pytest.raises(ValueError, match="artifact references"):
        validate_artifacts(spec, result)


def test_real_html_validator_rejects_invalid_plan(spec):
    bind_run(spec, "one")
    (spec.directory / "plan.html").write_text("<html>not a real plan</html>")
    result = PhaseResult(phase="plan", status="completed", summary="Done", artifacts=["plan.html"])
    with pytest.raises(ValueError, match="structural validation"):
        validate_artifacts(spec, result)
