#!/bin/bash
set -e

FUNCTION_NAME="ec2-auto-shutdown"
ROLE_NAME="ec2-auto-shutdown-role"
REGION="us-east-1"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

echo "==> Creating IAM role..."
aws iam create-role \
  --role-name $ROLE_NAME \
  --assume-role-policy-document '{
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Principal": {"Service": "lambda.amazonaws.com"},
      "Action": "sts:AssumeRole"
    }]
  }' 2>/dev/null || echo "Role already exists, skipping."

echo "==> Attaching policy..."
aws iam put-role-policy \
  --role-name $ROLE_NAME \
  --policy-name ec2-auto-shutdown-policy \
  --policy-document file://iam_policy.json

echo "==> Waiting for role to propagate..."
sleep 10

echo "==> Zipping Lambda code..."
zip -j lambda.zip lambda_function.py

echo "==> Deploying Lambda..."
ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/${ROLE_NAME}"

if aws lambda get-function --function-name $FUNCTION_NAME --region $REGION &>/dev/null; then
  aws lambda update-function-code \
    --function-name $FUNCTION_NAME \
    --zip-file fileb://lambda.zip \
    --region $REGION
  echo "Lambda updated."
else
  aws lambda create-function \
    --function-name $FUNCTION_NAME \
    --runtime python3.12 \
    --role $ROLE_ARN \
    --handler lambda_function.handler \
    --timeout 300 \
    --zip-file fileb://lambda.zip \
    --region $REGION
  echo "Lambda created."
fi

echo "==> Creating EventBridge rule (every 5 hours)..."
aws events put-rule \
  --name ec2-auto-shutdown-schedule \
  --schedule-expression "rate(5 hours)" \
  --state ENABLED \
  --region $REGION

LAMBDA_ARN="arn:aws:lambda:${REGION}:${ACCOUNT_ID}:function:${FUNCTION_NAME}"

echo "==> Granting EventBridge permission to invoke Lambda..."
aws lambda add-permission \
  --function-name $FUNCTION_NAME \
  --statement-id ec2-auto-shutdown-eventbridge \
  --action lambda:InvokeFunction \
  --principal events.amazonaws.com \
  --source-arn "arn:aws:events:${REGION}:${ACCOUNT_ID}:rule/ec2-auto-shutdown-schedule" \
  --region $REGION 2>/dev/null || echo "Permission already exists, skipping."

echo "==> Wiring rule to Lambda..."
aws events put-targets \
  --rule ec2-auto-shutdown-schedule \
  --targets "Id=1,Arn=${LAMBDA_ARN}" \
  --region $REGION

echo ""
echo "Done. Lambda '${FUNCTION_NAME}' will run every 5 hours and stop any EC2 instance running longer than 5 hours."
echo "To exempt an instance from shutdown, add the tag:  AutoShutdown=false"
