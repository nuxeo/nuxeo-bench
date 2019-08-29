#!/bin/bash -e
# Start the required infra to run a bench
cd $(dirname $0)
HERE=`readlink -e .`

db="pgsql"
nosqldb="none"
mongo="false"
kafka="false"
distrib="lastbuild"
keypair="jenkins-pub"
addons=""
nbnodes=2
esnodes=3
jdk=/usr/lib/jvm/java-11

function help {
    echo "Usage: $0 -P<dbprofile> -m -d<distribution>"
    echo "  -P dbprofile    : one of pgsql,mssql,oracle12c,mysql (default: pgsql)"
    echo "  -d distribution : nuxeo distribution (default: lastbuild) (see bin/get-nuxeo-distribution.py for details)"
    echo "  -k keypair      : use this keypair instead of jenkins"
    echo "  -n nodes        : the number of Nuxeo nodes in the cluster, default=2"
    echo "  -e nodes        : the number of Elasticsearch nodes in the cluster, default=3"
    echo "  -i addons       : a list of addons separated by comma to install on Nuxeo nodes"
    echo "  -K <boolean>    : use Kafka"
    exit 0
}

while getopts ":P:md:k:n:e:i:K:j:h" opt; do
    case $opt in
        h)
            help
            ;;
        P)
            case $OPTARG in
                mongodb)
                    db="mongodb"
                    mongo="true"
                    ;;
                pgsql)
                    db="pgsql"
                    ;;
                mssql)
                    db="mssql"
                    ;;
                oracle12c)
                    db="oracle12c"
                    ;;
                mysql)
                    db="mysql"
                    ;;
                *)
                    echo "Invalid db profile: $OPTARG" >&2
                    exit 1
                    ;;
            esac
            ;;
        d)
            distrib=$OPTARG
            ;;
        k)
            keypair=$OPTARG
            ;;
        n)
            nbnodes=$OPTARG
            ;;
        e)
            esnodes=$OPTARG
            ;;
        i)
            addons=$OPTARG
            ;;
        j)
            jdk=$OPTARG
            ;;
        K)
            if [ "$OPTARG" == "true" ]; then
                kafka="true"
            fi
            ;;
        :)
            echo "Option -$OPTARG requires an argument" >&2
            exit 1
            ;;
        \?)
            echo "Invalid option: -$OPTARG" >&2
            exit 1
            ;;
    esac
done

# Prepare distribution
if [ -d $HERE/deploy ]; then
    rm -rf $HERE/deploy
fi
mkdir $HERE/deploy
sudo apt-get update
sudo apt-get -q -y install python-lxml python-requests
./bin/get-nuxeo-distribution.py -v $distrib -o $HERE/deploy/nuxeo-distribution.zip -j $jdk
cp /opt/build/hudson/instance.clid $HERE/deploy/
echo "nuxeo-jsf-ui" > $HERE/deploy/mp-list
echo "nuxeo-platform-importer" >> $HERE/deploy/mp-list
for addon in $(echo $addons | tr "," "\n")
do
    echo $addon >> $HERE/deploy/mp-list
done

# Set db options
echo "---" > ansible/group_vars/all/custom.yml
echo "dbprofile: $db" >> ansible/group_vars/all/custom.yml
echo "nosqldbprofile: $nosqldb" >> ansible/group_vars/all/custom.yml
echo "mongo: $mongo" >> ansible/group_vars/all/custom.yml
echo "keypair: $keypair" >> ansible/group_vars/all/custom.yml
echo "kafkaflag: $kafka" >> ansible/group_vars/all/custom.yml

# Set nb of Nuxeo and elastic nodes
perl -pi -e "s,counts\:\n\s+nuxeo\:[^\n]+\n\s+es\:[^\n]+\n,counts\:\n  nuxeo: ${nbnodes}\n  es: ${esnodes}\n,igs" -0777 ansible/group_vars/all/main.yml

# Setup virtualenv
if [ ! -d venv ]; then
    virtualenv venv
fi
. venv/bin/activate
pip install --upgrade setuptools
pip install -r ansible/requirements.txt

# Run ansible scripts
pushd ansible
ansible-playbook -i inventory.py start_nodes.yml -v
ansible-playbook -i inventory.py setup.yml -v
popd

