# SageMaker AI Signal → Insight → Action Workshop

Train and deploy the Phase 1 complaint classifier as an IAM-authenticated SageMaker AI real-time endpoint. The lab uses the original synthetic complaint dataset and fitted TF-IDF plus logistic regression pipeline. It is the SageMaker companion to the [Bedrock workshop](https://github.com/Emojot-Inc/ai-signal-insight-action-workshop).

| Step | What happens |
|---|---|
| Signal | Send a complaint message to the inference endpoint. |
| Insight | Receive a category, its top model score, and the model version. |
| Action | Apply a score threshold to simulate routing or human review. |

The current workshop lab runs the three stages from the CLI. The [architecture diagram](docs/architecture/serving.drawio) and [production delivery design](docs/mlops.md) show where the endpoint fits. The dataset contains 64 synthetic examples across four categories. Treat reported metrics as lab observations and scores as uncalibrated.

## Quick start

Use Python 3.13 and install the training and serving dependencies from the same requirements file.

```bash
uv venv --python 3.13
source .venv/bin/activate
uv pip install -r requirements.txt
bash scripts/package-model.sh phase1-v1
python src/predict.py "The app freezes whenever I open my account"
python src/serve.py serve --bind 127.0.0.1 --model-dir artifacts
```

In another shell:

```bash
curl --fail-with-body -sS -H 'Content-Type: application/json' \
  --data-binary @events/complaint.json http://127.0.0.1:8080/invocations \
  -o artifacts/insight.json
python src/action.py artifacts/insight.json --minimum-score 0.40
```

## Train and deploy on SageMaker

After the local exercise, run the [managed training lab](docs/cloud-training.md). The same training code runs on a SageMaker CPU training job. The deployment script takes the archive produced by that job and uses it for the real-time endpoint.

- [Participant lab](docs/participant-guide.md)
- [Instructor guide](docs/instructor-guide.md)
- [Deployment playbook](docs/deployment-demo-playbook.md)
- [Troubleshooting](docs/troubleshooting.md)
- [Cost and cleanup](docs/costing.md)
