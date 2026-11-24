# Failure modes

| Incident | Observable result | Response |
|---|---|---|
| Missing or invalid model archive | Process startup fails, endpoint fails health checks | Inspect endpoint status and container logs. Verify S3 location, archive members, and dependency versions. |
| Wrong content type or malformed message | Container returns 415 or 400 | Inspect status and stop before the action stage. |
| Low score | Valid insight with score below policy threshold | Route to simulated review. |
| Invocation unavailable or denied | Runtime call fails | Inspect endpoint state and caller IAM. No insight is available for routing. |
