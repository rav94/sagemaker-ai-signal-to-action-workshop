"""Screen a complaint with Bedrock before calling the workshop SageMaker endpoint."""

import argparse
import json
import os
from pathlib import Path
import re
import subprocess
import sys
from tempfile import TemporaryDirectory


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("complaint", type=Path, help="JSON file containing a message")
    parser.add_argument("--endpoint", default=os.environ.get("WORKSHOP_STACK"))
    args = parser.parse_args()

    guardrail_id = os.environ.get("BEDROCK_GUARDRAIL_ID", "")
    guardrail_version = os.environ.get("BEDROCK_GUARDRAIL_VERSION", "")
    guardrail_region = os.environ.get("BEDROCK_GUARDRAIL_REGION")
    if not args.endpoint:
        parser.error("provide --endpoint or set WORKSHOP_STACK")
    if not guardrail_id or not re.fullmatch(r"[1-9][0-9]{0,7}", guardrail_version):
        parser.error("set BEDROCK_GUARDRAIL_ID and a numbered BEDROCK_GUARDRAIL_VERSION")

    try:
        complaint = json.loads(args.complaint.read_bytes())
    except (OSError, ValueError, RecursionError):
        parser.error("the complaint file must contain valid JSON")
    message = complaint.get("message") if isinstance(complaint, dict) else None
    if not isinstance(message, str) or not message.strip():
        parser.error("message must be a non-empty string")

    with TemporaryDirectory(prefix="workshop-content-check-") as directory:
        files = Path(directory)
        content = files / "guardrail-input.json"
        content.write_text(json.dumps([{"text": {"text": message}}]), encoding="utf-8")
        guardrail_command = [
            "aws", "bedrock-runtime", "apply-guardrail",
            "--guardrail-identifier", guardrail_id,
            "--guardrail-version", guardrail_version,
            "--source", "INPUT",
            "--content", f"file://{content}",
            "--query", "action",
            "--output", "text",
            "--no-cli-pager",
        ]
        if guardrail_region:
            guardrail_command += ["--region", guardrail_region]
        try:
            checked = subprocess.run(
                guardrail_command, check=True, stdout=subprocess.PIPE, text=True
            )
        except (OSError, subprocess.CalledProcessError):
            print("Content check failed. SageMaker was skipped.", file=sys.stderr)
            return 1

        decision = checked.stdout.strip()
        if decision == "GUARDRAIL_INTERVENED":
            print("Content policy intervened. SageMaker was skipped.", file=sys.stderr)
            return 3
        if decision != "NONE":
            print("Unexpected content check result. SageMaker was skipped.", file=sys.stderr)
            return 1

        # Send exactly the message checked above, without reading the fixture a second time.
        screened_request = files / "request.json"
        screened_request.write_text(json.dumps({"message": message}), encoding="utf-8")
        insight = files / "insight.json"
        try:
            subprocess.run(
                [
                    "aws", "sagemaker-runtime", "invoke-endpoint",
                    "--endpoint-name", args.endpoint,
                    "--content-type", "application/json",
                    "--body", f"fileb://{screened_request}",
                    "--no-cli-pager",
                    str(insight),
                ],
                check=True,
                stdout=subprocess.DEVNULL,
            )
            print(insight.read_text(encoding="utf-8"))
        except (OSError, subprocess.CalledProcessError):
            print("SageMaker invocation failed.", file=sys.stderr)
            return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
