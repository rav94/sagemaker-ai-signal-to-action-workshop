# Instructor guide

## Before class

- Confirm the teaching account and the training, Processing, and endpoint quotas.
- Pre-stage a [completed pipeline execution](sagemaker-pipeline.md) and its evaluation report. A completed failed-gate execution is optional.
- Deploy one shared endpoint and check that it is `InService`. Run the normal, ambiguous, and malformed fixtures using the participant identity.
- Save a normal response and a rejected invocation for fallback. Verify the local README path.
- Pre-stage a pending model package and rehearse the [registry and CI/CD lab](model-registry-ci-cd.md). Record the blocked promotion and the approved release's version.
- Rehearse the guarded endpoint update and the standalone content check. Capture the alarm and restored baseline version, and verify the allowed and screened-out requests.
- Open the [training and inference diagrams](architecture/README.md), the training job logs, endpoint metrics, and the Bedrock companion repo.

## SageMaker teaching sequence

1. Show the training split and the fitted preprocessing inside the pipeline. The dataset contains 48 training and 16 test examples with the checked-in split. Ask what four test cases per class can tell you.
2. Open the pipeline graph. Trace the training artifact, the held-out evaluation, and the billing recall gate. If you ran the optional stricter execution, show where it stopped.
3. Show one pending package being blocked, then approve and promote it. Verify the model version by invoking the endpoint.
4. Explain Model, EndpointConfig, and Endpoint using the deployed resources. Send a malformed case and inspect its container error.
5. Run the [guardrails lab](guardrails.md). Show the candidate alarm and endpoint rollback. Then pre-screen two requests with Bedrock ApplyGuardrail and compare the outcomes. Ask what would trigger a quality rollback if latency stays healthy while real complaint classification worsens.
6. Give the same complaint text to the existing Bedrock workflow. Compare a category score with generated analysis and compare a schema error with a guardrail intervention.

## Fallback and cleanup

If the pipeline is still running, inspect its active step and continue with the completed rehearsal execution and shared endpoint. Use local inference if the AWS endpoint is unavailable. The action CLI only needs Python's standard library, so participants without the ML dependencies can use the supplied example insight. Remove the teaching endpoint after its final exercise and verify deletion.
