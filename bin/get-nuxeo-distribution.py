#!/usr/bin/env python
import argparse
import re
import requests
import shutil
import sys
import urlparse
from lxml import html
from subprocess import check_output

def parse_args():
    parser = argparse.ArgumentParser(description='Download nuxeo distribution')
    parser.add_argument('-v', dest='version', type=str, default='lastbuild',
        help='one of: ' + \
             'lastbuild (downloads the last build from nuxeo-distribution-master), ' + \
             'lastitbuild (downloads the last IT build distribution), ' + \
             'lastitsuccess (downloads the last successful IT build distribution), ' + \
             'lastlts (downloads the latest LTS from cdn.nuxeo.com), ' + \
             'lastft (downloads the latest FastTrack from cdn.nuxeo.com), ' + \
             'lastsnapshot (downloads the latest published snapshot from community.nuxeo.com), ' + \
             'version (downloads that version from community.nuxeo.com (SNAPSHOT) or cdn.nuxeo.com (release)), ' + \
             'url ((http:// or https://): downloads that URL, no resolving done), ' + \
             'file ((file:// or starts with /): uses that local file)' + \
             'branch build a new distribution on using this branch fallback')
    parser.add_argument('-o', dest='output', type=str, default='nuxeo-distribution.zip',
        help='output file')
    parser.add_argument('-b', dest='branch', type=str, default='master',
                        help='build the distrib instead of download, using the git branch')
    parser.add_argument('-f', dest='fallback', type=str, default='master',
                        help='fallback to use when building from a branch')
    return parser

def get_distrib(version):
    print 'Looking for %s ...' % arg
    if arg == 'lastbuild':
        base = 'http://qa.nuxeo.org/jenkins/job/nuxeo-distribution-master/lastSuccessfulBuild/artifact/nuxeo-distribution/nuxeo-distribution-tomcat/target/'
        r = requests.get(base)
        tree = html.fromstring(r.text)
        archive = tree.xpath('//table[@class="fileList"]/tr/td[2]/a[starts-with(@href,"nuxeo-distribution-tomcat-") and contains(@href,"-nuxeo-cap.zip")]/@href')[0]
        url = urlparse.urljoin(base, archive)
    elif arg == 'lastitbuild':
        base = 'http://qa.nuxeo.org/jenkins/job/IT-nuxeo-master-build/lastBuild/artifact/archives/'
        r = requests.get(base)
        tree = html.fromstring(r.text)
        archive = tree.xpath('//table[@class="fileList"]/tr/td[2]/a[starts-with(@href,"nuxeo-cap-") and contains(@href,"-tomcat.zip")]/@href')[0]
        url = urlparse.urljoin(base, archive)
    elif arg == 'lastitsuccess':
        base = 'http://qa.nuxeo.org/jenkins/job/IT-nuxeo-master-build/lastSuccessfulBuild/artifact/archives/'
        r = requests.get(base)
        tree = html.fromstring(r.text)
        archive = tree.xpath('//table[@class="fileList"]/tr/td[2]/a[starts-with(@href,"nuxeo-cap-") and contains(@href,"-tomcat.zip")]/@href')[0]
        url = urlparse.urljoin(base, archive)
    elif arg == 'lastlts':
        url = 'http://community.nuxeo.com/static/latest-lts/'
    elif arg == 'lastft':
        url = 'http://community.nuxeo.com/static/latest-ft/'
    elif arg == 'lastsnapshot':
        url = 'http://community.nuxeo.com/static/latest-snapshot/'
    elif arg.startswith('http://') or arg.startswith('https://'):
        url = arg
    elif arg.startswith('file://') or arg.startswith('/'):
        url = arg
    elif re.match('^[0-9\.]+$', arg):
        url = 'http://cdn.nuxeo.com/nuxeo-%s/nuxeo-cap-%s-tomcat.zip' % (arg, arg)
    elif re.match('^[0-9\.]+-SNAPSHOT$', arg):
        url = 'http://community.nuxeo.com/static/latest-snapshot/nuxeo-distribution-tomcat,%s,nuxeo-cap.zip' % arg[:-9]
    else:
        print 'Unknown version: %s' % arg
        sys.exit(1)

    if arg.startswith('file://'):
        shutil.copy(url[7:], output)
    elif arg.startswith('/'):
        shutil.copy(url, output)
    else:
        print 'Downloading %s ...' % url
        r = requests.get(url, stream=True)
        with open(output, 'wb') as f:
            for chunk in r.iter_content(chunk_size=1024):
                if chunk:
                    f.write(chunk)
        print "Download complete."


def build_distrib(build, fallback):
    print "Building distrib from branch: " + branch + " fallback: " + master
    check_output()

if [ &quot;\$CLEAN&quot; = true ] || [ ! -e .git ]; then
  rm -rf * .??*
  git clone git@github.com:nuxeo/nuxeo.git .
fi
git checkout \$BRANCH 2&gt;/dev/null || git checkout \$PARENT_BRANCH

. scripts/gitfunctions.sh
if [ &quot;\$CLEAN&quot; = false ]; then
  gitfa fetch --all
  gitfa checkout \$PARENT_BRANCH
  gitfa pull --rebase
  # TODO: try something like gitfa diff --name-only --diff-filter=U
  (! (gitfa status --porcelain | grep -e &quot;^U&quot;))
fi

# switch on feature \$BRANCH if exists, else falls back on \$PARENT_BRANCH
./clone.py \$BRANCH -f \$PARENT_BRANCH
gitfa rebase origin/\$PARENT_BRANCH
(! (gitfa status --porcelain | grep -e &quot;^U&quot;))
if [ &quot;\$MERGE_BEFORE_BUILD&quot; = true ]; then
  gitfa checkout \$PARENT_BRANCH
  gitfa pull --rebase
  set +e
  gitfa merge --no-ff \$BRANCH --log
  set -e
  # TODO: try something like gitfa diff --name-only --diff-filter=U
  (! (gitfa status --porcelain | grep -e &quot;^U&quot;))
fi

rm -rf \$WORKSPACE/.repository/org/nuxeo/


if __name__ == '__main__':
    parser = parse_args()
    args = parser.parse_args()
    output = args.output
    if args.build:
        build_distrib(args.build, args.fallback)
    else:
        get_distrib(args.version)
    sys.exit(0)
