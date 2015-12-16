#!/bin/bash -e
cd $(dirname $0)

TARGET=http://nuxeo-bench.nuxeo.org/nuxeo
NUXEO_GIT=https://github.com/nuxeo/nuxeo.git
SCRIPT_ROOT="./bench-scripts"
SCRIPT_DIR="nuxeo-distribution/nuxeo-distribution-cap-gatling-tests"
SCRIPT_PATH="$SCRIPT_ROOT/$SCRIPT_DIR"
REDIS_DB=7
REPORT_PATH="./reports"

# fail on any command error
set -e

function clone_bench_scripts() {
  echo "Clone bench script"
  mkdir $SCRIPT_ROOT
  pushd $SCRIPT_ROOT
  git init
  git config core.sparseCheckout true
  echo "$SCRIPT_DIR" > .git/info/sparse-checkout
  git remote add origin $NUXEO_GIT
  git pull --depth 10 origin master
  popd
}

function update_bench_scripts() {
  echo "Update bench script"
  pushd $SCRIPT_ROOT
  set +e
  git pull --depth 20 origin master
  if [ $? -ne 0 ]; then
    popd
    set -e
    echo "Fail to update bench script, try to clone"
    rm -rf $SCRIPT_ROOT
    clone_bench_scripts
  else
    set -e
    popd
  fi
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
  pushd $SCRIPT_PATH
  echo flushdb | redis-cli -n $REDIS_DB
  # redis-cli don't like unbuffered input
  unset PYTHONUNBUFFERED
  python ./scripts/inject-arbres.py -d | redis-cli -n $REDIS_DB --pipe
  export PYTHONUNBUFFERED=1
  popd
}

function gatling() {
  mvn -nsu test gatling:execute -Pbench -Durl=$TARGET -Dgatling.simulationClass=$1
}

function run_simulations() {
  echo "Run simulations"
  pushd $SCRIPT_PATH || exit 2
  mvn -nsu clean
  gatling "org.nuxeo.cap.bench.Sim00Setup" -Dpause_ms=200
  gatling "org.nuxeo.cap.bench.Sim10MassImport"
  gatling "org.nuxeo.cap.bench.Sim10CreateFolders" -Dpause_ms=200
  gatling "org.nuxeo.cap.bench.Sim20CreateDocuments"
  gatling "org.nuxeo.cap.bench.Sim30UpdateDocuments"
  gatling "org.nuxeo.cap.bench.Sim30Navigation"
  gatling "org.nuxeo.cap.bench.Sim30NavigationJsf"
  gatling "org.nuxeo.cap.bench.Sim50Bench"
  gatling "org.nuxeo.cap.bench.Sim50CRUD"
  gatling "org.nuxeo.cap.bench.Sim80ReindexAll"
  popd
}

function build_reports() {
  echo "Buildingreports"


}

# main
clone_or_update_bench_scripts
load_data_into_redis
run_simulations
build_reports