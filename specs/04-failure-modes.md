# Failure modes

| Incident | Observable result | Response |
|---|---|---|
| Training quota, input, image, or execution role failure | The job cannot start or ends without `Completed` | Inspect the training job status, failure reason, and CloudWatch logs. The serving stack deployment does not run. |
| Job output URI outside the expected S3 prefix | Deployment stops before updating the serving stack | Inspect the archive URI returned by the job and confirm the workshop bucket and output prefix. |
| Missing or invalid model archive | Process startup fails, endpoint fails health checks | Inspect endpoint status and container logs. Verify S3 location, archive members, and dependency versions. |
| Wrong content type or malformed message | Container returns 415 or 400 | Inspect status and stop before the action stage. |
| Low score | Valid insight with score below policy threshold | Route to simulated review. |
| Invocation unavailable or denied | Runtime call fails | Inspect endpoint state and caller IAM. No insight is available for routing. |
