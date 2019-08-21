#!/bin/bash

#
# Prerequisites
#

# SElinux
sed -i 's/^SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
setenforce 0

# Packages
yum install -y vim git epel-release wget
yum install -y s3cmd awscli
yum install -y httpd yum-plugin-priorities yum-utils createrepo

#
# HTTP Setup
#

# Rendered content
cat << EOF > /etc/httpd/conf.d/architect.conf
<Directory /var/lib/architect/clusters/>
    Options Indexes MultiViews FollowSymlinks
    AllowOverride None
    Require all granted
    Order Allow,Deny
    Allow from all
</Directory>
Alias /architect /var/lib/architect/clusters/
EOF
systemctl enable httpd
systemctl start httpd

curl https://openflighthpc.s3-eu-west-1.amazonaws.com/repos/openflight/openflight.repo > /etc/yum.repos.d/openflight.repo

#
# Install Tools
#
curl https://openflighthpc.s3-eu-west-1.amazonaws.com/repos/openflight/openflight.repo > /etc/yum.repos.d/openflight.repo

yum clean all
yum install -y flight-architect flight-cloud flight-manage flight-metal flight-inventory

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
[ -z "$PS1" ] && return
    # Check user can passwordless sudo
    if timeout 2 sudo -n id >> /dev/null 2>&1; then
        if [ -f /opt/flight/.firstrun ] ; then
            flexec ruby /opt/flight/opt/runway/bin/banner
            sudo bash -l /root/hub-configure.sh
        else
            flight help
        fi
        sudo su -
    fi
fi
EOF
touch /opt/flight/.firstrun

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
rm -rf /opt/flight/opt/architect/data/base/lib/templates/{libvirt,vbox} /opt/flight/opt/architect/data/base/etc/configs/platforms/{libvirt,vbox}.yaml

# Remove some subcommands
## Plugins
sed -i '/^  plugin_list:/,/^    action: Commands::Plugin::Deactivate/d' /opt/flight/opt/architect/lib/underware/cli_helper/config.yaml
sed -i '/^  plugin:/,/^      deactivate: \*plugin_deactivate/d' /opt/flight/opt/architect/lib/underware/cli_helper/config.yaml
## Each
sed -i '/^  each:/,/^      - \*gender_option/d' /opt/flight/opt/architect/lib/underware/cli_helper/config.yaml
## Eval
sed -i '/^  eval:/,/^      - \*render_option/d' /opt/flight/opt/architect/lib/underware/cli_helper/config.yaml

