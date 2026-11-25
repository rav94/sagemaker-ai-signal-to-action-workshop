# Instructor guide

## Before class

- Confirm the teaching AWS account, region, training and real-time instance quotas, and deployer and participant roles.
- Rehearse managed training and save a completed job ID, evaluation output, and its S3 model URI.
- Deploy one shared endpoint and check that it is `InService`. Run the normal, ambiguous, and malformed fixtures using the participant identity.
- Save a normal response and a rejected invocation for fallback. Verify the local README path.
- Pre-stage a pending model package and rehearse the [registry and CI/CD lab](model-registry-ci-cd.md). Record the blocked promotion and the approved release's version.
- Rehearse the guarded endpoint update and the standalone content check. Capture the alarm and restored baseline version, and verify the allowed and screened-out requests.
- Open the [training and inference diagrams](architecture/README.md), the training job logs, endpoint metrics, and the Bedrock companion repo.

## SageMaker teaching sequence

1. Show the training split and the fitted preprocessing inside the pipeline. The dataset contains 48 training and 16 test examples with the checked-in split. Ask what four test cases per class can tell you.
2. In the [managed training lab](cloud-training.md), show the two Docker targets, the job input in S3, and the evaluation report in CloudWatch. Start the shared job before the live invocation block. When it completes, match its output URI to the model attached to the endpoint.
3. Trace the serving image and model archive through the serving execution role, Model, EndpointConfig, and Endpoint. Invoke with a valid case. Let pairs vary the review threshold and discuss score calibration and operational capacity.
4. Show one pending package being blocked, then approve it and promote it through GitHub Actions or the terminal. Verify the release version. Send a malformed case. Contrast the Runtime error from SageMaker with the container HTTP status and explain why there is no action.
5. Run the [guardrails lab](guardrails.md). Show the candidate alarm and endpoint rollback. Then pre-screen two requests with Bedrock ApplyGuardrail and compare the outcomes. Ask what would trigger a quality rollback if latency stays healthy while real complaint classification worsens.
6. Give the same complaint text to the existing Bedrock workflow. Compare a category score with generated analysis and compare a schema error with a guardrail intervention.

## Fallback and cleanup

If managed training runs long, inspect the running job and switch to the completed rehearsal job and shared endpoint. Use local inference if the AWS endpoint is unavailable. The action CLI only needs Python's standard library, so participants without the ML dependencies can use the supplied example insight. Remove the teaching endpoint after its final exercise and verify deletion.
