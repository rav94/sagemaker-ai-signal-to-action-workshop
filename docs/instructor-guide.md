# Instructor guide

## Before class

- Confirm the teaching AWS account, region, training and real-time instance quotas, and deployer and participant roles.
- Rehearse managed training and save a completed job ID, evaluation output, and its S3 model URI.
- Deploy one shared endpoint and check that it is `InService`. Run the normal, ambiguous, and malformed fixtures using the participant identity.
- Save a normal response and a rejected invocation for fallback. Verify the local README path.
- Open the serving diagram, a CloudWatch endpoint metrics view, and the Bedrock companion repo.

## SageMaker teaching sequence

1. Show the training split and the fitted preprocessing inside the pipeline. The dataset contains 48 training and 16 test examples with the checked-in split. Ask what four test cases per class can tell you.
2. Show the [managed training job](cloud-training.md), its input and output in S3, and the matching artifact configured on the endpoint. Start the job ahead of the live invocation block.
3. Trace image, artifact, IAM role, model, endpoint config, and endpoint. Invoke with a valid case. Let pairs vary the review threshold and discuss score calibration and operational capacity.
4. Send a malformed case. Contrast the Runtime error from SageMaker with the container HTTP status and explain why there is no action.
5. Walk through the [MLOps release design](mlops.md). Ask what would trigger rollback if latency stays healthy while real complaint classification worsens.
6. Give the same complaint text to the existing Bedrock workflow. Compare a category score with generated analysis and compare a schema error with a guardrail intervention.

## Fallback and cleanup

If managed training runs long, inspect the running job and switch to the completed rehearsal job and shared endpoint. Use local inference if the AWS endpoint is unavailable. The action CLI only needs Python's standard library, so participants without the ML dependencies can use the supplied example insight. Remove the teaching endpoint after its final exercise and verify deletion.
