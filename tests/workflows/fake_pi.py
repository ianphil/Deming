"""Subprocess fixture: never contacts a model or imports the production adapter."""
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import time

sys.stdin.reconfigure(encoding="utf-8")
sys.stdout.reconfigure(encoding="utf-8")
mode = sys.argv[1]
context = json.loads(sys.stdin.read().split("\n", 1)[1])
cycle = Path(context["cycle"])
attempt = Path(sys.argv[sys.argv.index("--session-dir") + 1]).parent
profile = Path(os.environ["PI_CODING_AGENT_DIR"])
auth = profile / "auth.json"
(attempt / "profile-observation.json").write_text(json.dumps({
    "path": str(profile),
    "providers": list(json.loads(auth.read_text()) if auth.exists() else {}),
    "settings": json.loads((profile / "settings.json").read_text()),
    "unrelated_key_present": "OPENAI_API_KEY" in os.environ,
    "parent_session_present": "PI_SESSION_ID" in os.environ,
}), encoding="utf-8")
if mode == "timeout":
    child = subprocess.Popen([sys.executable, "-c", "import time; time.sleep(120)"])
    (attempt / "child-pid.txt").write_text(str(child.pid))
    time.sleep(120)
if mode == "nonzero":
    sys.exit(7)
if mode == "malformed":
    print("not JSON")
    sys.exit(0)
phase = context["phase"]
for name in context["required_artifacts"]:
    if mode != "missing-file":
        text = "Status: pending\n" if mode == "pending-file" else "# Evidence\nStatus: completed\n"
        if name == "plan.html" and mode != "pending-file":
            if phase == "plan":
                template = Path(__file__).resolve().parents[2] / "templates" / "plan.html"
                text = re.sub(r"\{\{.*?\}\}", "Fixture", template.read_text(encoding="utf-8"))
                text = re.sub(r"<!--.*?-->", "", text, flags=re.S).replace("Status: pending", "Status: ready")
            else:
                text = (cycle / name).read_text(encoding="utf-8").replace("Status: ready", "Status: executed")
        (cycle / name).write_text(text, encoding="utf-8")
    else:
        (cycle / name).unlink(missing_ok=True)
if mode == "cross-phase":
    (cycle / "do.md").write_text("changed by study", encoding="utf-8")
result = {
    "phase": "do" if mode == "wrong-phase" else phase,
    "status": "needs_approval" if mode == "question" else "blocked" if mode == "blocked" else "completed",
    "summary": "Fixture result with unicode separator \u2028 preserved",
    "artifacts": ["../../../README.md"] if mode == "outside-artifact" else context["required_artifacts"],
}
if phase == "act":
    result["disposition"] = "adopt"
if mode == "question":
    result["question"] = "May I continue this same scope?"
if mode == "bad-result":
    result["unexpected"] = "field"
print(json.dumps({"type": "session", "id": "fixture"}))
print(json.dumps({"type": "agent_start"}))
print(json.dumps({"type": "message_end", "message": {
    "role": "assistant", "stopReason": "error" if mode == "error" else "stop",
    "provider": "github-copilot", "model": "other" if mode == "wrong-model" else "gpt-6.1-sol",
    "content": [{"type": "text", "text": json.dumps(result, ensure_ascii=False)}],
}}, ensure_ascii=False))
if mode != "no-settled":
    print(json.dumps({"type": "agent_settled"}), end="" if mode == "truncated" else "\n")
