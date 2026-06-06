# ec2-auto-shutdown

A Lambda function that automatically stops any EC2 instance that has been running for more than 5 hours, across all enabled AWS regions. Triggered every 5 hours via EventBridge.

## How it works

- Scans all enabled regions for running EC2 instances
- Stops any instance whose `LaunchTime` is older than 5 hours
- Skips instances tagged with `AutoShutdown=false`
- Logs every action (stopped, skipped + reason) to CloudWatch

## Exempt an instance from shutdown

Add this tag to any instance you want to keep running:

| Key | Value |
|-----|-------|
| `AutoShutdown` | `false` |

## Deploy

Requires the [AWS CLI](https://aws.amazon.com/cli/) configured with credentials that can create IAM roles and Lambda functions.

```bash
cd ec2-auto-shutdown
./deploy.sh
```

The script will:
1. Create an IAM role (`ec2-auto-shutdown-role`) with the least-privilege policy in `iam_policy.json`
2. Package and deploy the Lambda function (`ec2-auto-shutdown`) to `us-east-1`
3. Create an EventBridge rule that triggers it every 5 hours

Re-running `deploy.sh` is safe — it skips role/permission creation if they already exist and updates the Lambda code in place.

## IAM permissions required

| Permission | Purpose |
|-----------|---------|
| `ec2:DescribeRegions` | List all enabled regions |
| `ec2:DescribeInstances` | Find running instances |
| `ec2:StopInstances` | Stop instances over the time limit |
| `logs:CreateLogGroup/Stream`, `logs:PutLogEvents` | Write to CloudWatch Logs |

## Configuration

Edit the constants at the top of `lambda_function.py` to change defaults:

| Constant | Default | Description |
|----------|---------|-------------|
| `MAX_RUNNING_HOURS` | `5` | Hours before an instance is stopped |
| `EXEMPT_TAG_KEY` | `AutoShutdown` | Tag key checked for exemption |
| `EXEMPT_TAG_VALUE` | `false` | Tag value that exempts an instance |
