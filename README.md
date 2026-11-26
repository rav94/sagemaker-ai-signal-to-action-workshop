# SageMaker AI Signal → Insight → Action Workshop

Train a TF-IDF and logistic regression classifier on synthetic complaint data, run the same training code in SageMaker AI, and deploy the resulting model to a real-time endpoint. The workshop is the SageMaker companion to the [Bedrock Signal → Insight → Action workshop](https://github.com/rav94/ai-signal-insight-action-workshop).

| Lab | What you do | What to verify |
|---|---|---|
| **1. Local training and serving** | Fit the pipeline, package the model, and run it over HTTP. | Inspect the evaluation report. Send a complaint and change the routing threshold. |
| **2. Native SageMaker Pipeline** | Train, evaluate, and register a candidate if it meets the quality threshold. | Find the model archive, evaluation report, gate result, and pending package. |
| **3. Approved real-time deployment** | Approve a package and promote it with GitHub Actions or the terminal. | Invoke the endpoint and match `modelVersion` to the package. |

[Native SageMaker Pipeline lab](docs/sagemaker-pipeline.md) · [Deployment playbook](docs/deployment-demo-playbook.md) · [Architecture](docs/architecture/README.md)

## Run the local lab

Use Python 3.13. The dataset has 64 synthetic complaints across four categories. The reported metrics describe this small test split, and the classifier scores are uncalibrated.

```bash
uv venv --python 3.13
source .venv/bin/activate
uv pip install -r requirements.txt
bash scripts/package-model.sh phase1-local-v1
python src/predict.py "The app freezes whenever I open my account"
python src/serve.py serve --bind 127.0.0.1 --model-dir artifacts
```

In another terminal, send the billing complaint and apply two routing thresholds:

```bash
source .venv/bin/activate
curl -fsS http://127.0.0.1:8080/ping
curl --fail-with-body -sS -H 'Content-Type: application/json' \
  --data-binary @events/complaint.json http://127.0.0.1:8080/invocations \
  -o artifacts/insight.json
python src/action.py artifacts/insight.json --minimum-score 0.35
python src/action.py artifacts/insight.json --minimum-score 0.60
```

The **signal** is the complaint JSON. The **insight** contains the category, score, and model version. The **action** CLI uses the score to simulate routing to a category queue or human review.

## Train and deploy on AWS

Complete the [sandbox preflight](docs/deployment-demo-playbook.md), then start one shared SageMaker Pipeline:

```bash
bash scripts/deploy.sh phase1-pipeline-v1 --pipeline
```

Inspect its [training, evaluation, and quality gate](docs/sagemaker-pipeline.md). When a candidate passes, [review and approve its model package](docs/model-registry-ci-cd.md#review-and-approve-the-package), then promote it and [invoke the endpoint](docs/participant-guide.md). The [direct training walkthrough](docs/cloud-training.md) and [local fallback](docs/deployment-demo-playbook.md#rehearse-with-local-training) remain available for rehearsal.

- [Model Registry and CI/CD lab](docs/model-registry-ci-cd.md) for registering, approving, and promoting a specific release.
- [Guardrails lab](docs/guardrails.md) for endpoint auto-rollback and a standalone content check before SageMaker inference.
- [Instructor guide](docs/instructor-guide.md) for sequencing, checkpoints, and fallback.
- [Architecture](docs/architecture/README.md) for images, storage, roles, and the request path.
- [MLOps design](docs/mlops.md) for evaluation gates, versioning, rollout, and monitoring.
- [Troubleshooting](docs/troubleshooting.md) and [cost and cleanup](docs/costing.md) for operating the lab.

## License

This workshop is available under the [MIT License](LICENSE).
