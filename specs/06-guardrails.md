# Complaint content screening contract

The caller-side exercise runs after the [registered release](07-registry-release.md) is deployed. The Bedrock workshop owns and versions the guardrail. The caller reads `BEDROCK_GUARDRAIL_ID` and `BEDROCK_GUARDRAIL_VERSION` from the environment. Use a numbered version from the Bedrock stack's outputs. An optional `BEDROCK_GUARDRAIL_REGION` overrides the Region for this call alone.

The caller checks the complaint's non-blank `message` using Bedrock Runtime `ApplyGuardrail` with `source=INPUT`. If the API returns `NONE`, the caller sends exactly that message under the [inference contract](02-inference-contract.md), and prints the endpoint response on success.

| Outcome | Caller behavior |
|---|---|
| `NONE` and successful inference | Print the inference JSON to stdout and exit `0`. |
| `GUARDRAIL_INTERVENED`, including masking | Skip SageMaker, report the intervention on stderr, and exit `3`. |
| Guardrail API or unexpected response error | Skip SageMaker, report the check failure on stderr, and exit `1`. |
| Missing configuration or invalid fixture | Exit `2` before making either AWS call. |
| SageMaker invocation failure after clearance | Report the inference failure on stderr and exit `1`. |

The [screening lab](../docs/guardrails.md) uses a synthetic email fixture to exercise the shared guardrail's masking policy. The [endpoint rollback drill](07-registry-release.md#rollback-drill) exercises SageMaker deployment guardrails separately.
