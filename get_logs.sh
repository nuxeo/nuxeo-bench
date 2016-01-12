#!/bin/bash
REPORT_PATH="./reports"
DATA_FILE=$REPORT_PATH/data.yml

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

# Add some info to the data stat file
echo "dbprofile: \"$dbprofile\"" >> $DATA_FILE
echo "benchid: \"$benchid\"" >> $DATA_FILE
echo "benchname: \"$benchname\"" >> $DATA_FILE
# Extract the mass import document per second
tail -n1 logs/*/perf*.csv | cut -d \; -f3 | LC_ALL=C xargs printf "import_dps: %.1f" >> $DATA_FILE

