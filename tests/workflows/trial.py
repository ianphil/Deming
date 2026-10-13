"""Opt-in runtime evidence. `start` stops at review; `finish` requires explicit approval.

Uses the real local Prefect server. Fake Pi is the default; --live consumes Copilot
allowance and edits only a new scratch repository. Never deletes repositories.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import time
from uuid import UUID

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))
from workflows.__main__ import configure
configure()
from prefect.client.orchestration import get_client
from prefect.client.schemas.filters import FlowRunFilter, FlowRunFilterId
from prefect.flow_runs import resume_flow_run
from workflows.pi import RunSpec, stop_process_tree, write_json

REQUEST = """This is the pre-authorized scratch-only workflow trial. Append exactly one new paragraph
'Workflow trial verified.' to README.md, preserving its existing heading and text. Only README.md
and the existing ignored cycle records may change. This scope and PDSA are confirmed. The cycle
is already set up on its task branch. Use a minimal HTML plan without diagrams. Validate the
README with installed PowerShell. No package installation, network operations, publishing,
application commits or global configuration changes. Record visual-review limitations honestly.
The host operator will inspect the plan at the Prefect review pause before continuing.
"""


def config_hashes():
    root = Path(os.environ.get("PI_CODING_AGENT_DIR", str(Path.home() / ".pi" / "agent")))
    names = ("settings.json", "auth.json", "models.json", "AGENTS.md", "APPEND_SYSTEM.md", "SYSTEM.md", "mcp.json")
    return {name: hashlib.sha256((root / name).read_bytes()).hexdigest() if (root / name).is_file() else None
            for name in names}


def start_worker(evidence, label):
    stream = (evidence / f"worker-{label}.log").open("wb")
    process = subprocess.Popen([sys.executable, "-m", "workflows", "serve"], cwd=ROOT,
                               stdout=stream, stderr=subprocess.STDOUT,
                               start_new_session=os.name != "nt")
    stream.close()
    deadline = time.monotonic() + 90
    while time.monotonic() < deadline:
        if process.poll() is not None:
            raise RuntimeError(f"Worker exited; inspect worker-{label}.log")
        try:
            with get_client(sync_client=True) as client:
                deployment = client.read_deployment_by_name("deming-pdsa/local")
            time.sleep(3)
            return process, deployment
        except Exception:
            time.sleep(1)
    stop_process_tree(process)
    raise TimeoutError("Deployment did not become available")


def wait_state(run_id, expected, seconds):
    deadline = time.monotonic() + seconds
    while time.monotonic() < deadline:
        with get_client(sync_client=True) as client:
            run = client.read_flow_run(run_id)
        if run.state_name in expected:
            return run
        if run.state and run.state.is_final():
            raise RuntimeError(f"Unexpected terminal state: {run.state_name}; inspect Prefect and local evidence")
        time.sleep(2)
    raise TimeoutError(f"Run did not reach {expected}; inspect state before intervening")


def record_run(evidence, run_id, label):
    with get_client(sync_client=True) as client:
        run = client.read_flow_run(run_id)
        tasks = client.read_task_runs(flow_run_filter=FlowRunFilter(id=FlowRunFilterId(any_=[run_id])))
    write_json(evidence / f"run-{label}.json", run.model_dump(mode="json"))
    write_json(evidence / f"tasks-{label}.json", [task.model_dump(mode="json") for task in tasks])


def start(evidence, live):
    evidence.mkdir(parents=True, exist_ok=False)
    repo = Path(tempfile.mkdtemp(prefix="deming-pdsa-trial-"))
    def git(*args):
        subprocess.run(["git", "-C", str(repo), "-c", "user.name=Deming Trial",
                        "-c", "user.email=trial@example.invalid", "-c", "commit.gpgsign=false",
                        "-c", "core.hooksPath=NUL" if os.name == "nt" else "core.hooksPath=/dev/null",
                        *args], check=True, capture_output=True)
    git("init", "-b", "main")
    (repo / "README.md").write_text("# Workflow trial\n\nA disposable local fixture.\n", encoding="utf-8")
    (repo / ".gitignore").write_text("/.deming/\n", encoding="utf-8")
    git("add", ".")
    git("commit", "-m", "Trial baseline")
    shell = shutil.which("pwsh") or shutil.which("powershell")
    with (evidence / "setup.log").open("wb") as output:
        subprocess.run([shell, "-NoProfile", "-ExecutionPolicy", "Bypass", "-File",
                        str(ROOT / "scripts/start-cycle.ps1"), "-Repo", str(repo), "-Name", "workflow-trial"],
                       check=True, stdout=output, stderr=subprocess.STDOUT)
    cycle = repo / ".deming/cycles/001-workflow-trial"
    spec = RunSpec(cycle=str(cycle), request=REQUEST, scope_confirmed=True)
    if not live:
        auth = evidence / "fake-auth.json"
        write_json(auth, {"github-copilot": {"type": "api_key", "key": "fixture-not-a-credential"}})
        spec.auth_file = str(auth)
        spec.pi_command = [sys.executable, str(Path(__file__).with_name("fake_pi.py")), "success"]
    write_json(evidence / "config-before.json", config_hashes())
    write_json(evidence / "trial.json", {"live": live, "repo": str(repo), "cycle": str(cycle), "spec": spec.model_dump()})
    worker, deployment = start_worker(evidence, "before-review")
    try:
        with get_client(sync_client=True) as client:
            run = client.create_flow_run_from_deployment(deployment.id, parameters={"spec": spec.model_dump()})
        metadata = json.loads((evidence / "trial.json").read_text(encoding="utf-8"))
        metadata["run_id"] = str(run.id)
        write_json(evidence / "trial.json", metadata)
        print(f"Run: {run.id}\nReview: {cycle / 'plan.html'}", flush=True)
        wait_state(run.id, {"Suspended"}, 780)
        record_run(evidence, run.id, "suspended")
        time.sleep(3)  # Let the suspended flow subprocess close before stopping the server-side poller.
    finally:
        stop_process_tree(worker)
    print("Suspended; serving process stopped. Inspect the plan before invoking finish.", flush=True)


def finish(evidence, review_note):
    metadata = json.loads((evidence / "trial.json").read_text(encoding="utf-8"))
    run_id = UUID(metadata["run_id"])
    worker, _ = start_worker(evidence, "after-review")
    try:
        resume_flow_run(run_id, run_input={"approved": True,
                        "answer": review_note})
        state = wait_state(run_id, {"Completed", "Suspended"}, 2100)
        record_run(evidence, run_id, "completed" if state.state_name == "Completed" else "needs-input")
        if state.state_name != "Completed":
            raise RuntimeError("Another human input is required; inspect the question and resume this same run")
        cycle = Path(metadata["cycle"])
        attempts = sorted(path.name for path in (cycle / "workflow/attempts").iterdir())
        assert attempts == ["act-1", "do-1", "plan-1", "study-1"], attempts
        if metadata["live"]:
            readme = (Path(metadata["repo"]) / "README.md").read_text(encoding="utf-8")
            assert readme.count("Workflow trial verified.") == 1
            assert readme.startswith("# Workflow trial\n\nA disposable local fixture.\n")
        before = json.loads((evidence / "config-before.json").read_text())
        after = config_hashes()
        write_json(evidence / "config-after.json", after)
        assert before == after, "Interactive Pi configuration changed"
        write_json(evidence / "checks.json", {"state": "Completed", "attempts": attempts,
                   "interactive_config_unchanged": True, "real_model": metadata["live"]})
    finally:
        stop_process_tree(worker)
    print("Completed. Single Plan attempt across host restart; interactive config unchanged.", flush=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mode", choices=["start", "finish"])
    parser.add_argument("--evidence", type=Path, required=True)
    parser.add_argument("--live", action="store_true", help="Spend Copilot allowance in one new scratch repository")
    parser.add_argument("--approve-reviewed-plan", action="store_true")
    parser.add_argument("--review-note", default="Operator reviewed the bounded, pre-authorized scratch trial plan. No expanded permissions.")
    args = parser.parse_args()
    if args.mode == "finish" and not args.approve_reviewed_plan:
        parser.error("Inspect the saved plan, then explicitly pass --approve-reviewed-plan")
    if args.mode == "start":
        start(args.evidence.resolve(), args.live)
    else:
        finish(args.evidence.resolve(), args.review_note)
