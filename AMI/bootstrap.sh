#!/bin/bash

# Increase open files limit
echo '*       soft    nofile      4096' >> /etc/security/limits.conf
echo '*       hard    nofile      8192' >> /etc/security/limits.conf

# Upgrade packages and install ssh, vim
export DEBIAN_FRONTEND=noninteractive
locale-gen en_US.UTF-8
update-locale LANG=en_US.UTF-8
apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv 7F0CEB10
echo "deb http://repo.mongodb.org/apt/ubuntu trusty/mongodb-org/3.0 multiverse" > /etc/apt/sources.list.d/mongodb-org-3.0.list
apt-get update
apt-get -q -y upgrade
apt-get -q -y install openssh-server openssh-client vim postfix curl git
update-alternatives --set editor /usr/bin/vim.basic

# Secure postfix
perl -p -i -e "s/^inet_interfaces\s*=.*$/inet_interfaces=127.0.0.1/" /etc/postfix/main.cf

# Install docker (for ffmpeg compilation)
curl -sSL https://get.docker.com/ | sh

# Compile & install ffmpeg
git clone git://github.com/nuxeo/nuxeo-tools-docker.git
pushd nuxeo-tools-docker/ffmpeg
docker build -t nuxeo/ffmpeg-deb-pkg .
docker run --rm=true -v $(pwd)/packages:/packages:rw nuxeo/ffmpeg-deb-pkg
dpkg -i packages/ffmpeg-nuxeo_2.7.2-1_amd64.deb
popd
rm -rf nuxeo-tools-docker
docker images -q | xargs docker rmi

# Install Java 7
apt-get -q -y install openjdk-7-jdk
update-java-alternatives -s java-1.7.0-openjdk-amd64

# Install Nuxeo dependencies & misc tools
apt-get -q -y install \
    python python-requests python-lxml \
    imagemagick ufraw ffmpeg2theora \
    poppler-utils exiftool libwpd-tools \
    libreoffice zip unzip redis-tools \
    postgresql-client screen wget mongodb-org-shell \
    atop sysstat

# Install Java 8
mkdir -p /usr/lib/jvm
curl -o/tmp/jdk-8-linux-x64.tgz -L --insecure --header 'Cookie: oraclelicense=accept-securebackup-cookie' 'http://download.oracle.com/otn-pub/java/jdk/8u65-b17/jdk-8u65-linux-x64.tar.gz'
tar xzf /tmp/jdk-8-linux-x64.tgz -C /usr/lib/jvm
rm /tmp/jdk-8-linux-x64.tgz
ln -s /usr/lib/jvm/jdk1.8.0_65 /usr/lib/jvm/java-8
update-alternatives --install /usr/bin/java java /usr/lib/jvm/java-8/jre/bin/java 1081
update-alternatives --set java /usr/lib/jvm/java-8/jre/bin/java

# Get logstash image
docker pull logstash:2.1

# Install (disabled) Diamond
apt-get -q -y install make pbuilder python-mock python-configobj python-support cdbs
cd /usr/local/src
git clone git://github.com/python-diamond/Diamond
cd Diamond
make builddeb
dpkg -i build/diamond_*.deb
service diamond stop
update-rc.d diamond disable

# Prepare cleanup
cat << EOF > /mnt/cleanup.sh
#!/bin/bash
apt-get clean
rm -f /etc/udev/rules.d/70-persistent*
rm -rf /var/lib/cloud/*
rm -rf /tmp/*
rm -rf /var/tmp/*
shred -u /root/.bash_history
shred -u /home/ubuntu/.bash_history
invoke-rc.d rsyslog stop
find /var/log -type f -exec rm {} \;
rm -f /etc/ssh/*key*
rm -rf /root/.ssh
rm -rf /home/ubuntu/.ssh
shutdown -h now
EOF
chmod +x /mnt/cleanup.sh

# Wait for cloud-init to finish, run cleanup and stop instance
at -t $(date --date="now + 2 minutes" +"%Y%m%d%H%M") -f /mnt/cleanup.sh

