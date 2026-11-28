# Rehearse the AWS release

- [x] Implement Studio, shared assets, Pipeline, Registry, and endpoint CloudFormation stacks. [Stack ownership](../docs/architecture/README.md#stack-ownership-and-identities)
- [x] Validate the pipeline definition and test the launcher and approval gate locally with mocked AWS calls.
- [x] Verify standard promotion and rollback outcomes locally with mocked AWS calls. [Release contract](../specs/07-registry-release.md#rollback-drill)
- [ ] Rehearse the launcher with Studio. Open the dedicated domain and trace a completed run through training, the evaluation report, the gate, and its exact Registry ARN. Confirm the new package is `Completed` and `PendingManualApproval`. [AWS walkthrough](../docs/deployment-demo-playbook.md)
- [ ] Run the [GitHub IAM setup](../docs/model-registry-ci-cd.md#set-up-aws-access-once). Confirm it configures or reuses the account provider and deploys the workshop IAM stack. Populate repository variables from its outputs.
- [ ] Approve the candidate and dispatch GitHub Actions with that versioned ARN. Confirm GitHub Actions assumes the role, then verify the endpoint is `InService` and returns the registered `modelVersion`. [Approval and deployment](../docs/model-registry-ci-cd.md)
- [ ] Rehearse the optional [content screening lab](../docs/guardrails.md) with the shared Bedrock guardrail. Verify the clean request returns the baseline `modelVersion` and the synthetic email case exits `3` before invocation.
- [ ] Dispatch the same workflow with a second approved package and `rollback_demo` enabled. Confirm the candidate alarm, `UPDATE_ROLLBACK_COMPLETE`, and the baseline endpoint configuration and `modelVersion`. [Rollback drill](../docs/model-registry-ci-cd.md#demonstrate-rollback)
- [ ] Run the inference fixtures and rehearse the [cleanup](../docs/costing.md#delete-after-the-final-invocation).
