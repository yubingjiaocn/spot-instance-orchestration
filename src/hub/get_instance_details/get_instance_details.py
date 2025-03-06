import boto3
import json
import os
from botocore.exceptions import ClientError

def lambda_handler(event, context):
    # Initialize the SSM client
    ssm = boto3.client('ssm')
    prefix = os.environ['PREFIX']

    # Parameter name to fetch - you can modify this or pass it through the event
    parameter_name = f"/{prefix}/instances-info"

    try:
        # Get the parameter value
        # WithDecryption=True will automatically decrypt SecureString parameters
        response = ssm.get_parameter(
            Name=parameter_name,
            WithDecryption=True
        )

        parameter_value = response['Parameter']['Value']

        return {
            'statusCode': 200,
            'body': parameter_value
        }

    except ClientError as e:
        error_message = e.response['Error']['Message']
        error_code = e.response['Error']['Code']

        return {
            'statusCode': 500,
            'body': json.dumps({
                'error': error_message,
                'error_code': error_code
            })
        }
    except Exception as e:
        return {
            'statusCode': 500,
            'body': json.dumps({
                'error': str(e)
            })
        }
