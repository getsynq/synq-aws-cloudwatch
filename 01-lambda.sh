#!/usr/bin/env bash

set -euo pipefail

# Common config
SCRIPT_PATH="$(dirname -- "${BASH_SOURCE[0]}")"
source "${SCRIPT_PATH}/00-common.sh"

# Validate requirements
validate_auth
check_aws_cli

if [[ ! -f "synq-aws-cloudwatch.zip" ]]; then
    log_error "synq-aws-cloudwatch.zip not found. Run 'make zip' first"
    exit 1
fi

if [[ ! -f "iam-role.json" ]]; then
    log_error "iam-role.json not found"
    exit 1
fi

# Create or get IAM role
create_or_get_role() {
    local role_arn
    if role_arn=$(aws iam get-role --role-name "${FUNCTION_ROLE}" --query Role.Arn --output text 2>/dev/null); then
        log_info "Using existing role: ${role_arn}"
        echo "${role_arn}"
    else
        log_info "Creating IAM role: ${FUNCTION_ROLE}"
        role_arn=$(aws iam create-role \
            --role-name "${FUNCTION_ROLE}" \
            --assume-role-policy-document file://iam-role.json \
            --query Role.Arn --output text)
        
        # Attach the AWS managed policy for basic Lambda execution
        aws iam attach-role-policy \
            --role-name "${FUNCTION_ROLE}" \
            --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole
        
        log_info "Waiting for role to propagate..."
        sleep 10
        
        echo "${role_arn}"
    fi
}

FUNCTION_ROLE_URN=$(create_or_get_role)

# Create or update Lambda function
if FUNCTION_URN=$(aws lambda get-function --function-name "${FUNCTION_NAME}" --query Configuration.FunctionArn --output text 2>/dev/null); then
    log_info "Updating existing Lambda environment variables"

    # Update environment variables
    aws lambda update-function-configuration \
        --function-name "${FUNCTION_NAME}" \
        --environment "Variables={SYNQ_TOKEN=${SYNQ_TOKEN:-\"\"},SYNQ_CLIENT_ID=${SYNQ_CLIENT_ID:-\"\"},SYNQ_CLIENT_SECRET=${SYNQ_CLIENT_SECRET:-\"\"}}"

    log_info "Updating existing Lambda function: ${FUNCTION_NAME}"

    aws lambda update-function-code \
        --function-name "${FUNCTION_NAME}" \
        --zip-file fileb://synq-aws-cloudwatch.zip

else
    log_info "Creating Lambda function: ${FUNCTION_NAME}"
    FUNCTION_URN=$(aws lambda create-function \
        --function-name "${FUNCTION_NAME}" \
        --runtime provided.al2023 \
        --handler bootstrap \
        --environment "Variables={SYNQ_TOKEN=${SYNQ_TOKEN:-\"\"},SYNQ_CLIENT_ID=${SYNQ_CLIENT_ID:-\"\"},SYNQ_CLIENT_SECRET=${SYNQ_CLIENT_SECRET:-\"\"}}" \
        --role "${FUNCTION_ROLE_URN}" \
        --timeout 120 \
        --zip-file fileb://synq-aws-cloudwatch.zip \
        --query FunctionArn --output text)
fi

log_info "Lambda function ready: ${FUNCTION_URN}"
