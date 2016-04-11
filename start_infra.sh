#!/bin/bash -e
# Start the required infra to run a bench
cd $(dirname $0)
HERE=`readlink -e .`

db="pgsql"
mongo="false"
distrib="lastbuild"
keypair="Jenkins"

function help {
    echo "Usage: $0 -P<dbprofile> -m -d<distribution>"
    echo "  -P dbprofile    : one of pgsql,mssql,oracle12c,mysql (default: pgsql)"
    echo "  -m              : use mongodb"
    echo "  -d distribution : nuxeo distribution (default: lastbuild) (see bin/get-nuxeo-distribution.py for details)"
    echo "  -k keypair      : use this keypair instead of jenkins"
    echo "  -n nodes        : the number of Nuxeo nodes in the cluster, default=2"
    exit 0
}

while getopts ":P:md:k:n:h" opt; do
    case $opt in
        h)
            help
            ;;
        P)
            case $OPTARG in
                mongodb)
                    db="pgsql"
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
        m)
            mongo="true"
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
./bin/get-nuxeo-distribution.py -v $distrib -o $HERE/deploy/nuxeo-distribution.zip
cp /opt/build/hudson/instance.clid $HERE/deploy/
echo "nuxeo-platform-importer" > $HERE/deploy/mp-list

# Set db options
echo "---" > ansible/group_vars/all/custom.yml
echo "dbprofile: $db" >> ansible/group_vars/all/custom.yml
echo "mongo: $mongo" >> ansible/group_vars/all/custom.yml
echo "keypair: $keypair" >> ansible/group_vars/all/custom.yml

# Set nb of Nuxeo nodes
perl -pi -e "s,counts\:\n\s+nuxeo\:[^\n]+\n,counts\:\n  nuxeo: ${nbnodes}\n,igs" -0777 ansible/group_vars/all/main.yml

# Setup virtualenv
if [ ! -d venv ]; then
    virtualenv venv
fi
. venv/bin/activate
pip install -r ansible/requirements.txt

# Run ansible scripts
pushd ansible
ansible-playbook -i inventory.py start_nodes.yml -v
ansible-playbook -i inventory.py setup.yml -v
popd

