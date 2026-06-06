# aws-tools

A collection of AWS automation utilities.

## Tools

| Tool | Description |
|------|-------------|
| [ec2-auto-shutdown](ec2-auto-shutdown/) | Lambda function that stops EC2 instances running longer than 2 hours, across all regions |

## CI/CD

Deployments are automated via GitHub Actions using [OIDC federation](https://docs.github.com/en/actions/security-for-github-actions/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services) — no long-lived AWS credentials are stored as secrets.

| Event | Behaviour |
|-------|-----------|
| Pull request → `master` | Packages the Lambda zip (validation only, no deploy) |
| Push → `master` | Packages and deploys via `deploy.sh` |

### How it works

GitHub Actions requests a short-lived OIDC token from GitHub, then exchanges it for temporary AWS credentials by assuming the `github-actions-aws-tools` IAM role. Credentials expire when the job finishes.

### One-time AWS setup (already done)

If you ever need to recreate this in a new AWS account:

```bash
# 1. Create the OIDC identity provider
THUMBPRINT=$(openssl s_client -connect token.actions.githubusercontent.com:443 \
  -servername token.actions.githubusercontent.com 2>/dev/null \
  | openssl x509 -fingerprint -noout -sha1 \
  | sed 's/.*=//;s/://g' | tr '[:upper:]' '[:lower:]')

aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list $THUMBPRINT

# 2. Create the IAM role (trust policy scoped to this repo)
aws iam create-role \
  --role-name github-actions-aws-tools \
  --assume-role-policy-document file://iam_role_trust.json

# 3. Attach the deploy permissions policy
aws iam put-role-policy \
  --role-name github-actions-aws-tools \
  --policy-name deploy-ec2-auto-shutdown \
  --policy-document file://iam_role_policy.json
```

The IAM role trust policy restricts assumption to GitHub Actions jobs running in this repository (`nkamatam/aws-tools`). The permissions policy is least-privilege — scoped to exactly the IAM, Lambda, and EventBridge resources that `deploy.sh` manages.

## Contributors

- [nkamatam](https://github.com/nkamatam)

## Requirements

- [AWS CLI](https://aws.amazon.com/cli/) configured with appropriate credentials
- Each tool has its own IAM requirements — see the tool's README for details
