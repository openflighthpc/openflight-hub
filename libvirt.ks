install
text
keyboard uk
firstboot --disable
lang en_GB
skipx
network --device eth2 --bootproto dhcp
rootpw password
firewall --disabled
authconfig --enableshadow --enablemd5
selinux --disabled
timezone --utc Europe/London
bootloader --location=mbr --append="console=tty0 console=ttyS0,115200"
zerombr
clearpart --all --drives=vda --initlabel

part biosboot --fstype=biosboot --size=1
part /boot --fstype ext4 --size=512 --ondisk=vda
part / --fstype ext4 --size=1024 --ondisk vda --grow
reboot

%packages --ignoremissing
@core
@base
vim
emacs
xauth
xhost
xdpyinfo
xterm
xclock
tigervnc-server
ntpdate
#Required for cobbler completion
#For cobbler postscripts
wget
vconfig
bridge-utils
patch
tcl-devel
gettext


%end

%post
yum -y update
yum clean all
if [ ! -f /etc/systemd/system-preset/00-alces-kb.preset ]; then
    mkdir -p /etc/systemd/system-preset
    cat <<EOF > /etc/systemd/system-preset/00-alces-kb.preset
disable libvirtd.service
disable NetworkManager.service
EOF
fi
systemctl disable NetworkManager
systemctl stop NetworkManager

curl https://raw.githubusercontent.com/openflighthpc/openflight-hub/master/hub-setup.sh |sudo /bin/bash > /tmp/hub-setup.out 2>&1
%end
