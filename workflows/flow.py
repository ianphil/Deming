"""One PDSA workflow, using Prefect's native tasks, caching and suspension."""
import json
from pathlib import Path

from prefect import flow, get_run_logger, task
from prefect.context import get_run_context
from prefect.flow_runs import suspend_flow_run
from prefect.input import RunInput
from pydantic import Field

from workflows.pi import (PHASES, PhaseResult, RunSpec, bind_run, digest, execute_phase,
                          validate_artifacts, write_json)


class HumanDecision(RunInput):
    approved: bool = Field(description="Continue only the existing local scope? False stops the run.")
    answer: str = Field(default="", max_length=4000,
                        description="Answer the question or record a review note. Never enter credentials.")


@task(name="pi-phase", retries=0, persist_result=True, result_serializer="json")
def phase_task(spec_data: dict, phase: str, run_id: str, attempt: int, answer: str) -> dict:
    spec = RunSpec.model_validate(spec_data)
    result = execute_phase(spec, phase, run_id, attempt, answer)
    if phase == "plan" and result["status"] == "completed":
        snapshot = spec.directory / "workflow" / "plan-reviewed.html"
        with snapshot.open("xb") as output:
            output.write((spec.directory / "plan.html").read_bytes())
    return result


def ask(key: str, description: str) -> HumanDecision:
    decision = suspend_flow_run(
        wait_for_input=HumanDecision.with_initial_data(description=description),
        key=key, timeout=86400,
    )
    if not decision.approved:
        raise PermissionError("Human declined continuation; dependent work was not started")
    return decision


def expected_plan_hash(directory: Path) -> str:
    # A validated Do attempt may update the checklist before asking a question.
    # Use its recorded hash on replay; an interrupted attempt has no accepted result.
    for attempt in (2, 1):
        folder = directory / "attempts" / f"do-{attempt}"
        result = folder / "result.json"
        if result.exists():
            if PhaseResult.model_validate_json(result.read_bytes()).phase != "do":
                raise ValueError("Invalid Do evidence")
            return json.loads((folder / "record-hashes.json").read_text(encoding="utf-8"))["plan.html"]
    return digest(directory / "plan-reviewed.html")


@flow(name="deming-pdsa", retries=0, persist_result=True, result_serializer="json")
def pdsa(spec: RunSpec) -> dict:
    """Execute an existing, scope-confirmed cycle; pause for local review after Plan."""
    run_id = str(get_run_context().flow_run.id)
    directory = bind_run(spec, run_id)
    logger = get_run_logger()
    results = {}
    for phase in PHASES:
        bind_run(spec, run_id)  # Also executes on replay, outside the cached task.
        run = phase_task.with_options(name=phase.title(), task_run_name=f"{phase}-attempt-1",
                                      result_storage=directory / "prefect-results")
        result = PhaseResult.model_validate(run(spec.model_dump(), phase, run_id, 1, ""))
        if result.status == "needs_approval":
            logger.warning("%s needs input; inspect its local result.json and the resume form", phase)
            decision = ask(f"question-{phase}", result.question)
            if not decision.answer.strip():
                raise ValueError("Clarification requires a nonempty answer")
            run = phase_task.with_options(name=phase.title(), task_run_name=f"{phase}-attempt-2",
                                          result_storage=directory / "prefect-results")
            result = PhaseResult.model_validate(run(spec.model_dump(), phase, run_id, 2, decision.answer))
        if result.status != "completed":
            raise RuntimeError(f"{phase} is {result.status}; inspect local evidence. Automatic retries are disabled.")
        if result.phase != phase:
            raise ValueError("Cached result does not match the current phase")
        validate_artifacts(spec, result)  # File checks are not bypassed by task caching.
        results[phase] = result.model_dump()
        logger.info("%s complete: %s", phase, result.summary)
        if phase == "plan":
            snapshot = directory / "plan-reviewed.html"
            plan_hash = digest(snapshot)
            decision = ask(f"plan-review-{plan_hash}",
                           f"Review `{spec.directory / 'plan.html'}` on the host. "
                           f"Plan SHA-256: `{plan_hash}`. Approval permits Do within the confirmed "
                           "local scope only; it never grants publication or installation permission.")
            # Before Do, this is exactly the reviewed plan. Later replays accept only
            # checklist changes recorded by a validated Do attempt, not arbitrary drift.
            if digest(spec.directory / "plan.html") != expected_plan_hash(directory):
                raise ValueError("Plan changed since review; inspect it before executing Do")
            write_json(directory / "approval.json", {"plan_sha256": plan_hash, **decision.model_dump()})
    write_json(directory / "outcome.json", results)
    return results
