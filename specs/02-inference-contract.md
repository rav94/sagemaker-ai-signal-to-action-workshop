# Inference and decision contracts

- `GET /ping` returns HTTP 200 after the model and version are loaded and a startup prediction succeeds.
- `POST /invocations` expects `application/json` with a non-empty `message` string of at most 4,000 characters and a request body of at most 16 KiB.
- A successful response contains `category` (billing, delivery, service, technical), `score` (top estimated class probability in [0, 1]), and `modelVersion` (the packaged release version).
- Invalid JSON or a malformed message returns HTTP 400 from the container. The local routing CLI rejects an error response. On SageMaker, consult the Runtime `ModelError` metadata for the container status.
- The CLI emits `manual_review` below the chosen score threshold, or `route_to_category` otherwise. The default threshold of 0.40 is a classroom policy.

The same contract applies to artifacts produced locally and by the [managed training job](05-managed-training.md).

[AWS container contract](https://docs.aws.amazon.com/sagemaker/latest/dg/your-algorithms-inference-code.html) · [InvokeEndpoint errors](https://docs.aws.amazon.com/sagemaker/latest/APIReference/API_runtime_InvokeEndpoint.html#API_runtime_InvokeEndpoint_Errors)
