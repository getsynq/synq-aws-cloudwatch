#!/usr/bin/env bash
set -e


if [ -z "${AIRFLOW_ENV}" ]; then
  echo "Please set AIRFLOW_ENV variable"
  exit 1
fi
FILTER_NAME="airflow-${AIRFLOW_ENV}-logs-to-synq"


# Common config
SCRIPT_PATH="$(dirname -- "${BASH_SOURCE[0]}")"
source "${SCRIPT_PATH}/00-common.sh"

#For Airflow this should be in a format "airflow-<airflow-env>-Task"
LOG_GROUP_URN=$(aws mwaa get-environment --name ${AIRFLOW_ENV} --query Environment.LoggingConfiguration.TaskLogs.CloudWatchLogGroupArn --output text)
echo "Will forward ${LOG_GROUP_URN} log group"
LOG_GROUP_NAME=$(echo "${LOG_GROUP_URN}" | cut -d':' -f7)

FUNCTION_URN=$(aws lambda get-function --function-name "${FUNCTION_NAME}" --query Configuration.FunctionArn --output text)
if [ -z "${FUNCTION_URN}" ]; then
  echo "Function ${FUNCTION_NAME} not found, use 01-lambda.sh to create it"
  exit 1
fi;
echo "Using ${FUNCTION_URN} function"

echo "Adding permission to invoke lambda"
aws lambda add-permission \
    --function-name "${FUNCTION_NAME}" \
    --statement-id "${LOG_GROUP_NAME}-${FUNCTION_NAME}" \
    --principal "logs.amazonaws.com" \
    --action "lambda:InvokeFunction" \
    --source-arn "${LOG_GROUP_URN}:*" || true

echo "Adding subscription filter"
aws logs put-subscription-filter \
    --log-group-name "${LOG_GROUP_NAME}" \
    --filter-name "${FILTER_NAME}" \
    --filter-pattern "" \
    --destination-arn "${FUNCTION_URN}"

