#!/bin/bash -e
set -x
# This script add a CI build artifact of a bench to the bench reference site
cd $(dirname $0)
# fail on any command error
set -e

BUILD_PATH=$1
shift
SITE_PATH=$1
shift
DATA_FILE=$BUILD_PATH/archive/reports/data.yml


function get_artifact_info() {
  # need dbprofile, benchid, benchname
  export BENCHID=`grep benchid $DATA_FILE | cut -d \: -f 2 | sed 's,[" ],,g'`
  export DBPROFILE=`grep dbprofile $DATA_FILE | cut -d \: -f 2 | sed 's,",,g;s,^ *,,g'`
  export BENCHNAME=`grep benchname $DATA_FILE | cut -d \: -f 2 | sed 's,",,g;s,^ *,,g'`
}

function copy_artifact() {
  mkdir -p $SITE_PATH/static/build
  mkdir $SITE_PATH/static/build/$BENCHID
  cp -af $BUILD_PATH $SITE_PATH/static/build/$BENCHID/$DBPROFILE
}

function add_data() {
  mkdir -p $SITE_PATH/data/bench
  cp -r $DATA_FILE $SITE_PATH/data/bench/$BENCHID$DBPROFILE.yml
}

function add_content() {
  mkdir -p $SITE_PATH/content/bench/$BENCHID
  cat > $SITE_PATH/content/bench/$BENCHID/$DBPROFILE.md << EOF
---
dfile: "$BENCHID$DBPROFILE"
benchid: "$BENCHID"
benchname: "$BENCHNAME"
dbprofile: "$DBPROFILE"
type: bench
---
EOF
}

function rebuild_site() {
  pushd $SITE_PATH
  git pull
  hugo --theme=hyde
  popd
}

# -------------------------------------------------------
# main
#
get_artifact_info
copy_artifact
add_data
add_content
rebuild_site
echo "Done"