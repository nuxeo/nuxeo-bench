#!/bin/bash

cd $(dirname $0)
. venv/bin/activate

if [ -d logs ]; then
    rm -rf logs
fi

mkdir logs

for h in $(ansible/inventory.py --hosts nuxeo); do
    mkdir logs/$h
    scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no ubuntu@$h:/opt/nuxeo/logs/server.log logs/$h/ || true
    scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no ubuntu@$h:/opt/nuxeo/logs/gc.log logs/$h/ || true
    scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no ubuntu@$h:/opt/nuxeo/server/nxserver/perf*.csv logs/$h/ || true
done
