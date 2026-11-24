# Inference and decision contracts

## Container HTTP API

The container listens on port `8080`. `GET /ping` returns `{"status":"ok"}` with HTTP 200 after the model and version load and a startup prediction succeeds.

`POST /invocations` expects an `application/json` object with a non-blank `message` string of up to 4,000 characters. The request body can be up to 16 KiB.

```json
{"message":"I was charged twice and need help with my account balance."}
```

A successful response returns the predicted category, its top model score, and the release version. Valid categories are `billing`, `delivery`, `service`, and `technical`. The score lies in [0, 1] and is uncalibrated.

```json
{"category":"billing","score":0.35864,"modelVersion":"phase1-cloud-v1"}
```

| Condition | Container response |
|---|---|
| Invalid JSON, body length, or message | HTTP 400 |
| Unsupported content type | HTTP 415 |
| Request body read timeout | HTTP 408 |
| Unknown GET or POST route | HTTP 404 |

In AWS, the caller uses the IAM-authenticated `InvokeEndpoint` API. SageMaker Runtime exposes a container 4xx or 5xx as `ModelError` with service HTTP 424 and the container's `OriginalStatusCode`. The same contract applies to artifacts produced locally and by the [managed training job](05-managed-training.md). [AWS container contract](https://docs.aws.amazon.com/sagemaker/latest/dg/your-algorithms-inference-code.html) · [InvokeEndpoint errors](https://docs.aws.amazon.com/sagemaker/latest/APIReference/API_runtime_InvokeEndpoint.html#API_runtime_InvokeEndpoint_Errors)

The [guarded caller](06-guardrails.md#bedrock-content-check-before-inference) optionally evaluates the input before it reaches this API. An intervention stops the request at that caller.

## Local routing policy

The CLI requires a valid category, a numeric score in [0, 1], and a non-blank model version. The minimum score is between 0 and 1 and defaults to 0.40 for the lab.

- A score below the threshold returns `simulatedAction=manual_review` and `queue=review`.
- A score at or above the threshold returns `simulatedAction=route_to_category` and sets `queue` to the predicted category.
- Both successful actions include `modelVersion`. Invalid inputs are rejected without a routing decision.
