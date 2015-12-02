#!/bin/bash -e

NUXEO_GIT=https://github.com/nuxeo/nuxeo.git
SCRIPT_ROOT="./bench-scripts"
SCRIPT_DIR="nuxeo-distribution/nuxeo-distribution-cap-gatling-tests"
SCRIPT_PATH="$SCRIPT_ROOT/$SCRIPT_DIR"
TARGET=http://nuxeo-bench.nuxeo.org/

function clone_bench_scripts() {
  echo "Clone bench script"
  mkdir $SCRIPT_ROOT || exit 2
  pushd  $SCRIPT_ROOT
  git init || exit 2
  git config core.sparseCheckout true || exit 2
  echo "$SCRIPT_DIR" > .git/info/sparse-checkout
  git remote add origin $NUXEO_GIT || exit 2
  git pull --depth 1 origin master || exit 2
  popd
}

function update_bench_scripts() {
  echo "Update bench script"
  pushd $SCRIPT_ROOT || exit 2
  git pull --depth 1 origin master || exit 2
  popd
}

function clone_or_update_bench_scripts() {
  if [ -d $SCRIPT_ROOT ]; then
    update_bench_scripts
  else
    clone_bench_scripts
  fi
}

function load_data_into_redis() {
  echo "Load bench data into Redis"
  pushd $SCRIPT_PATH || exit 2
  python ./scripts/inject-arbres.py -d | redis-cli -n 7 --pipe || exit 3
  popd
}

function gatling() {
  mvn -nsu test gatling:execute -Pbench -Durl=$TARGET -Dgatling.simulationClass=$1 || exit 2
}

function run_simulations() {
  pushd $SCRIPT_PATH || exit 2
  echo "Run simulations"
  gatling "org.nuxeo.cap.bench.Sim00Setup"
  gatling "org.nuxeo.cap.bench.Sim10MassImport"
  gatling "org.nuxeo.cap.bench.Sim10CreateFolders"
  gatling "org.nuxeo.cap.bench.Sim20CreateDocuments"
  gatling "org.nuxeo.cap.bench.Sim30UpdateDocuments"
  gatling "org.nuxeo.cap.bench.Sim30Navigation"
  gatling "org.nuxeo.cap.bench.Sim30NavigationJsf"
  gatling "org.nuxeo.cap.bench.Sim50Bench"
  gatling "org.nuxeo.cap.bench.Sim50CRUD"
  gatling "org.nuxeo.cap.bench.Sim80ReindexAll"
  popd
}

clone_or_update_bench_scripts
load_data_into_redis
run_simulations
