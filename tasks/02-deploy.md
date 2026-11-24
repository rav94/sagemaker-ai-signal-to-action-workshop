# Deploy to the teaching sandbox

- [x] Define S3, ECR, IAM, CloudWatch Logs, Model, EndpointConfig, and Endpoint resources.
- [x] Add the managed training image, training role, input channel, and artifact handoff.
- [ ] Rehearse the managed training job. Capture the job status, input URI, and evaluation log.
- [ ] Verify the completed job’s artifact URI matches `PrimaryContainer.ModelDataUrl` and the inference response reports the expected release version.
- [ ] Confirm the profile, region, training and serving quotas, and permission to provision paid resources.
- [ ] Deploy and wait for `InService`. Run the participant fixtures with the signed runtime client.
- [ ] Rehearse deletion of the endpoint and asset stack.
