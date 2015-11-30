#!/bin/bash -e

cd $(dirname $0)

db="pgsql"
mongo="false"
distrib="lastbuild"
keypair="jenkins"

function help {
    echo "Usage: $0 -P<dbprofile> -m -d<distribution>"
    echo "  -P dbprofile    : one of pgsql,mssql,oracle12c,mysql (default: pgsql)"
    echo "  -m              : use mongodb"
    echo "  -d distribution : nuxeo distribution (default: lastbuild) (see bin/get-nuxeo-distribution for details)"
    echo "  -k keypair      : use this keypair instead of jenkins"
    exit 0
}

while getopts ":P:md:k:h" opt; do
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
if [ -d deploy ]; then
    rm -rf deploy
fi
mkdir deploy
./bin/get-nuxeo-distribution -v $distrib -o deploy/nuxeo-distribution.zip
cp /opt/build/hudson/instance.clid deploy/
echo "nuxeo-platform-importer" > deploy/mp-list

# Set db options
echo "---" > ansible/group_vars/all/custom.yml
echo "dbprofile: $db" >> ansible/group_vars/all/custom.yml
echo "mongo: $mongo" >> ansible/group_vars/all/custom.yml
echo "keypair: $keypair" >> ansible/group_vars/all/custom.yml
#perl -p -i -e "s/^dbprofile:.*$/dbprofile: $db/" ansible/group_vars/all.yml
#perl -p -i -e "s/^mongo:.*$/mongo: $mongo/" ansible/group_vars/all.yml
#perl -p -i -e "s/^keypair:.*$/keypair: $keypair/" ansible/group_vars/all.yml

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

