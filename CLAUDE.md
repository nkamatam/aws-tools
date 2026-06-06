# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository structure

A collection of AWS automation utilities. Currently contains one tool:

- **`ec2-auto-shutdown/`** — Lambda function (Python 3.12 / boto3) that stops EC2 instances running longer than `MAX_RUNNING_HOURS` (default: 2), across all enabled regions. Triggered every 2 hours via EventBridge. Instances tagged `AutoShutdown=false` are exempt.

## Deploying

```bash
cd ec2-auto-shutdown
./deploy.sh
```

`deploy.sh` is idempotent — safe to re-run. It creates the IAM role, packages `lambda_function.py` into `lambda.zip`, creates or updates the Lambda, and wires the EventBridge schedule. All resources are deployed to `us-east-1`; the Lambda itself scans all enabled regions at runtime.

## CI/CD (GitHub Actions)

- **PR → master**: packages the zip (validation only, no deploy)
- **Push → master**: packages and deploys via `deploy.sh`

Authentication uses OIDC — GitHub Actions assumes the `github-actions-aws-tools` IAM role (account `925601332263`) with no stored credentials. The `id-token: write` permission is required on the deploy job.

## Configuration

To change the shutdown threshold or exemption tag, edit the constants at the top of `ec2-auto-shutdown/lambda_function.py`:

| Constant | Default | Purpose |
|---|---|---|
| `MAX_RUNNING_HOURS` | `2` | Hours before an instance is stopped |
| `EXEMPT_TAG_KEY` | `AutoShutdown` | Tag key checked for exemption |
| `EXEMPT_TAG_VALUE` | `false` | Tag value that exempts an instance |

After editing, re-run `deploy.sh` to push the change. Also update the EventBridge `schedule-expression` in `deploy.sh` if changing the trigger interval.

## Adding a new tool

Create a new top-level directory (e.g., `s3-cleanup/`) with its own `deploy.sh`, IAM policy JSON, and Lambda/script source. Update the table in the root `README.md`. If the new tool needs CI/CD, add a job to `.github/workflows/deploy.yml` following the existing OIDC pattern.
