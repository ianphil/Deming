"""Run with uv run python -m workflows; all configuration is process-local."""
import argparse
import json
import os
from pathlib import Path
from urllib.parse import urlsplit
from uuid import UUID

from workflows.pi import ROOT, RunSpec, validate_workspace


def configure() -> str:
    api = os.environ.get("PREFECT_API_URL", "http://127.0.0.1:4200/api").rstrip("/")
    url = urlsplit(api)
    if url.hostname not in ("127.0.0.1", "localhost", "::1") or url.scheme not in ("http", "https"):
        raise ValueError("This single-user prototype requires a loopback Prefect API")
    if url.username or url.password:
        raise ValueError("Keep credentials out of the API URL")
    state = ROOT / ".deming" / "prefect-host"
    os.environ.update(PREFECT_API_URL=api, PREFECT_HOME=str(state),
                      PREFECT_PROFILES_PATH=str(state / "profiles.toml"),
                      PREFECT_SERVER_ALLOW_EPHEMERAL_MODE="false",
                      PREFECT_SERVER_ANALYTICS_ENABLED="false")
    os.environ.pop("PREFECT_API_KEY", None)
    return api


def main():
    parser = argparse.ArgumentParser(description="Local Prefect / headless Pi PDSA prototype")
    sub = parser.add_subparsers(dest="command", required=True)
    sub.add_parser("serve", help="Serve deming-pdsa/local, one run at a time; Ctrl+C stops")
    submit = sub.add_parser("submit", help="Start a prepared cycle whose scope you have confirmed")
    submit.add_argument("--cycle", required=True, type=Path)
    submit.add_argument("--request-file", required=True, type=Path)
    submit.add_argument("--scope-confirmed", required=True, action="store_true")
    submit.add_argument("--model", default="gpt-6.1-sol")
    submit.add_argument("--deming-dir", type=Path, default=ROOT)
    submit.add_argument("--timeout-seconds", type=int, default=600)
    submit.add_argument("--auth-file", type=Path, help="Existing Pi auth.json; only Copilot entry is staged")
    status = sub.add_parser("status", help="Read run state")
    status.add_argument("run_id", type=UUID)
    resume = sub.add_parser("resume", help="Answer the current approval form for the same run")
    resume.add_argument("run_id", type=UUID)
    choice = resume.add_mutually_exclusive_group(required=True)
    choice.add_argument("--approve", action="store_true")
    choice.add_argument("--deny", action="store_true")
    resume.add_argument("--answer", default="")
    args = parser.parse_args()
    api = configure()  # Before importing Prefect: don't read/write the interactive Prefect profile.
    from prefect.client.orchestration import get_client
    from prefect.deployments import run_deployment
    from prefect.flow_runs import resume_flow_run
    from workflows.flow import pdsa

    if args.command == "serve":
        pdsa.serve(name="local", limit=1, global_limit=1, pause_on_shutdown=False)
    elif args.command == "submit":
        spec = RunSpec(cycle=str(args.cycle.resolve()),
                       request=args.request_file.read_text(encoding="utf-8"),
                       scope_confirmed=args.scope_confirmed, model=args.model,
                       deming_dir=str(args.deming_dir.resolve()), timeout_seconds=args.timeout_seconds,
                       auth_file=str(args.auth_file.resolve()) if args.auth_file else None)
        validate_workspace(spec)
        if (spec.directory / "workflow" / "owner.json").exists():
            parser.error("Cycle already belongs to a run; inspect owner.json and resume that run")
        run = run_deployment("deming-pdsa/local", parameters={"spec": spec.model_dump()}, timeout=0)
        print(f"Run: {run.id}\nUI: {api.removesuffix('/api')}/runs/flow-run/{run.id}")
    elif args.command == "resume":
        resume_flow_run(args.run_id, run_input={"approved": args.approve, "answer": args.answer})
        print("Resume requested for the existing run; check its state before assuming completion.")
    elif args.command == "status":
        with get_client(sync_client=True) as client:
            run = client.read_flow_run(args.run_id)
        print(json.dumps({"id": str(run.id), "name": run.name, "state": run.state_name,
                          "message": run.state.message if run.state else None}, indent=2))


if __name__ == "__main__":
    main()
