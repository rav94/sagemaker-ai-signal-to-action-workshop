# Registered release contract

## Registration

The main [pipeline flow](../docs/sagemaker-pipeline.md) trains, evaluates held-out data in a Processing job, and registers a package only if the billing recall meets the execution's `MinimumBillingRecall`. The package links the evaluation report. The commands below describe the registry-only fallback.

- `scripts/deploy.sh RELEASE --cloud-train --register-only` publishes the training and serving images, runs managed training, and registers the artifact. Omitting `--cloud-train` uses local training.
- `registry.yaml` creates the workshop Model Package Group in the separate `<workshop-stack>-registry` stack.
- The package starts in `PendingManualApproval`. It captures the S3 model URI, ECR serving image digest, supported response and request format, serving instance type, and release version.
- Registration leaves the endpoint alone. An instructor reviews the evaluation and explicitly approves or rejects a candidate.

## Promotion

- `scripts/deploy-approved.sh MODEL_PACKAGE_ARN` accepts a versioned ARN scoped to the workshop group, AWS account, and region.
- It stops with exit `3` before deploying if either approval or package status fails the gate. Required states are `Approved` and `Completed`.
- It uses the registered archive and image from the existing workshop asset stack. It neither starts another training job nor rebuilds the image. The signed smoke test must return the registered release as `modelVersion`.

## Workflows

- Workshop CI runs the same local Docker train-and-serve contract test for pull requests and `main` pushes. It has no AWS credentials.
- Deployment is manually dispatched from `main`, uses OIDC for the teaching AWS role, and delegates all Registry checks to `scripts/deploy-approved.sh`.

See the [registry and CI/CD lab](../docs/model-registry-ci-cd.md) for commands and role setup.
