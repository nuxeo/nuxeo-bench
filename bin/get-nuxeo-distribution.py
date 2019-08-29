#!/usr/bin/env python
import os
import argparse
import re
import requests
import shutil
import sys
import urlparse
from lxml import html
import subprocess

parser = argparse.ArgumentParser(description='Download nuxeo distribution')
parser.add_argument('-v', dest='version', type=str, default='lastbuild',
                    help='one of: ' + \
                    'lastbuild (downloads the last build from nuxeo-distribution-master), ' + \
                    'lastitbuild (downloads the last IT build distribution), ' + \
                    'lastitsuccess (downloads the last successful IT build distribution), ' + \
                    'lastlts (downloads the latest LTS from cdn.nuxeo.com), ' + \
                    'lastft (downloads the latest FastTrack from cdn.nuxeo.com), ' + \
                    'lastsnapshot (downloads the latest published snapshot from community.nuxeo.com), ' + \
                    'VERSION (downloads that version from community.nuxeo.com (SNAPSHOT) or cdn.nuxeo.com (release)), ' + \
                    'URL ((http:// or https://): downloads that URL, no resolving done), ' + \
                    'FILE ((file:// or starts with /): uses that local file)'  + \
                    'BRANCH (build Nuxeo distribution from a git branch fallback on master)' +\
                    'BRANCH@DATE (build Nuxeo distribution from a git branch as it was the date, the date format yyyy-mm-dd)' +\
                    'BRANCH/FALLBACK (build Nuxeo distribution from a git branch fallback on FALLBACK branch)')
parser.add_argument('-o', dest='output', type=str, default='nuxeo-distribution.zip',
    help='output file')
parser.add_argument('-j', dest='jdk', type=str, default='/usr/lib/jvm/java-11',
    help='JDK HOME to use when building a distribution from a branch')

args = parser.parse_args()

arg = args.version
output = args.output
jdk = args.jdk

print 'Looking for version %s ...' % arg

if arg == 'lastbuild':
    base = 'http://qa.nuxeo.org/jenkins/job/master/job/nuxeo-distribution-master/lastSuccessfulBuild/artifact/nuxeo-distribution/nuxeo-server-tomcat/target/'
    r = requests.get(base)
    tree = html.fromstring(r.text)
    archive = tree.xpath('//table[@class="fileList"]/tr/td[2]/a[starts-with(@href,"nuxeo-server-tomcat-") and contains(@href,".zip")]/@href')[0]
    url = urlparse.urljoin(base, archive)
elif arg == 'lastitbuild':
    base = 'http://qa.nuxeo.org/jenkins/job/Deploy/job/IT-nuxeo-master-build/lastBuild/artifact/archives/'
    r = requests.get(base)
    tree = html.fromstring(r.text)
    archive = tree.xpath('//table[@class="fileList"]/tr/td[2]/a[starts-with(@href,"nuxeo-server-") and contains(@href,"-tomcat.zip")]/@href')[0]
    url = urlparse.urljoin(base, archive)
elif arg == 'lastitsuccess':
    base = 'http://qa.nuxeo.org/jenkins/job/Deploy/job/IT-nuxeo-master-build/lastSuccessfulBuil/archives/'
    r = requests.get(base)
    tree = html.fromstring(r.text)
    archive = tree.xpath('//table[@class="fileList"]/tr/td[2]/a[starts-with(@href,"nuxeo-server-") and contains(@href,"-tomcat.zip")]/@href')[0]
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
    v1 = int(arg.split(".")[0])
    v2 = int(arg.split(".")[1])
    if v1 < 8 or (v1 == 8 and v2 < 10):
        url = 'http://cdn.nuxeo.com/nuxeo-%s/nuxeo-cap-%s-tomcat.zip' % (arg, arg)
    else:
        url = 'http://cdn.nuxeo.com/nuxeo-%s/nuxeo-server-%s-tomcat.zip' % (arg, arg)
elif re.match('^[0-9\.]+-SNAPSHOT$', arg):
    v0 = arg.split("-")[0]
    v1 = int(v0.split(".")[0])
    v2 = int(v0.split(".")[1])
    if v1 < 8 or (v1 == 8 and v2 < 10):
        url = 'http://community.nuxeo.com/static/latest-snapshot/nuxeo-distribution-tomcat,%s,nuxeo-cap.zip' % arg[:-9]
    else:
        url = 'http://community.nuxeo.com/static/latest-snapshot/nuxeo-server,%s,tomcat.zip' % arg[:-9]
else:
    cmd = os.path.join(os.path.dirname(os.path.realpath(__file__)), "build-distribution.sh")
    branches = arg.split('/')
    if '@' in branches[0]:
        branch_date = branches[0].split('@')
        param = [cmd, "-b", branch_date[0], "-d", branch_date[1], "-o", output]
    else:
        param = [cmd, "-b", branches[0], "-o", output]
    if len(branches) > 1:
        param.extend(["-f", branches[1]])
    param.extend(["-j", jdk])
    subprocess.check_call(param)
    sys.exit(0)

if url.startswith('file://'):
    shutil.copy(url[7:], output)
elif url.startswith('/'):
    shutil.copy(url, output)
else:
    print 'Downloading %s ...' % url
    r = requests.get(url, stream=True)
    with open(output, 'wb') as f:
        for chunk in r.iter_content(chunk_size=1024):
            if chunk:
                f.write(chunk)
    print "Download complete."

