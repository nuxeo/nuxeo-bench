#!/bin/bash -e
# Run the Nuxeo gatling bench and generates simulation reports
cd $(dirname $0)
HERE=`readlink -e .`

TARGET=http://nuxeo-bench.nuxeo.org/nuxeo
NUXEO_GIT=https://github.com/nuxeo/nuxeo.git
SCRIPT_ROOT="./bench-scripts"
SCRIPT_DIR="nuxeo-distribution/nuxeo-jsf-ui-gatling-tests"
SCRIPT_PATH="$SCRIPT_ROOT/$SCRIPT_DIR"
SCRIPT_BRANCH=10.10
REDIS_DB=7
REPORT_PATH="./reports"
GAT_REPORT_VERSION=3.0-SNAPSHOT
GAT_REPORT_JAR=~/.m2/repository/org/nuxeo/tools/gatling-report/${GAT_REPORT_VERSION}/gatling-report-${GAT_REPORT_VERSION}-capsule-fat.jar
GRAPHITE_DASH=http://bench-mgmt.nuxeo.org/dashboard/#nuxeo-bench
MUSTACHE_TEMPLATE=./report-templates/data.mustache
# fail on any command error
set -e

function find_bench_scripts_branch() {
  local build_dir="$HERE/bin/.build/nuxeo"
  # if the distrib as been build from a branch use the same branch
  if [ -d ${build_dir} ]; then
    pushd ${build_dir}
    SCRIPT_BRANCH=$(git symbolic-ref -q --short HEAD 2>/dev/null) || SCRIPT_BRANCH=$(git describe --tags --exact-match 2>/dev/null) || SCRIPT_BRANCH="master"
    popd
  fi
}


function optimized_clone_bench_scripts() {
  echo "Cloning bench script using $SCRIPT_BRANCH"
  mkdir ${SCRIPT_ROOT}
  pushd ${SCRIPT_ROOT}
  git init
  git config core.sparseCheckout true
  echo "$SCRIPT_DIR" > .git/info/sparse-checkout
  git remote add origin ${NUXEO_GIT}
  git pull --depth 10 origin ${SCRIPT_BRANCH}
  popd
}

function optimized_update_bench_scripts() {
  echo "Updating bench script using $SCRIPT_BRANCH"
  pushd ${SCRIPT_ROOT}
  set +e
  git pull --depth 20 origin ${SCRIPT_BRANCH}
  if [ $? -ne 0 ]; then
    popd
    set -e
    echo "Fail to update bench script, try to clone"
    rm -rf ${SCRIPT_ROOT}
    clone_bench_scripts
  else
    set -e
    popd
  fi
}

function clone_bench_scripts() {
  echo "Cloning bench script using $SCRIPT_BRANCH"
  git clone ${NUXEO_GIT} ${SCRIPT_ROOT}
  pushd ${SCRIPT_ROOT}
  git checkout ${SCRIPT_BRANCH}
  popd
}


function update_bench_scripts() {
  echo "Updating bench script using $SCRIPT_BRANCH"
  pushd ${SCRIPT_ROOT}
  set +e
  git checkout ${SCRIPT_BRANCH}
  if [ $? -ne 0 ]; then
    popd
    set -e
    echo "Fail to update bench script, try to clone"
    rm -rf ${SCRIPT_ROOT}
    clone_bench_scripts
  else
    set -e
    popd
  fi
}

function clone_or_update_bench_scripts() {
  find_bench_scripts_branch
  if [ -d ${SCRIPT_ROOT} ]; then
    update_bench_scripts
  else
    clone_bench_scripts
  fi
  pushd ${SCRIPT_ROOT}
  mvn -nsu install -N
  popd
}

function load_data_into_redis() {
  echo "Load bench data into Redis"
  pushd ${SCRIPT_PATH}
  echo flushdb | redis-cli -n ${REDIS_DB}
  set +e
  wget -nc https://maven-eu.nuxeo.org/nexus/service/local/repositories/public-releases/content/org/nuxeo/tools/testing/data-test-les-arbres/1.1/data-test-les-arbres-1.1.zip -O data.zip
  unzip -o data.zip
  set -e
  # redis-cli don't like unbuffered input
  unset PYTHONUNBUFFERED
  cat data-test*.csv | python ./scripts/inject-arbres.py | redis-cli -n ${REDIS_DB} --pipe
  export PYTHONUNBUFFERED=1
  popd
}

function gatling() {
  if [ -n "$GATLING_2_1" ]; then
    mvn -nsu test gatling:execute -Pbench -Durl=${TARGET} -Dgatling.simulationClass=$@
  else
    mvn -nsu test gatling:test -Pbench -Durl=${TARGET} -Djava.net.preferIPv4Stack=true -Djava.net.preferIPv6Addresses=false -Dgatling.simulationClass=$@
  fi
}

function find_gatling_version() {
  (mvn -nsu dependency:tree | grep gatling-core | grep 2.1.) && export GATLING_2_1="true"
  if [ -n "$GATLING_2_1" ]; then
    echo "Gatling 2.1 detected"
  else
    echo "Gatling > 2.3 detected"
  fi
}

function run_simulations() {
  echo "Run simulations"
  pushd ${SCRIPT_PATH} || exit 2
  mvn -nsu clean
  find_gatling_version
  gatling "org.nuxeo.cap.bench.Sim00Setup"
  # init user ws and give some chance to graphite to init all metrics before mass import
  gatling "org.nuxeo.cap.bench.Sim25WarmUsersJsf"
  gatling "org.nuxeo.cap.bench.Sim10MassImport" -DnbNodes=100000
  gatling "org.nuxeo.cap.bench.Sim20CSVExport"
  gatling "org.nuxeo.cap.bench.Sim15BulkUpdateDocuments"
  #gatling "org.nuxeo.cap.bench.Sim10MassImport" -DnbNodes=1000000 -Dusers=32
  gatling "org.nuxeo.cap.bench.Sim10CreateFolders"
  gatling "org.nuxeo.cap.bench.Sim20CreateDocuments" -Dusers=32
  gatling "org.nuxeo.cap.bench.Sim25WaitForAsync"
  gatling "org.nuxeo.cap.bench.Sim25BulkUpdateFolders" -Dusers=32 -Dduration=180 -Dpause_ms=0
  gatling "org.nuxeo.cap.bench.Sim30UpdateDocuments" -Dusers=32 -Dduration=180
  #gatling "org.nuxeo.cap.bench.Sim30UpdateDocuments" -Dusers=32 -Dduration=400
  gatling "org.nuxeo.cap.bench.Sim35WaitForAsync"
  gatling "org.nuxeo.cap.bench.Sim30Navigation" -Dusers=48 -Dduration=180
  gatling "org.nuxeo.cap.bench.Sim30Search" -Dusers=48 -Dduration=180
  gatling "org.nuxeo.cap.bench.Sim30NavigationJsf" -Dduration=180
  gatling "org.nuxeo.cap.bench.Sim50Bench" -Dnav.users=80 -Dnavjsf=5 -Dupd.user=15 -Dnavjsf.pause_ms=1000 -Dduration=180
  gatling "org.nuxeo.cap.bench.Sim50CRUD" -Dusers=32 -Dduration=120
  gatling "org.nuxeo.cap.bench.Sim55WaitForAsync"
  gatling "org.nuxeo.cap.bench.Sim80ReindexAll"
  # gatling "org.nuxeo.cap.bench.Sim30Navigation" -Dusers=100 -Dduration=120 -Dramp=50
  popd
}

function download_gatling_report_tool() {
  if [ ! -f ${GAT_REPORT_JAR} ]; then
    mvn -DgroupId=org.nuxeo.tools -DartifactId=gatling-report -Dversion=${GAT_REPORT_VERSION} -Dclassifier=capsule-fat -DrepoUrl=http://maven.nuxeo.org/nexus/content/groups/public-snapshot dependency:get
  fi
}

function build_report() {
  report_root="${1%-*}"
  if [ -d ${report_root} ]; then
    report_root = "${report_root}-bis"
  fi
  mkdir ${report_root} || true
  mv $1 ${report_root}/detail
  java -jar ${GAT_REPORT_JAR} -o ${report_root}/overview -g ${GRAPHITE_DASH} ${report_root}/detail/simulation.log
  find ${report_root} -name simulation.log -exec gzip {} \;
}

function build_reports() {
  echo "Building reports"
  download_gatling_report_tool
  for report in `find ${SCRIPT_PATH}/target/gatling -name simulation.log`; do
    build_report `dirname ${report}`
  done
}

function move_reports() {
  echo "Moving reports"
  if [ -d ${SCRIPT_PATH}/target/gatling/results ]; then
    # Gatling 2.1 use a different path for reports
    mv ${SCRIPT_PATH}/target/gatling/results/* ${REPORT_PATH}
  else
    mv ${SCRIPT_PATH}/target/gatling/* ${REPORT_PATH}
  fi
}

function build_stat() {
  # create a yml file with all the stats
  set -x
  java -jar ${GAT_REPORT_JAR} -f -o ${REPORT_PATH} -n data.yml -t ${MUSTACHE_TEMPLATE} \
    -m import,bulk,mbulk,exportcsv,create,createasync,nav,navjsf,search,update,updateasync,bench,crud,crudasync,reindex \
    ${REPORT_PATH}/sim10massimport/detail/simulation.log.gz \
    ${REPORT_PATH}/sim15bulkupdatedocuments/detail/simulation.log.gz \
    ${REPORT_PATH}/sim25bulkupdatefolders/detail/simulation.log.gz \
    ${REPORT_PATH}/sim20csvexport/detail/simulation.log.gz \
    ${REPORT_PATH}/sim20createdocuments/detail/simulation.log.gz \
    ${REPORT_PATH}/sim25waitforasync/detail/simulation.log.gz \
    ${REPORT_PATH}/sim30navigation/detail/simulation.log.gz \
    ${REPORT_PATH}/sim30navigationjsf/detail/simulation.log.gz \
    ${REPORT_PATH}/sim30search/detail/simulation.log.gz \
    ${REPORT_PATH}/sim30updatedocuments/detail/simulation.log.gz \
    ${REPORT_PATH}/sim35waitforasync/detail/simulation.log.gz \
    ${REPORT_PATH}/sim50bench/detail/simulation.log.gz \
    ${REPORT_PATH}/sim50crud/detail/simulation.log.gz \
    ${REPORT_PATH}/sim55waitforasync/detail/simulation.log.gz \
    ${REPORT_PATH}/sim80reindexall/detail/simulation.log.gz
  echo "build_number: $BUILD_NUMBER" >> ${REPORT_PATH}/data.yml
  echo "build_url: \"$BUILD_URL\"" >> ${REPORT_PATH}/data.yml
  echo "job_name: \"$JOB_NAME\"" >> ${REPORT_PATH}/data.yml
  echo "dbprofile: \"$dbprofile\"" >> ${REPORT_PATH}/data.yml
  echo "bench_suite: \"$benchsuite\"" >> ${REPORT_PATH}/data.yml
  echo "nuxeonodes: $nbnodes" >> ${REPORT_PATH}/data.yml
  echo "esnodes: $esnodes" >> ${REPORT_PATH}/data.yml
  echo "classifier: \"$classifier\"" >> ${REPORT_PATH}/data.yml
  echo "distribution: \"$distribution\"" >> ${REPORT_PATH}/data.yml
  echo "default_category: \"$category\"" >> ${REPORT_PATH}/data.yml
  echo "kafka: $kafka" >> ${REPORT_PATH}/data.yml
  # Calculate benchmark duration between import and reindex
  d1=$(grep import_date ${REPORT_PATH}/data.yml| sed -e 's,^[a-z\_]*\:\s,,g')
  d2=$(grep reindex_date ${REPORT_PATH}/data.yml | sed -e 's,^[a-z\_]*\:\s,,g')
  dd=$(grep reindex_duration ${REPORT_PATH}/data.yml | sed -e 's,^[a-z\_]*\:\s,,g')
  t1=$(date -d "$d1" +%s)
  t2=$(date -d "$d2" +%s)
  benchmark_duration=$(echo $(( ($t2 - $t1) + ${dd%.*} )) )
  echo "benchmark_duration: $benchmark_duration" >> ${REPORT_PATH}/data.yml
  echo "" >> ${REPORT_PATH}/data.yml
  set +x
}

function clean() {
  rm -rf ${REPORT_PATH} || true
  mkdir ${REPORT_PATH}
}

# -------------------------------------------------------
# main
#
clean
clone_or_update_bench_scripts
load_data_into_redis
run_simulations
set +e
build_reports
move_reports
build_stat
