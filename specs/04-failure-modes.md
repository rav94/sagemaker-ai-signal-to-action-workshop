# Failure modes

| Incident | Observable result | Response |
|---|---|---|
| Training or Processing job fails | Pipeline execution fails before registration | Inspect the failed step, underlying job failure reason, and CloudWatch logs. Verify quotas, image, S3 access, and the job role. |
| Billing recall misses the gate | `RejectBelowThreshold` fails the execution. It creates no candidate. | Compare the S3 report's recall and billing count with the execution parameter. |
| GitHub IAM setup cannot configure the provider or STS rejects the subject | IAM setup or workflow authentication fails before promotion | Check the teaching profile's IAM permissions, provider audience, and exact GitHub repository subject on `main`. [GitHub Actions setup](../docs/model-registry-ci-cd.md#github-actions-setup) |
| Approval or package status blocks promotion | Deploy helper exits `3` without changing the endpoint | Check the exact versioned ARN. Review pending packages and promote only an `Approved`, `Completed` package. |
| Model archive or serving image is invalid | The helper rejects out-of-scope locations, or the endpoint fails its health check | Inspect the approved package, CloudFormation events, and endpoint logs. Verify the archive layout and image digest. |
| Unexpected inference version | Promotion smoke test fails after invocation | Compare the package's `ReleaseVersion` and registered assets against the deployed model and returned `modelVersion`. |
| Candidate alarm trips during the rollback drill | CloudFormation rolls back the update. The workflow checks the alarm, the original endpoint configuration, and the original `modelVersion`. | Require `UPDATE_ROLLBACK_COMPLETE` and a successful baseline invocation. |
| Candidate deploys without the expected alarm | The drill fails and the candidate can remain live. | Inspect the endpoint version and alarm history. Restore the baseline by dispatching its approved package with the drill unchecked. |
| Shared guardrail intervenes | The screening caller exits `3` before invoking SageMaker | Use the synthetic email fixture to demonstrate this expected outcome. |
| Shared guardrail call fails or returns an unexpected action | The screening caller exits `1` before invoking SageMaker | Check the published version, Bedrock Region, and caller IAM. [Screening setup](../docs/guardrails.md#reference-the-bedrock-guardrail) |
| Wrong content type or malformed message on direct invocation | Container returns HTTP 415 or 400. SageMaker Runtime reports `ModelError` with the original container status. | Inspect the original status and stop before the action stage. |
| Invocation unavailable or denied | Runtime call fails | Inspect endpoint state and caller IAM. No insight is available for routing. |
| Low score | Valid insight with score below policy threshold | Route to simulated review. |

[Workshop troubleshooting](../docs/troubleshooting.md)
