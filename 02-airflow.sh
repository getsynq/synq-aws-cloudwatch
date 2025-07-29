#!/usr/bin/env bash

set -euo pipefail

# Common config
SCRIPT_PATH="$(dirname -- "${BASH_SOURCE[0]}")"
source "${SCRIPT_PATH}/00-common.sh"

# Validate requirements
validate_auth
check_aws_cli

if [[ -z "${AIRFLOW_ENV:-}" ]]; then
    log_error "AIRFLOW_ENV environment variable is required"
    log_error "Example: export AIRFLOW_ENV='my-airflow-environment'"
    exit 1
fi

FILTER_NAME="airflow-${AIRFLOW_ENV}-logs-to-synq"

# Get Airflow log group
get_airflow_log_group() {
    local log_group_urn
    if ! log_group_urn=$(aws mwaa get-environment --name "${AIRFLOW_ENV}" --query Environment.LoggingConfiguration.TaskLogs.CloudWatchLogGroupArn --output text 2>/dev/null); then
        log_error "Failed to get Airflow environment '${AIRFLOW_ENV}'. Please check the environment name."
        exit 1
    fi
    
    if [[ "${log_group_urn}" == "None" || -z "${log_group_urn}" ]]; then
        log_error "Task logging is not enabled for Airflow environment '${AIRFLOW_ENV}'"
        exit 1
    fi
    
    echo "${log_group_urn}"
}

LOG_GROUP_URN=$(get_airflow_log_group)
LOG_GROUP_NAME=$(echo "${LOG_GROUP_URN}" | cut -d':' -f7)

log_info "Will forward log group: ${LOG_GROUP_URN}"

# Verify Lambda function exists
if ! FUNCTION_URN=$(aws lambda get-function --function-name "${FUNCTION_NAME}" --query Configuration.FunctionArn --output text 2>/dev/null); then
    log_error "Lambda function '${FUNCTION_NAME}' not found"
    log_error "Run ./01-lambda.sh to create it first"
    exit 1
fi

log_info "Using Lambda function: ${FUNCTION_URN}"

# Add permission for CloudWatch Logs to invoke Lambda
log_info "Adding permission for CloudWatch Logs to invoke Lambda"
if ! aws lambda add-permission \
    --function-name "${FUNCTION_NAME}" \
    --statement-id "${LOG_GROUP_NAME}-${FUNCTION_NAME}" \
    --principal "logs.amazonaws.com" \
    --action "lambda:InvokeFunction" \
    --source-arn "${LOG_GROUP_URN}:*" 2>/dev/null; then
    log_info "Permission already exists or failed to add"
fi

# Create subscription filter
log_info "Creating subscription filter: ${FILTER_NAME}"
if aws logs put-subscription-filter \
    --log-group-name "${LOG_GROUP_NAME}" \
    --filter-name "${FILTER_NAME}" \
    --filter-pattern "" \
    --destination-arn "${FUNCTION_URN}"; then
    log_info "Successfully created subscription filter for ${LOG_GROUP_NAME} log group"
else
    log_error "Failed to create subscription filter"
    exit 1
fi

