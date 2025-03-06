# AWS Spot Instance Management System API Guide

This document provides detailed information about the API endpoints available for interacting with the AWS Spot Instance Management System.

## API Overview

The AWS Spot Instance Management System exposes a REST API through API Gateway that allows users to:

1. Retrieve information about currently running spot instances
2. Enable or disable spot instance provisioning
3. Trigger teardown of resources

## Base URL

The API is accessible through the API Gateway URL provided during deployment:

```
https://{api-id}.execute-api.{region}.amazonaws.com/{stage}/
```

## Authentication

The API has no authentication.

## Endpoints

### 1. Get Spot Instance Details

Retrieves information about currently running spot instances across all regions.

**Endpoint:** `GET /spot-instances`

**Description:** Returns details about the currently active spot instances, including region, instance IDs, and IP addresses.

**Request Parameters:** None

**Response:**

```json
{
  "region": "us-west-2",
  "instances": [
    {
      "instance_id": "i-0123456789abcdef0",
      "public_ip": "54.123.456.789",
      "private_ip": "10.0.0.123"
    }
  ]
}
```

**Status Codes:**
- `200 OK`: Request successful
- `404 Not Found`: No active spot instances found
- `500 Internal Server Error`: Server error

**Example Request:**

```bash
curl -X GET https://{api-id}.execute-api.{region}.amazonaws.com/{stage}/spot-instances
```

### 2. Toggle Spot Provisioning

Enables or disables spot instance provisioning across the system.

**Endpoint:** `POST /spot-provisioning`

**Description:** Controls the spot instance provisioning state. When enabled, the system will attempt to provision spot instances in the optimal region. When disabled, the system will stop provisioning new instances and can optionally tear down existing resources.

**Request Body:**

```json
{
  "action": "enable|disable",
  "teardown": true|false
}
```

Parameters:
- `action` (required): Either "enable" to start spot instance provisioning or "disable" to stop it
- `teardown` (optional): When set to true with "disable" action, triggers cleanup of all resources

**Response:**

```json
{
  "message": "Spot provisioning enabled|disabled successfully"
}
```

**Status Codes:**
- `200 OK`: Request successful
- `400 Bad Request`: Invalid request parameters
- `500 Internal Server Error`: Server error

**Example Request:**

```bash
# Enable spot provisioning
curl -X POST https://{api-id}.execute-api.{region}.amazonaws.com/{stage}/spot-provisioning \
  -H "Content-Type: application/json" \
  -d '{"action": "enable"}'

# Disable spot provisioning with teardown
curl -X POST https://{api-id}.execute-api.{region}.amazonaws.com/{stage}/spot-provisioning \
  -H "Content-Type: application/json"\
  -d '{"action": "disable", "teardown": true}'
```

## Implementation Details

### Lambda Functions

The API endpoints are implemented by Lambda functions:

1. **Get Instance Details Lambda (`src/hub/get_instance_details/get_instance_details.py`):**
   - Retrieves instance information from SSM Parameter Store
   - Returns formatted JSON response with instance details

2. **Toggle Provisioning Lambda (`src/hub/toggle_provisioning/toggle_provisioning.py`):**
   - Updates provisioning state in SSM Parameter Store
   - Enables/disables EventBridge rules
   - Starts/stops Step Function executions
   - Sends teardown signals to worker regions when requested

### API Gateway Configuration

The API Gateway is configured with the following resources:

1. `/spot-instances` resource with GET method
2. `/spot-provisioning` resource with POST method

Each method is integrated with the corresponding Lambda function using AWS_PROXY integration type.

### Error Handling

The API implements the following error handling:

1. **Input Validation:**
   - Validates request parameters and body
   - Returns 400 Bad Request for invalid inputs

2. **Resource Not Found:**
   - Returns 404 Not Found when requested resources don't exist

3. **Server Errors:**
   - Catches and logs exceptions
   - Returns 500 Internal Server Error with error details

## Usage Examples

### Workflow: Starting a Spot Instance

1. Enable spot provisioning:
   ```bash
   curl -X POST https://{api-id}.execute-api.{region}.amazonaws.com/{stage}/spot-provisioning \
     -H "Content-Type: application/json" \
     -d '{"action": "enable"}'
   ```

2. Check instance status (may take a few minutes to provision):
   ```bash
   curl -X GET https://{api-id}.execute-api.{region}.amazonaws.com/{stage}/spot-instances
   ```

### Workflow: Stopping a Spot Instance

1. Disable spot provisioning with teardown:
   ```bash
   curl -X POST https://{api-id}.execute-api.{region}.amazonaws.com/{stage}/spot-provisioning \
     -H "Content-Type: application/json" \
     -d '{"action": "disable", "teardown": true}'
   ```

2. Verify instances are terminated:
   ```bash
   curl -X GET https://{api-id}.execute-api.{region}.amazonaws.com/{stage}/spot-instances
   ```

## Troubleshooting

### Common Issues

1. **404 Not Found:**
   - This is normal if no instances are currently running
   - Check if provisioning is enabled

2. **500 Internal Server Error:**
   - Check CloudWatch Logs for detailed error messages
   - Verify SSM Parameter Store contains the expected parameters

### Logging

All API requests and responses are logged to CloudWatch Logs:

- Lambda function logs: `/aws/lambda/{prefix}-hub-*`
- API Gateway logs: Configured in API Gateway settings

## Security Considerations

1. **IAM Permissions:**
   - Use the principle of least privilege when granting API access
   - Consider using API Gateway resource policies for additional security

2. **Data Protection:**
   - Sensitive information is stored in SSM Parameter Store
   - Consider enabling encryption for parameters containing sensitive data

3. **Network Security:**
   - Consider using VPC endpoints for API Gateway
   - Implement IP-based restrictions if needed
