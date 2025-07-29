#!/usr/bin/env bash

set -euo pipefail

# Common config
SCRIPT_PATH="$(dirname -- "${BASH_SOURCE[0]}")"
source "${SCRIPT_PATH}/00-common.sh"

check_aws_cli

log_info "Starting cleanup of SYNQ AWS CloudWatch resources..."

# Remove Lambda function
if aws lambda get-function --function-name "${FUNCTION_NAME}" --query Configuration.FunctionArn --output text >/dev/null 2>&1; then
    log_info "Deleting Lambda function: ${FUNCTION_NAME}"
    aws lambda delete-function --function-name "${FUNCTION_NAME}"
else
    log_info "Lambda function ${FUNCTION_NAME} not found, skipping"
fi

# Remove IAM role and policies
if aws iam get-role --role-name "${FUNCTION_ROLE}" >/dev/null 2>&1; then
    log_info "Detaching policies from role: ${FUNCTION_ROLE}"
    
    # Detach AWS managed policy
    aws iam detach-role-policy \
        --role-name "${FUNCTION_ROLE}" \
        --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole || true
    
    log_info "Deleting IAM role: ${FUNCTION_ROLE}"
    aws iam delete-role --role-name "${FUNCTION_ROLE}"
else
    log_info "IAM role ${FUNCTION_ROLE} not found, skipping"
fi

# Remove subscription filters if AIRFLOW_ENV is set
if [[ -n "${AIRFLOW_ENV:-}" ]]; then
    FILTER_NAME="airflow-${AIRFLOW_ENV}-logs-to-synq"
    
    if LOG_GROUP_URN=$(aws mwaa get-environment --name "${AIRFLOW_ENV}" --query Environment.LoggingConfiguration.TaskLogs.CloudWatchLogGroupArn --output text ); then
        LOG_GROUP_NAME=$(echo "${LOG_GROUP_URN}" | cut -d':' -f7)
        
        log_info "Removing subscription filter: ${FILTER_NAME}"
        aws logs delete-subscription-filter \
            --log-group-name "${LOG_GROUP_NAME}" \
            --filter-name "${FILTER_NAME}" || log_info "Subscription filter not found"
        
        # Remove Lambda permission
        log_info "Removing Lambda permission"
        aws lambda remove-permission \
            --function-name "${FUNCTION_NAME}" \
            --statement-id "${LOG_GROUP_NAME}-${FUNCTION_NAME}" || log_info "Permission not found"
    else
        log_info "Airflow environment ${AIRFLOW_ENV} not found, skipping subscription filter cleanup"
    fi
else
    log_info "AIRFLOW_ENV not set, skipping Airflow-specific cleanup"
fi

log_info "Cleanup completed successfully"
