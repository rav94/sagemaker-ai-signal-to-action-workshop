# Instructor guide

## Before class

- Start with the [AWS walkthrough](deployment-demo-playbook.md). Launch the pipeline to create the assets stack and Studio workspace.
- With the assets stack available, run the [GitHub IAM setup](model-registry-ci-cd.md#github-actions-setup) and set the repository variables. Rehearse approval, GitHub deployment, and signed inference. Keep the completed Studio execution, evaluation report, Actions run, and endpoint ready.
- Save one successful and one malformed-request result for the walkthrough. Verify the [local lab](../README.md#run-the-local-lab) so students can reproduce the model and inference later.
- Open the [architecture diagram](architecture/README.md), Studio execution, Model Registry package, GitHub Actions log, and Bedrock companion repo.
- If presenting content screening, have the separate Bedrock stack's guardrail ID and published version ready. Rehearse both fixtures in the [screening lab](guardrails.md).

## In class

1. Show the complaint and expected response. Explain what the fitted vectorizer and classifier contribute to the archive.
2. Trace the trained archive through the Studio graph. Ask whether students would release a model that got 13 of 16 right overall and caught only 2 of 4 billing cases.
3. Follow the exact package ARN through approval and GitHub Actions. Explain why production promotion has its own permissions, verification, and rollback policy. [Teaching note](mlops.md#why-separate-model-building-and-deployment) Explain the Model, EndpointConfig, and Endpoint, then invoke the live endpoint and verify `modelVersion`.
4. Run the [content screening lab](guardrails.md) against the baseline endpoint. Use the shared Bedrock guardrail to screen complaints before SageMaker inference.
5. Use the [rollback drill](model-registry-ci-cd.md#demonstrate-rollback) to show what happens when the next approved release breaches a latency alarm. Keep the completed drill run and baseline response ready to show. Then switch to the Bedrock companion and show how the application applies the same content policy in its foundation model flow.

Students follow the demonstration in class and can run the repo later. After the last invocation, follow the [cleanup guide](costing.md).
