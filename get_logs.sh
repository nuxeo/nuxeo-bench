#!/bin/bash

cd $(dirname $0)


if [ -d logs ]; then
    rm -rf logs
fi

mkdir logs

for h in $(ansible/inventory.py --hosts nuxeo); do
    mkdir logs/$h
    scp ubuntu@$h:/opt/nuxeo/logs/server.log logs/$h/
    scp ubuntu@$h:/opt/nuxeo/logs/gc.log logs/$h/
    scp ubuntu@$h:/opt/nuxeo/server/nxserver/perf*.csv logs/$h/
done
