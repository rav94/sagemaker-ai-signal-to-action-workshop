# Production release and operations design

```mermaid
flowchart LR
    A[Validate versioned data] --> B[Train on SageMaker and archive to S3]
    B --> C[Evaluate on held-out examples]
    C -->|Pass release gate| D[Register model package]
    D --> E[Approval]
    E --> F[Stage and smoke test]
    F --> G[Canary to a production endpoint]
    G -->|Alarms healthy| H[Promote]
    G -->|Alarm| I[Roll back]
    H --> J[Evaluate against delayed labels]
    J -->|Quality regression| K[Investigate and decide rollback or retraining]
```

Track the training data revision, training job ID, artifact URI or checksum, both image digests, and the evaluation report together. Set explicit per-category recall requirements and a review queue capacity before release. Validate contract compatibility in staging. For a production canary, use service error and latency alarms, and verify you can redeploy the previous artifact and image. Separately, track changes in input and score distributions and measure quality after labels arrive. Route quality alerts to the team that can change the model or review policy.

The main workshop runs a [native SageMaker Pipeline](sagemaker-pipeline.md) with a separate evaluation job and billing recall gate. A passing package still needs manual model approval before promotion. The [guardrails lab](guardrails.md) adds a blue/green update with a CloudWatch latency alarm and automatic rollback. The [Registry and CI/CD lab](model-registry-ci-cd.md) makes model registration, manual approval, and promotion of the exact artifact runnable. The production design above adds explicit quality gates and gradual traffic shifting. Use those steps as a tabletop exercise.

[Model Registry](https://docs.aws.amazon.com/sagemaker/latest/dg/model-registry.html) · [Deployment guardrails](https://docs.aws.amazon.com/sagemaker/latest/dg/deployment-guardrails.html) · [CloudWatch metrics](https://docs.aws.amazon.com/sagemaker/latest/dg/monitoring-cloudwatch.html)
