#!/usr/bin/env python3

import boto3
import argparse
import sys
from typing import Dict, Any

def create_ec2_instance(
    subnet_id: str,
    ami_id: str,
    instance_type: str = 't2.micro',
    key_name: str = None,
    security_group_ids: list = None,
    tags: Dict[str, str] = None
) -> Dict[str, Any]:
    """
    Create an EC2 instance in the specified subnet with the given AMI.
    
    Args:
        subnet_id (str): The ID of the subnet to launch the instance in
        ami_id (str): The ID of the AMI to use
        instance_type (str): The type of instance to launch
        key_name (str): The name of the key pair to use
        security_group_ids (list): List of security group IDs
        tags (dict): Dictionary of tags to apply to the instance
    
    Returns:
        dict: Information about the created instance
    """
    try:
        ec2 = boto3.client('ec2')
        
        # Prepare launch parameters
        launch_params = {
            'ImageId': ami_id,
            'InstanceType': instance_type,
            'SubnetId': subnet_id,
            'MinCount': 1,
            'MaxCount': 1,
        }
        
        if key_name:
            launch_params['KeyName'] = key_name
            
        if security_group_ids:
            launch_params['SecurityGroupIds'] = security_group_ids
            
        # Launch the instance
        response = ec2.run_instances(**launch_params)
        
        instance_id = response['Instances'][0]['InstanceId']
        
        # Add tags if provided
        if tags:
            ec2.create_tags(
                Resources=[instance_id],
                Tags=[{'Key': k, 'Value': v} for k, v in tags.items()]
            )
        
        # Wait for the instance to be running
        waiter = ec2.get_waiter('instance_running')
        waiter.wait(InstanceIds=[instance_id])
        
        # Get instance details
        instance = ec2.describe_instances(InstanceIds=[instance_id])
        
        return {
            'InstanceId': instance_id,
            'State': instance['Reservations'][0]['Instances'][0]['State']['Name'],
            'PublicIpAddress': instance['Reservations'][0]['Instances'][0].get('PublicIpAddress'),
            'PrivateIpAddress': instance['Reservations'][0]['Instances'][0].get('PrivateIpAddress')
        }
        
    except Exception as e:
        print(f"Error creating EC2 instance: {str(e)}")
        sys.exit(1)

def main():
    parser = argparse.ArgumentParser(description='Create an EC2 instance')
    parser.add_argument('--subnet-id', required=True, help='Subnet ID to launch the instance in')
    parser.add_argument('--ami-id', required=True, help='AMI ID to use')
    parser.add_argument('--instance-type', default='t2.micro', help='Instance type')
    parser.add_argument('--key-name', help='Key pair name')
    parser.add_argument('--security-groups', nargs='+', help='Security group IDs')
    parser.add_argument('--tags', nargs='+', help='Tags in format key=value')
    
    args = parser.parse_args()
    
    # Parse tags if provided
    tags = {}
    if args.tags:
        for tag in args.tags:
            key, value = tag.split('=')
            tags[key] = value
    
    # Create instance
    instance_info = create_ec2_instance(
        subnet_id=args.subnet_id,
        ami_id=args.ami_id,
        instance_type=args.instance_type,
        key_name=args.key_name,
        security_group_ids=args.security_groups,
        tags=tags
    )
    
    print("\nInstance created successfully!")
    print(f"Instance ID: {instance_info['InstanceId']}")
    print(f"State: {instance_info['State']}")
    if instance_info.get('PublicIpAddress'):
        print(f"Public IP: {instance_info['PublicIpAddress']}")
    print(f"Private IP: {instance_info['PrivateIpAddress']}")

if __name__ == '__main__':
    main() 