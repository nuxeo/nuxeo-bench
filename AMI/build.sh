#!/bin/bash

set -e
set -x

cd $(dirname $0)
. aws.ini

# Prepare instance
instance=$(okta-aws ec2 run-instances --image-id ${AMI} --count 1 --instance-type ${TYPE} --key-name ${KEYNAME} --subnet-id ${SUBNET} --region ${REGION} --user-data file://$(pwd)/bootstrap.sh --query "Instances[0].InstanceId")
#--security-group-ids ${SECGROUP}
#instance=$(okta-aws ec2 run-instances --image-id ${AMI} --count 1 --instance-type ${TYPE} --key-name ${KEYNAME} --security-group-ids ${SECGROUP} --region ${REGION} --user-data file://$(pwd)/bootstrap.sh --query "Instances[0].InstanceId")
instance_id=$(echo -n $instance | tr -d '"')

# Wait for shutdown
while [ "$(okta-aws ec2 describe-instances --instance-ids ${instance_id} --region ${REGION} --query "Reservations[0].Instances[0].State.Name")" != "\"stopped\"" ]; do sleep 10; done

# Create image
tstamp=$(date +"%Y%m%d%H%M")
okta-aws ec2 create-image --instance-id ${instance_id} --name "nuxeo-base-$tstamp" --description "Nuxeo-base"  --region ${REGION}

# Terminate base instance
okta-aws ec2 terminate-instances --instance-ids ${instance_id} --region ${REGION}

