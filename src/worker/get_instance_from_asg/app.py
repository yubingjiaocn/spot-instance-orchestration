import json
import logging
import os

import boto3

logger = logging.getLogger()
logger.setLevel(logging.INFO)

def lambda_handler(event, context):
    """
    Retrieve region, public/private IP address for instances in ASG
    """
    region = boto3.Session().region_name
    asg_name = os.environ['ASG_NAME']
    prefix = os.environ['PREFIX']

    # get desired and current inservice count from asg
    asg = boto3.client('autoscaling', region_name=region)
    ec2 = boto3.client('ec2', region_name=region)

    asg_response = asg.describe_auto_scaling_groups(
        AutoScalingGroupNames=[asg_name]
    )
    desired_count = asg_response['AutoScalingGroups'][0]['DesiredCapacity']
    current_count = len([i for i in asg_response['AutoScalingGroups'][0]['Instances'] if i['LifecycleState'] == 'InService'])
    ssm = boto3.client('ssm', region_name=os.environ['HUB_REGION'])

    instances_info = []
    if ((desired_count == current_count) and (current_count > 0)):
        # put region, public IP (if available) and private IP to ssm parameter
        instances = asg_response['AutoScalingGroups'][0]['Instances']
        try:
            for i in instances:
                instance_id = i['InstanceId']
                if i['LifecycleState'] == 'InService':
                    instance = ec2.describe_instances(InstanceIds=[instance_id])
                    public_ip = instance['Reservations'][0]['Instances'][0].get('PublicIpAddress')
                    if public_ip is None:
                        public_ip = 'None'
                    private_ip = instance['Reservations'][0]['Instances'][0]['PrivateIpAddress']
                    instances_info.append({
                        'instance_id': instance_id,
                        'public_ip': public_ip,
                        'private_ip': private_ip
                    })
            # put instances_info into ssm
            param_output = {
                "region": region,
                "instances": instances_info
            }
            ssm.put_parameter(
                Name=f'/{prefix}/instances-info',
                Value=json.dumps(param_output),
                Type='String',
                Overwrite=True
            )
            return {"launched": True}
        except Exception as e:
            logger.error(f"Error getting instance details: {str(e)}")
            return {'error': str(e)}
    else:
        logger.error(f"Desired and current instance count do not match, expect {desired_count} but get {current_count}")
        return {"launched": False}