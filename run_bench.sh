#!/bin/bash -e
cd $(dirname $0)

TARGET=http://nuxeo-bench.nuxeo.org/nuxeo
NUXEO_GIT=https://github.com/nuxeo/nuxeo.git
SCRIPT_ROOT="./bench-scripts"
SCRIPT_DIR="nuxeo-distribution/nuxeo-distribution-cap-gatling-tests"
SCRIPT_PATH="$SCRIPT_ROOT/$SCRIPT_DIR"
REDIS_DB=7
REPORT_PATH="./reports"
GAT_REPORT_VERSION=1.0-SNAPSHOT
GAT_REPORT_JAR=~/.m2/repository/org/nuxeo/tools/gatling-report/$GAT_REPORT_VERSION/gatling-report-$GAT_REPORT_VERSION-capsule-fat.jar
GRAPHITE_DASH=http://bench-mgmt.nuxeo.org/dashboard/#nuxeo-bench
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

function download_gatling_report() {
  if [ ! -f $GAT_REPORT_JAR ]; then
    mvn -DgroupId=org.nuxeo.tools -DartifactId=gatling-report -Dversion=$GAT_REPORT_VERSION -Dclassifier=capsule-fat -DrepoUrl=http://maven.nuxeo.org/nexus/content/groups/public-snapshot dependency:get
  fi
}

function build_report() {
  report_root="${1%-*}"
  mkdir $report_root || true
  mv $1 $report_root/detail
  java -jar $GAT_REPORT_JAR -o $report_root/overview -g $GRAPHITE_DASH --timezone 'Europe/Paris' $report_root/detail/simulation.log
  gzip $report_root/detail/simulation.log
}

function build_reports() {
  echo "Buildingreports"
  download_gatling_report
  for report in `find $SCRIPT_PATH/target/gatling/results -name simulation.log`; do
    build_report `dirname $report`
  done
}

function move_reports() {
  echo "Moving reports"
  mv $SCRIPT_PATH/target/gatling/results/* $REPORT_PATH
}

function clean() {
  rm -rf $REPORT_PATH
}

# main
clean
clone_or_update_bench_scripts
load_data_into_redis
run_simulations
set +e
build_reports
move_reports
