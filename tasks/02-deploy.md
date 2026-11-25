# Deploy to the teaching sandbox

- [x] Define S3, ECR, IAM, CloudWatch Logs, Model, EndpointConfig, and Endpoint resources.
- [x] Add the managed training image, training role, input channel, and artifact handoff.
- [ ] Rehearse the managed training job. Capture the job status, input URI, and evaluation log.
- [ ] Verify the completed job’s artifact URI matches `PrimaryContainer.ModelDataUrl` and the inference response reports the expected release version.
- [ ] Confirm the profile, region, training and serving quotas, and permission to provision paid resources.
- [ ] Deploy and wait for `InService`. Run the participant fixtures with the signed runtime client.
- [ ] Run hosted CI and rehearse the pending and approved Registry deployment from the teaching account.
- [ ] Rehearse the guarded update and capture the alarm and restored baseline version.
- [ ] Verify the standalone content check for both the allowed and synthetic email requests in the teaching account.
- [ ] Rehearse deletion of the endpoint and asset stack.
