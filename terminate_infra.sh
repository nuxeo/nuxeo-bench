#!/bin/bash

cd $(dirname $0)
. venv/bin/activate

esinstances=$(aws ec2 describe-instances --filters "Name=tag:bench,Values=test" "Name=tag:bench_role,Values=es" --region=eu-west-1 --no-paginate --query "Reservations[*].Instances[*].InstanceId" | grep "i-" | tr -d '" ,')
nuxeoinstances=$(aws ec2 describe-instances --filters "Name=tag:bench,Values=test" "Name=tag:bench_role,Values=nuxeo" --region=eu-west-1 --no-paginate --query "Reservations[*].Instances[*].InstanceId" | grep "i-" | tr -d '" ,')

for i in $(echo -n $esinstances" "$nuxeoinstances); do
    aws ec2 terminate-instances --instance-ids $i --region=eu-west-1
done


dbinstances=$(aws ec2 describe-instances --filters "Name=tag:bench_role,Values=db" "Name=instance-state-name,Values=running" --region=eu-west-1 --no-paginate --query "Reservations[*].Instances[*].InstanceId" | grep "i-" | tr -d '" ,')
nosqldbinstances=$(aws ec2 describe-instances --filters "Name=tag:bench_role,Values=nosqldb" "Name=instance-state-name,Values=running" --region=eu-west-1 --no-paginate --query "Reservations[*].Instances[*].InstanceId" | grep "i-" | tr -d '" ,')
mgmtinstances=$(aws ec2 describe-instances --filters "Name=tag:bench_role,Values=mgmt" "Name=instance-state-name,Values=running" --region=eu-west-1 --no-paginate --query "Reservations[*].Instances[*].InstanceId" | grep "i-" | tr -d '" ,')

for i in $(echo -n $dbinstances" "$nosqldbinstances" "$mgmtinstances); do
    aws ec2 stop-instances --instance-ids $i --region=eu-west-1
done

