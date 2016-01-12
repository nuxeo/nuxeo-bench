#!/bin/bash
REPORT_PATH="./reports"

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

# Extract the mass import document per second stat and insert it into the report stat file
tail -n1 logs/*/perf*.csv | cut -d \; -f3 | LC_ALL=C xargs printf "import_dps:%.1f" >> $REPORT_PATH/data.yml
