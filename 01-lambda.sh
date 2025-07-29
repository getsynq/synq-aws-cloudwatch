#!/usr/bin/env bash

set -e

# Common config
SCRIPT_PATH="$(dirname -- "${BASH_SOURCE[0]}")"
source "${SCRIPT_PATH}/00-common.sh"

FUNCTION_ROLE_URN=$(aws iam get-role --role-name "${FUNCTION_ROLE}" --query Role.Arn --output text)
if [ -z "${FUNCTION_ROLE_URN}" ]; then
echo "Creating lambda role"
# Create the IAM role for Lambda
FUNCTION_ROLE_URN=$(aws iam create-role --role-name "${FUNCTION_ROLE}" --assume-role-policy-document file://iam-role.json --query Role.Arn --output text)

# Attach the AWS managed policy for basic Lambda execution
aws iam attach-role-policy --role-name "${FUNCTION_ROLE}" \
--policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole

fi
echo "Using ${FUNCTION_ROLE_URN} function role"

FUNCTION_URN=$(aws lambda get-function --function-name "${FUNCTION_NAME}" --query Configuration.FunctionArn --output text || true)
if [ -z "${FUNCTION_URN}" ]; then
  echo "Creating lambda function"
  aws lambda create-function --function-name "${FUNCTION_NAME}" \
  --runtime provided.al2023 --handler bootstrap \
  --environment "Variables={SYNQ_TOKEN=${SYNQ_TOKEN:-\"\"},SYNQ_CLIENT_ID=${SYNQ_CLIENT_ID:-\"\"},SYNQ_CLIENT_SECRET=${SYNQ_CLIENT_SECRET:-\"\"}}" \
  --role "${FUNCTION_ROLE_URN}" \
  --timeout 120 \
  --zip-file fileb://synq-aws-cloudwatch.zip
else
  echo "Updating lambda function"
  aws lambda update-function-code --function-name "${FUNCTION_NAME}" \
  --zip-file fileb://synq-aws-cloudwatch.zip
fi;
echo "Using ${FUNCTION_URN} function"
