# SageMaker AI Signal → Insight → Action Workshop

Train a complaint classifier on synthetic data, then take one candidate through evaluation, approval, and deployment on SageMaker AI. Compare the deployed classifier with the [Bedrock foundation model workshop](https://github.com/rav94/ai-signal-insight-action-workshop).

| Path | What you see |
|---|---|
| **Local practice** | Train the model, package it, serve it over HTTP, and route one prediction. |
| **AWS release** | Use Studio to inspect a SageMaker Pipeline. Approve the passing package in Model Registry. Deploy and verify it through GitHub Actions. |

## Run the local lab

From the repo root, use Python 3.13 with `uv`:

```bash
uv venv --python 3.13
source .venv/bin/activate
uv pip install -r requirements.txt
bash scripts/package-model.sh phase1-local-v1
python src/serve.py serve --bind 127.0.0.1 --model-dir artifacts
```

In a second terminal at the repo root:

```bash
source .venv/bin/activate
curl --fail-with-body -sS -H 'Content-Type: application/json' \
  --data-binary @events/complaint.json http://127.0.0.1:8080/invocations \
  -o artifacts/insight.json &&
  cat artifacts/insight.json &&
  python src/action.py artifacts/insight.json --minimum-score 0.35
```

The complaint is the **signal**. The predicted category, score, and version are the **insight**. The routing CLI applies a threshold to simulate the **action**. Try the same result with `--minimum-score 0.60` to see when a complaint goes to review.

## Run the AWS release

SageMaker builds and evaluates the candidate. Model Registry records approval, and a separate GitHub Actions workflow deploys the exact approved package. [Why separate build and deployment?](docs/mlops.md#why-separate-model-building-and-deployment)

### Deploy the baseline

Complete the [teaching account preflight](docs/deployment-demo-playbook.md#preflight), then from the repo root run:

```bash
bash scripts/deploy.sh phase1-pipeline-v1
```

1. Open the workshop's **Studio** domain and inspect the **Pipeline** run. [AWS walkthrough](docs/deployment-demo-playbook.md#inspect-the-run-in-studio)
2. For the first run, [run the GitHub IAM setup and set repository variables](docs/model-registry-ci-cd.md#github-actions-setup).
3. Review the evaluation and approve the exact version in **Model Registry**. In **GitHub Actions → Deploy approved SageMaker release → Run workflow**, select `main`, enter that package ARN, and leave **`rollback_demo` unchecked**. [Approval and deployment](docs/model-registry-ci-cd.md)
4. Confirm the endpoint is `InService` and record the baseline `modelVersion`. [Inference walkthrough](docs/participant-guide.md)

### Screen a complaint before inference

With the baseline endpoint running, use the published guardrail from the separate Bedrock workshop to check a complaint before invoking SageMaker. [Content screening lab](docs/guardrails.md)

### Demonstrate blue/green rollback

Build a second candidate with a fresh release label:

```bash
bash scripts/deploy.sh phase1-rollout-v2
```

Approve the second package in Model Registry. Run **Deploy approved SageMaker release** again with the new ARN and **`rollback_demo` checked**. SageMaker shifts all traffic to the candidate while retaining the baseline fleet. The workflow sends probes to trigger the latency alarm, then verifies that the endpoint serves the baseline `modelVersion` again. [Rollout steps and expected logs](docs/deployment-demo-playbook.md#demonstrate-bluegreen-rollback)

[Architecture](docs/architecture/README.md) · [Instructor guide](docs/instructor-guide.md) · [Troubleshooting](docs/troubleshooting.md) · [Cost and cleanup](docs/costing.md)

## License

This workshop is available under the [MIT License](LICENSE).
