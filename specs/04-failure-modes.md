# Failure modes

| Incident | Observable result | Response |
|---|---|---|
| Training quota, input, image, or execution role failure | The job cannot start or ends without `Completed` | Inspect the training job status, failure reason, and CloudWatch logs. The serving stack deployment does not run. |
| Job output URI outside the expected S3 prefix | Deployment stops before updating the serving stack | Inspect the archive URI returned by the job and confirm the workshop bucket and output prefix. |
| Missing or invalid model archive | Process startup fails, endpoint fails health checks | Inspect endpoint status and container logs. Verify S3 location, archive members, and dependency versions. |
| Wrong content type or malformed message | Container returns HTTP 415 or 400. SageMaker Runtime reports `ModelError` with the original container status. | Inspect the original status and stop before the action stage. |
| Unexpected inference version | A valid response reports a different `modelVersion` | Compare the endpoint’s model URI with the completed training job output and verify the configured release before using the result. |
| Candidate latency alarm during update | SageMaker initiates rollback during the guarded update | Compare the final endpoint configuration and inference version with the recorded baseline. |
| Content check intervenes or fails | The guarded caller exits before `InvokeEndpoint` | Inspect its outcome and use the application fallback. |
| Low score | Valid insight with score below policy threshold | Route to simulated review. |
| Invocation unavailable or denied | Runtime call fails | Inspect endpoint state and caller IAM. No insight is available for routing. |
