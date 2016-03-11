#!/bin/bash
# Build a nuxeo tomcat distrib on a branch
cd $(dirname $0)
# defaults
BRANCH=master
PARENT_BRANCH=master
HERE=`readlink -e .`
TMP=$HERE/.build
OUTPUT=$TMP/nuxeo-distribution.zip
MVN_HOME=/opt/build/tools/maven3
# fail on any command error
set -e

function help {
  echo "Usage: $0 -b<branch> -f<fallback> -o<zipfile>"
  echo "  -b branch       : the git branch to build the distrib"
  echo "  -f fallback     : the breanch to falls back, default is master"
  echo "  -o zipfile      : the nuxeo zip archive output file"
  echo "  -t tempdir      : where to checkout the src to build"
  echo "  -j java_home    : JAVA_HOME"
  exit 0
}


function setup_env {
  if [ ! -z $JDK_PATH ]; then
    export JAVA_HOME=$JDK_PATH
    export PATH=$JDK_PATH/bin:$PATH
  fi
  if [ -d $MAVEN_HOME/bin ]; then
    export PATH=$MVN_HOME/bin:$PATH
  fi
}

function clean_tmp {
  echo "### Cleaning temp dir: $TMP"
  if [ -e $TMP/nuxeo ]; then
    rm -rf "$TMP/nuxeo"
  fi
  if [ -e $TMP/m2  ]; then
    rm -rf "$TMP/m2"
  fi
  mkdir -p $TMP/m2
  mkdir -p $TMP/nuxeo
}

function clone_src {
  echo "### Cloning nuxeo source in: $TMP/nuxeo"
  time {
  pushd "$TMP/nuxeo"
    git clone git@github.com:nuxeo/nuxeo.git .
    git checkout $BRANCH 2&>/dev/null || git checkout $PARENT_BRANCH
    . scripts/gitfunctions.sh
    echo "### Switch to branch $BRANCH if exists else falls back on $PARENT_BRANCH"
    ./clone.py $BRANCH -f $PARENT_BRANCH
    (! (gitfa status --porcelain | grep -e "^U"))
    popd
  }
  echo "### Clone done"
}

function build_nuxeo {
  echo "### Building Nuxeo tomcat distrib"
  time {
    pushd "$TMP/nuxeo"
    # exclude npm build that fails randomly
    time MAVEN_OPTS="-Xms1024m -Xmx4096m -XX:MaxPermSize=2048m" mvn -Dmaven.repo.local="$TMP/m2" -nsu -am -pl nuxeo-distribution/nuxeo-distribution-tomcat -Paddons,distrib,qa -DskipTests=true -DexcludeGroupIds=org.nuxeo  -T16 install || true
    #time MAVEN_OPTS="-Xms1024m -Xmx4096m -XX:MaxPermSize=2048m" mvn -Dmaven.repo.local="$TMP/m2" -nsu -am -pl nuxeo-distribution/nuxeo-distribution-tomcat,-addons/nuxeo-review-workflows-dashboards,-addons/nuxeo-salesforce,-addons/nuxeo-salesforce,-nuxeo-features/nuxeo-admin-center/nuxeo-admin-center-analytics,-addons/nuxeo-platform-spreadsheet,-addons/nuxeo-travel-expenses,-addons/nuxeo-salesforce/nuxeo-salesforce-web,-addons/nuxeo-salesforce/nuxeo-salesforce-core -Paddons,distrib,qa -DskipTests=true -DexcludeGroupIds=org.nuxeo  -T16 install || true
    popd
  }
  echo "### Build done"
}

function copy_zip {
    cp $TMP/nuxeo/nuxeo-distribution/nuxeo-distribution-tomcat/target/nuxeo-distribution-*-nuxeo-cap.zip $OUTPUT
    echo "### zip ready: $OUTPUT"
}

while getopts "b:f:t:j:o:h" opt; do
    case $opt in
        h)
            help
            ;;
        b)
            BRANCH=$OPTARG
            ;;
        f)
            PARENT_BRANCH=$OPTARG
            ;;
        t)
            TMP=$OPTARG
            ;;
        j)
            JDK_HOME=$OPTARG
            ;;
        o)
            OUTPUT=$OPTARG
            ;;
        ?)
            echo "Invalid option: -$OPTARG" >&2
            exit 1
            ;;
    esac
done

setup_env
clean_tmp
clone_src
build_nuxeo
copy_zip
