# Scope

Train the original Phase 1 complaint classifier locally or in a SageMaker training job, then deploy it on a SageMaker AI real-time CPU endpoint. Run the Signal → Insight → Action loop from a CLI using synthetic fixtures. The endpoint runs the fitted text preprocessing and classifier together. Routing decisions are simulated.

The managed path uses one shared CPU training job and one serving instance in a teaching sandbox. The [architecture](../docs/architecture/README.md) and [managed training contract](05-managed-training.md) describe the artifact handoff. The MLOps delivery diagram is a discussion design. EventBridge, DynamoDB, a release pipeline, and automated monitoring jobs are future extensions.
