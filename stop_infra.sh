#!/bin/bash
# Stop the bench infra
cd $(dirname $0)
. venv/bin/activate

esinstances=$(aws ec2 describe-instances --filters "Name=tag:bench,Values=test" "Name=tag:bench_role,Values=es" "Name=instance-state-name,Values=running" --region=eu-west-1 --no-paginate --query "Reservations[*].Instances[*].InstanceId" | grep "i-" | tr -d '" ,')
nuxeoinstances=$(aws ec2 describe-instances --filters "Name=tag:bench,Values=test" "Name=tag:bench_role,Values=nuxeo" "Name=instance-state-name,Values=running" --region=eu-west-1 --no-paginate --query "Reservations[*].Instances[*].InstanceId" | grep "i-" | tr -d '" ,')
kafkainstances=$(aws ec2 describe-instances --filters "Name=tag:bench,Values=test" "Name=tag:bench_role,Values=kafka" "Name=instance-state-name,Values=running" --region=eu-west-1 --no-paginate --query "Reservations[*].Instances[*].InstanceId" | grep "i-" | tr -d '" ,')
dbinstances=$(aws ec2 describe-instances --filters "Name=tag:bench_role,Values=db" "Name=instance-state-name,Values=running" --region=eu-west-1 --no-paginate --query "Reservations[*].Instances[*].InstanceId" | grep "i-" | tr -d '" ,')
nosqldbinstances=$(aws ec2 describe-instances --filters "Name=tag:bench_role,Values=nosqldb" "Name=instance-state-name,Values=running" --region=eu-west-1 --no-paginate --query "Reservations[*].Instances[*].InstanceId" | grep "i-" | tr -d '" ,')
mgmtinstances=$(aws ec2 describe-instances --filters "Name=tag:bench_role,Values=mgmt" "Name=instance-state-name,Values=running" --region=eu-west-1 --no-paginate --query "Reservations[*].Instances[*].InstanceId" | grep "i-" | tr -d '" ,')

for i in $(echo -n $esinstances" "$nuxeoinstances" "$dbinstances" "$nosqldbinstances" "$mgmtinstances" "$kafkainstances); do
    aws ec2 stop-instances --instance-ids $i --region=eu-west-1
done

