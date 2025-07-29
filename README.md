# SYNQ AWS CloudWatch Integration

This project provides an AWS Lambda function that forwards CloudWatch logs to SYNQ.

## Prerequisites

- AWS CLI configured with appropriate permissions
- Go 1.24.5+ (for building the Lambda function)
- Make
- Access to SYNQ API (token or client credentials)

## Configuration

Edit `00-common.sh` to set your configuration:

```bash
SYNQ_TOKEN=""                    # Your SYNQ API token (required if not using client credentials)
SYNQ_CLIENT_ID=""               # Your SYNQ client ID (required if not using token)
SYNQ_CLIENT_SECRET=""           # Your SYNQ client secret (required if not using token)
FUNCTION_NAME="synq-aws-cloudwatch"  # Lambda function name
FUNCTION_ROLE="${FUNCTION_NAME}-role"  # IAM role name
```

**Note:** You must provide either `SYNQ_TOKEN` OR both `SYNQ_CLIENT_ID` and `SYNQ_CLIENT_SECRET`.

## Installation

### 1. Build and Deploy Lambda Function

```bash
# Build and package the Lambda function
make zip

# Deploy the Lambda function to AWS
./01-lambda.sh
```

### 2. Set up Airflow Log Forwarding (Optional)

To forward Airflow logs, set the `AIRFLOW_ENV` environment variable and run:

```bash
export AIRFLOW_ENV="your-airflow-environment-name"
./02-airflow.sh
```

## Authentication

You can authenticate with SYNQ using either:

1. **Long-lived token**: Set `SYNQ_TOKEN` in `00-common.sh` (available on the Airflow integration screen after creating the integration in the SYNQ app)
2. **Client credentials**: Set `SYNQ_CLIENT_ID` and `SYNQ_CLIENT_SECRET` in `00-common.sh`

## Environment Variables

The Lambda function uses these environment variables:

- `SYNQ_API_ENDPOINT` (default: `https://developer.synq.io/`)
- `SYNQ_TOKEN` - Long-lived API token
- `SYNQ_CLIENT_ID` - OAuth client ID
- `SYNQ_CLIENT_SECRET` - OAuth client secret

## Cleanup

To remove all created resources:

```bash
./xx-cleanup.sh
```
