#!/bin/bash
#==============================================================================
# Copyright (C) 2019-present Alces Flight Ltd.
#
# This file is part of OpenFlight Hub.
#
# This program and the accompanying materials are made available under
# the terms of the Eclipse Public License 2.0 which is available at
# <https://www.eclipse.org/legal/epl-2.0>, or alternative license
# terms made available by Alces Flight Ltd - please direct inquiries
# about licensing to licensing@alces-flight.com.
#
# OpenFlight Hub is distributed in the hope that it will be useful, but
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, EITHER EXPRESS OR
# IMPLIED INCLUDING, WITHOUT LIMITATION, ANY WARRANTIES OR CONDITIONS
# OF TITLE, NON-INFRINGEMENT, MERCHANTABILITY OR FITNESS FOR A
# PARTICULAR PURPOSE. See the Eclipse Public License 2.0 for more
# details.
#
# You should have received a copy of the Eclipse Public License 2.0
# along with OpenFlight Hub. If not, see:
#
#  https://opensource.org/licenses/EPL-2.0
#
# For more information on OpenFlight Hub, please visit:
# https://github.com/openflighthpc/openflight-hub
#==============================================================================

NAME="openflight-hub-$(date +%Y%m%d%H%M%S)"

virt-install \
--name $NAME \
--ram 4096 \
--disk path=/opt/vm/$NAME.qcow2,size=8 \
--vcpus 2 \
--os-type linux \
--os-variant centos7.0 \
--network bridge=pri \
--network bridge=ext \
--graphics vnc,password='password',listen=0.0.0.0,port='-1' --noautoconsole \
--console pty,target_type=serial \
--location 'http://alces-repo.s3.amazonaws.com/centos/7/base' \
--initrd-inject ./libvirt.ks \
--extra-args 'console=tty0 console=ttyS0,115200n8 ip=eth1:dhcp bootdev=eth1 ks=file:/libvirt.ks'

virsh console $NAME
