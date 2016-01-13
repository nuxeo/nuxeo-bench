#!/bin/bash -e
# Add a CI reference bench artifacts to the bench reference site
cd $(dirname $0)
SITE_ROOT=../site

# fail on any command error
set -e

function import_artifacts() {
  echo "Import artifacts"


  mkdir $SCRIPT_ROOT
  pushd $SCRIPT_ROOT
  git init
  git config core.sparseCheckout true
  echo "$SCRIPT_DIR" > .git/info/sparse-checkout
  git remote add origin $NUXEO_GIT
  git pull --depth 10 origin master
  popd
}
