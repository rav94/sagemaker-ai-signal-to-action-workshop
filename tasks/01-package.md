# Package and verify the model

- [x] Pin dependencies and package the fitted TF-IDF vectorizer, classifier, and release version as a single model archive. [Artifact contract](../specs/03-model-artifact.md)
- [x] Build the Linux AMD64 training and serving images from the shared Dockerfile. Run training with SageMaker-style paths and load its archive in the serving container.
- [x] Run the evaluation entry point in a separate container on the same archive. The local smoke run measured 13/16 correct overall and 2/4 billing complaints detected. [Training and evaluation contract](../specs/05-managed-training.md)
- [x] Rehearse the local README flow with the `uv` environment. Train and package a release, send a complaint over loopback HTTP, and check routing. [Local lab](../README.md#run-the-local-lab)
- [x] Verify container health, a prediction with the expected `modelVersion`, and HTTP 400 for malformed input. [Inference contract](../specs/02-inference-contract.md)
- [x] Reuse the container smoke checks in GitHub Actions CI. [CI workflow](../.github/workflows/ci.yml)
