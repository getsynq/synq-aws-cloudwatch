#!/usr/bin/env bash

set -euo pipefail

# Configuration
SYNQ_TOKEN=${SYNQ_TOKEN:-}
SYNQ_CLIENT_ID=${SYNQ_CLIENT_ID:-}
SYNQ_CLIENT_SECRET=${SYNQ_CLIENT_SECRET:-}

FUNCTION_NAME="synq-aws-cloudwatch"
FUNCTION_ROLE="${FUNCTION_NAME}-role"

export AWS_PAGER=""

# Validation function
validate_auth() {
    if [[ -z "${SYNQ_TOKEN}" && (-z "${SYNQ_CLIENT_ID}" || -z "${SYNQ_CLIENT_SECRET}") ]]; then
        echo "Error: Either SYNQ_TOKEN or both SYNQ_CLIENT_ID and SYNQ_CLIENT_SECRET must be set" >&2
        echo "Please edit 00-common.sh to configure authentication" >&2
        exit 1
    fi
}

# Utility functions
log_info() {
    echo "[INFO] $*" >&2
}

log_error() {
    echo "[ERROR] $*" >&2
}

check_aws_cli() {
    if ! command -v aws &> /dev/null; then
        log_error "AWS CLI not found. Please install and configure AWS CLI"
        exit 1
    fi
}