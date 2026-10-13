from types import SimpleNamespace

import pytest

import workflows.flow as workflow
from workflows.__main__ import configure
from workflows.pi import OUTPUTS, PhaseResult


class FakeTask:
    def __init__(self, spec, states):
        self.spec = spec
        self.states = states
        self.calls = []

    def with_options(self, **kwargs):
        return self

    def __call__(self, spec_data, phase, run_id, attempt, answer):
        self.calls.append((phase, attempt, answer))
        state = self.states.get((phase, attempt), "completed")
        if phase == "plan":
            directory = self.spec.directory / "workflow"
            (directory / "plan-reviewed.html").write_bytes((self.spec.directory / "plan.html").read_bytes())
        return PhaseResult(phase=phase, status=state, summary="Fixture only",
                           artifacts=sorted(OUTPUTS[phase]),
                           question="Clarify?" if state == "needs_approval" else None,
                           disposition="adopt" if phase == "act" else None).model_dump()


@pytest.fixture
def flow_context(spec, monkeypatch):
    monkeypatch.setattr(workflow, "get_run_context", lambda: SimpleNamespace(flow_run=SimpleNamespace(id="one")))
    monkeypatch.setattr(workflow, "get_run_logger", lambda: SimpleNamespace(info=lambda *a: None, warning=lambda *a: None))
    monkeypatch.setattr(workflow, "validate_artifacts", lambda *a: None)
    monkeypatch.setattr(workflow, "suspend_flow_run", lambda **kw: workflow.HumanDecision(approved=True, answer="Same scope"))
    fake = FakeTask(spec, {})
    monkeypatch.setattr(workflow, "phase_task", fake)
    return fake


def test_order_and_plan_gate(spec, flow_context, monkeypatch):
    gates = []
    def suspend(**kwargs):
        gates.append((kwargs["key"], list(flow_context.calls)))
        return workflow.HumanDecision(approved=True, answer="Reviewed")
    monkeypatch.setattr(workflow, "suspend_flow_run", suspend)
    result = workflow.pdsa.fn(spec)
    assert list(result) == ["plan", "do", "study", "act"]
    assert [call[0] for call in flow_context.calls] == ["plan", "do", "study", "act"]
    assert len(gates) == 1 and gates[0][0].startswith("plan-review-")
    assert gates[0][1] == [("plan", 1, "")]


def test_denial_stops_before_do(spec, flow_context, monkeypatch):
    monkeypatch.setattr(workflow, "suspend_flow_run", lambda **kw: workflow.HumanDecision(approved=False))
    with pytest.raises(PermissionError):
        workflow.pdsa.fn(spec)
    assert flow_context.calls == [("plan", 1, "")]


def test_blocked_phase_stops_dependents(spec, flow_context):
    flow_context.states[("do", 1)] = "blocked"
    with pytest.raises(RuntimeError, match="do is blocked"):
        workflow.pdsa.fn(spec)
    assert [call[0] for call in flow_context.calls] == ["plan", "do"]


def test_one_clarification_attempt(spec, flow_context):
    flow_context.states[("study", 1)] = "needs_approval"
    workflow.pdsa.fn(spec)
    assert flow_context.calls[2:4] == [("study", 1, ""), ("study", 2, "Same scope")]


def test_repeated_question_is_bounded(spec, flow_context):
    flow_context.states.update({("study", 1): "needs_approval", ("study", 2): "needs_approval"})
    with pytest.raises(RuntimeError, match="study is needs_approval"):
        workflow.pdsa.fn(spec)
    assert len(flow_context.calls) == 4
    assert all(call[0] != "act" for call in flow_context.calls)


def test_plan_changed_during_review_stops_do(spec, flow_context, monkeypatch):
    def suspend(**kwargs):
        (spec.directory / "plan.html").write_text("Changed during review")
        return workflow.HumanDecision(approved=True)
    monkeypatch.setattr(workflow, "suspend_flow_run", suspend)
    with pytest.raises(ValueError, match="Plan changed"):
        workflow.pdsa.fn(spec)
    assert len(flow_context.calls) == 1


def test_validated_do_checklist_hash_is_used_on_replay(spec):
    import json
    from workflows.pi import digest
    directory = spec.directory / "workflow"
    folder = directory / "attempts" / "do-1"
    folder.mkdir(parents=True)
    (directory / "plan-reviewed.html").write_text("original")
    (spec.directory / "plan.html").write_text("checklist updated before a question")
    result = PhaseResult(phase="do", status="needs_approval", summary="Question",
                         question="Continue?", artifacts=["plan.html", "do.md"])
    (folder / "result.json").write_text(result.model_dump_json())
    recorded = digest(spec.directory / "plan.html")
    (folder / "record-hashes.json").write_text(json.dumps({"plan.html": recorded}))
    assert workflow.expected_plan_hash(directory) == recorded
    (spec.directory / "plan.html").write_text("unrecorded drift")
    assert workflow.expected_plan_hash(directory) != digest(spec.directory / "plan.html")


def test_local_configuration_only(monkeypatch):
    monkeypatch.setenv("PREFECT_API_URL", "http://127.0.0.1:4200/api")
    monkeypatch.setenv("PREFECT_API_KEY", "do-not-forward")
    # configure mutates process environment, so preserve it through monkeypatch.
    for name in ("PREFECT_HOME", "PREFECT_PROFILES_PATH", "PREFECT_SERVER_ALLOW_EPHEMERAL_MODE", "PREFECT_SERVER_ANALYTICS_ENABLED"):
        monkeypatch.setenv(name, "before")
    assert configure() == "http://127.0.0.1:4200/api"
    import os
    assert "PREFECT_API_KEY" not in os.environ
    assert ".deming" in os.environ["PREFECT_HOME"]
    monkeypatch.setenv("PREFECT_API_URL", "https://app.prefect.cloud/api")
    with pytest.raises(ValueError, match="loopback"):
        configure()


def test_cli_help_on_windows_encoding():
    import os
    import subprocess
    import sys
    process = subprocess.run([sys.executable, "-m", "workflows", "--help"],
                             env={**os.environ, "PYTHONIOENCODING": "cp1252"}, capture_output=True)
    assert process.returncode == 0
    assert b"submit" in process.stdout


def test_prefect_decorators_disable_retries_and_persist():
    assert workflow.pdsa.retries == 0
    assert workflow.pdsa.persist_result is True
    assert workflow.phase_task.retries == 0
    assert workflow.phase_task.persist_result is True
