# Registered release contract

## Registration

`RegisterCandidate` runs in the [SageMaker model-building pipeline](05-managed-training.md) after the billing-recall gate passes. The registry stack creates the Model Package Group `<workshop-stack>-registry`. The package records:

- `PendingManualApproval` and a versioned package ARN.
- The exact S3 training archive URI and ECR serving image digest.
- The S3 evaluation report as model quality statistics.
- The release label in `CustomerMetadataProperties.ReleaseVersion`.
- Supported request and response formats and real-time serving instance type.

The instructor reviews the evaluation and makes the release decision. The Studio role can issue an `Approved` update for a version in the workshop group. The pipeline ends at registration or failure. Approval records the release decision in Model Registry. Deployment starts when the instructor manually dispatches the separate GitHub workflow with that approved version's ARN.

## Promotion

- `scripts/deploy-approved.sh MODEL_PACKAGE_ARN` accepts a versioned ARN scoped to the workshop group, AWS account, and region.
- It stops with exit `3` before deploying unless the package is both `Approved` and `Completed`.
- It validates the asset locations against the workshop stack and passes the exact registered archive and image to the serving stack.
- The serving stack applies the Model, EndpointConfig, and Endpoint. After the endpoint is `InService`, a signed smoke test must return the registered release as `modelVersion`.

## Rollback drill

- The same workflow can run a blue/green drill using a different approved package and an existing workshop endpoint in `InService`. The serving role retains access to the baseline archive while both fleets are present.
- The deployment policy shifts all traffic at once and monitors the candidate's `ModelLatency` under the candidate endpoint configuration for five minutes. Synthetic probes populate the metric. The drill threshold is 1 µs.
- Success requires a candidate alarm transition during the run, CloudFormation in `UPDATE_ROLLBACK_COMPLETE`, the original endpoint configuration back in `InService`, and a fresh response with the original `modelVersion`.

## Workflows

- Workshop CI runs the local Docker train, evaluate, and serve contract checks on pull requests and `main` pushes without AWS credentials.
- The deployment workflow is manually dispatched from `main` with the versioned ARN. It assumes the teaching AWS role via OIDC and delegates checks and deployment to `scripts/deploy-approved.sh`.
- The [GitHub IAM setup script](../scripts/setup-github-iam.sh) creates or reuses the account's GitHub OIDC provider for `https://token.actions.githubusercontent.com` and ensures the `sts.amazonaws.com` audience is enabled. The provider remains in account IAM when the workshop stack is deleted.
- The [GitHub deployment IAM stack](../github-deploy-iam.yaml) uses the account's GitHub OIDC provider and requires the exact `GitHubOidcSubject` for the repository's `main` branch. Its output roles supply `AWS_DEPLOY_ROLE_ARN` and `AWS_MODEL_EXECUTION_ROLE_ARN`.
- The GitHub role can pass the setup stack's serving execution role to SageMaker. Model and EndpointConfig creation and deletion use the workshop's `WorkshopStack` tag. The instructor identity retains model approval.

The [Registry and CI/CD lab](../docs/model-registry-ci-cd.md) provides the approval command, GitHub dispatch, and OIDC setup.
