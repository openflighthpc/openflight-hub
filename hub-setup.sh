#!/bin/bash

#
# Prerequisites
#

# SElinux
sed -i 's/^SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
setenforce 0

# Packages
yum install -y vim git epel-release
yum install -y s3cmd awscli

#
# Repo
#

# Create Repo
yum install -y httpd yum-plugin-priorities yum-utils createrepo

mkdir -p /opt/repo/openflight

cat << 'EOF' > /opt/repo/mirror.conf
[main]
cachedir=/var/cache/yum/$basearch/$releasever
keepcache=0
debuglevel=2
logfile=/var/log/yum.log
exactarch=1
obsoletes=1
gpgcheck=1
plugins=1
installonly_limit=5
reposdir=/dev/null

EOF
curl https://openflighthpc.s3-eu-west-1.amazonaws.com/repos/openflight/openflight.repo >> /opt/repo/mirror.conf

reposync -nm --config /opt/repo/mirror.conf -r openflight -p /opt/repo/openflight --norepopath
createrepo /opt/repo/openflight

# Server Updater Script
cat << 'EOF' > /opt/repo/updateserver.sh
IP="$(curl http://169.254.169.254/latest/meta-data/public-ipv4)"

# Client repo file
cat << EOD > /opt/repo/client.repo
[openflight]
name=openflight
baseurl=http://$IP/repo/openflight
description=OpenFlight Tool Repository
enabled=1
gpgcheck=0
EOD

# Client updater script
cat << EOD > /opt/repo/updateclient.sh
curl http://$IP/repo/client.repo > /etc/yum.repos.d/client.repo
EOD
EOF

bash /opt/repo/updateserver.sh

# Add updater to crontab
(crontab -l ; echo '@reboot  bash /opt/repo/updateserver.sh') |crontab -

#
# HTTP Setup
#

# Repo
cat << EOF > /etc/httpd/conf.d/repo.conf
<Directory /opt/repo/>
    Options Indexes MultiViews FollowSymlinks
    AllowOverride None
    Require all granted
    Order Allow,Deny
    Allow from all
</Directory>
Alias /repo /opt/repo
EOF

# Rendered content
cat << EOF > /etc/httpd/conf.d/architect.conf
<Directory /var/lib/underware/clusters/>
    Options Indexes MultiViews FollowSymlinks
    AllowOverride None
    Require all granted
    Order Allow,Deny
    Allow from all
</Directory>
Alias /architect /var/lib/underware/clusters/
EOF
systemctl enable httpd
systemctl start httpd

#
# Install Tools
#
bash /opt/repo/updateclient.sh
yum clean all

yum install -y flight-architect flight-cloud flight-manage flight-inventory

_yes=true /opt/flight/bin/flenable

#
# Pretty Prompt
#
cat << "EOF" > /etc/profile.d/openflight-prompt.sh
if [ "$PS1" ]; then
  PS1="[\u@\h\[\e[1;34m\] [OpenFlight Hub]\[\e[0m\] \W]\\$ "
fi
EOF

# First run configuration
cat << 'EOF' > /etc/profile.d/firstrun.sh
if [ "$USER" == "centos" ] ; then
    if [ -f /home/centos/.firstrun ] ; then
        flexec ruby /opt/flight/opt/runway/bin/banner
        sudo bash -l /root/hub-configure.sh
    else
        flight help
    fi
    sudo su -
fi
EOF
touch /home/centos/.firstrun

curl https://raw.githubusercontent.com/openflighthpc/openflight-hub/master/hub-configure.sh > /root/hub-configure.sh

#####################################################
#                                                   #
# EVERYTHING BELOW HERE SHOULDN'T BE IN THIS SCRIPT #
#                                                   #
# The below commands and fixes are currently here   #
# identify the changes that will need to be made    #
# elsewhere in order to provide the desired working #
# of the various flight apps with the flight hub    #
#                                                   #
#####################################################


#
# ARCHITECT
#

# Remove unnecessary platforms
rm -rf /opt/flight/opt/architect/data/base/lib/templates/{kickstart,libvirt,vbox} /opt/flight/opt/architect/data/base/etc/configs/platforms/{kickstart,libvirt,vbox}.yaml

# Remove some subcommands
## Plugins
sed -i '/^  plugin_list:/,/^    action: Commands::Plugin::Deactivate/d' /opt/flight/opt/architect/lib/underware/cli_helper/config.yaml
sed -i '/^  plugin:/,/^      deactivate: \*plugin_deactivate/d' /opt/flight/opt/architect/lib/underware/cli_helper/config.yaml
## Each
sed -i '/^  each:/,/^      - \*gender_option/d' /opt/flight/opt/architect/lib/underware/cli_helper/config.yaml
## Eval
sed -i '/^  eval:/,/^      - \*render_option/d' /opt/flight/opt/architect/lib/underware/cli_helper/config.yaml

