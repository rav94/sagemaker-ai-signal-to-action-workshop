# Release and content safeguards

The workshop demonstrates two controls on the same SageMaker inference workflow. The deployment policy governs a release update. The guarded caller governs whether complaint text proceeds to inference.

## SageMaker deployment guardrails

| Contract | Expected behavior |
|---|---|
| Baseline | Existing workshop stack and endpoint in `InService`. Record the current endpoint configuration and inference `modelVersion`. |
| Entry point | `bash scripts/guarded-update.sh CANDIDATE_VERSION LATENCY_THRESHOLD_US` with an explicit teaching account and stack. |
| Candidate inputs | Fresh archive in S3. The update reuses the serving image digest and instance type already configured on the stack. The serving role retains read access to the baseline artifact during the update. |
| Deployment policy | CloudFormation enables an `ALL_AT_ONCE` blue/green update on the existing endpoint with a 300-second monitoring window. A standard deploy sets `EnableDeploymentGuardrails=false`. |
| Alarm | Average `AWS/SageMaker` `ModelLatency` in microseconds, scoped to the endpoint, the `AllTraffic` variant, and the candidate endpoint configuration. One 60-second datapoint above threshold enters `ALARM`. Missing data is treated as non-breaching. |
| Rollback evidence | CloudWatch history records `ALARM` during the update. The same endpoint is eventually `InService` with the baseline configuration, and a fresh inference returns the baseline `modelVersion`. |

The drill uses an intentionally low threshold and sends probe requests during the monitoring window. A failed stack update alone does not satisfy the rollback acceptance criteria. [Guarded update lab](../docs/guardrails.md#1-protect-a-sagemaker-endpoint-update) · [AWS auto-rollback configuration](https://docs.aws.amazon.com/sagemaker/latest/dg/deployment-guardrails-configuration.html)

## Bedrock content check before inference

The caller reads a non-blank `message` from the request JSON once. It passes the text to `bedrock-runtime apply-guardrail` with source `INPUT`, a guardrail ID, and a published numeric version. It uses `WORKSHOP_STACK` or an explicit endpoint argument and supports a separate guardrail region. The caller identity needs `bedrock:ApplyGuardrail` and `sagemaker:InvokeEndpoint`.

| Result | Endpoint call | CLI result |
|---|---|---|
| `NONE` and inference succeeds | Sends the same checked message | Inference JSON on stdout, exit `0` |
| `GUARDRAIL_INTERVENED` | Skipped, including a masking intervention | Diagnostic on stderr, exit `3` |
| Guardrail API failure or unexpected action | Skipped | Diagnostic on stderr, exit `1` |
| Missing configuration or invalid request JSON or message | Skipped before the content check | Argument error, exit `2` |
| Inference failure after clearance | Attempted | Diagnostic on stderr, exit `1` |

The application routing threshold remains part of the [inference and decision contracts](02-inference-contract.md). See the [content check lab](../docs/guardrails.md#2-use-bedrock-applyguardrail-in-front-of-sagemaker) for the normal and synthetic email cases. [AWS ApplyGuardrail](https://docs.aws.amazon.com/bedrock/latest/APIReference/API_runtime_ApplyGuardrail.html)
