#!/bin/bash

# Increase open files limit
echo '*       soft    nofile      4096' >> /etc/security/limits.conf
echo '*       hard    nofile      8192' >> /etc/security/limits.conf

# Upgrade packages and install ssh, vim
export DEBIAN_FRONTEND=noninteractive
locale-gen en_US.UTF-8
update-locale LANG=en_US.UTF-8

# add mongo key and ppa
apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv 0C49F3730359A14518585931BC711F9BA15703C6
echo "deb [ arch=amd64,arm64 ] http://repo.mongodb.org/apt/ubuntu xenial/mongodb-org/3.4 multiverse" | tee /etc/apt/sources.list.d/mongodb-org-3.4.list

# ffmpeg
add-apt-repository ppa:jonathonf/ffmpeg-3

apt-get update
apt-get -q -y upgrade


# Install Nuxeo dependencies & misc tools
apt-get -q -y install openssh-server openssh-client vim postfix curl git atop sysstat screen tree bc \
    ffmpeg libav-tools x264 x265 \
    python python-requests python-lxml \
    imagemagick ufraw ffmpeg2theora \
    poppler-utils exiftool libwpd-tools \
    libreoffice zip unzip redis-tools \
    postgresql-client screen wget mongodb-org-shell \
    redis-server openjdk-8-jdk

ln -s /usr/lib/jvm/java-8-openjdk-amd64 /usr/lib/jvm/java-8

# editor
update-alternatives --set editor /usr/bin/vim.basic

# Secure postfix
perl -p -i -e "s/^inet_interfaces\s*=.*$/inet_interfaces=127.0.0.1/" /etc/postfix/main.cf

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

