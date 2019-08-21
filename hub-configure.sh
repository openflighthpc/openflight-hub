#!/bin/bash

#
# Functions and fun stuff
#

function stuff_that_should_be_quiet() {
    if [[ ! -f /root/.ssh/id_rsa.pub ]] ; then
        # Generate SSH key
        ssh-keygen -f /root/.ssh/id_rsa -N ''
    fi
}

stuff_that_should_be_quiet > /dev/null

function ctrl_c() {
    echo "Exiting program..."
    sleep 1
    echo "Re-execute this script to continue with cluster setup:"
    echo "    bash hub-configure.sh"
    exit 1
}

trap 'ctrl_c' SIGINT

function ask_question() {
    #
    # ask_question "Question to ask" VARIABLE_NAME
    #
    QUESTION=$1
    OUTPUT=$2

    read -p "$QUESTION: " VAR
    while [[ -z "$VAR" ]] ; do
        echo "ERROR: Answer cannot be blank"
        read -p "$QUESTION: " VAR
    done

    # Alphanumeric only
    while [[ "$VAR" =~ [^a-zA-Z0-9] ]] ; do
        echo "ERROR: Answer can only contain letters and numbers"
        read -p "$QUESTION: " VAR
    done

    declare -g $OUTPUT=$VAR
}

function ask_question_yn() {
    #
    # ask_question_yn "Yes or no question" VARIABLE
    #
    QUESTION=$1
    OUTPUT=$2

    read -p "$QUESTION? [y/n] " -n 1 VAR
    while [[ ! $VAR =~ ^[YyNn]$ ]] ; do
        echo "ERROR: Please answer y or n"
        read -p "$QUESTION? [y/n] " -n 1 VAR
    done
    echo

    declare -g $OUTPUT=$VAR
}


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

# Update domain config
## AWS IP
IP="$(curl -f http://169.254.169.254/latest/meta-data/public-ipv4 2> /dev/null)"
if [ $? != 0 ] ; then
    ## Azure IP
    IP="$(curl -f -H Metadata:true 'http://169.254.169.254/metadata/instance/network/interface/0/ipv4/ipAddress/0/publicIpAddress?api-version=2019-06-01&format=text')"
fi
sed -i "s,renderedurl:.*,renderedurl: http://$IP/architect/<%=node.config.cluster%>/var/rendered/<%=node.platform%>/node/<%=node.name%>,g" /opt/flight/opt/architect/data/base/etc/configs/domain.yaml


#
# CLOUD
#

# Get access details
cat << EOF

Deploying cloud resources requires either AWS or Azure access credentials. 

For information on locating your cloud credentials, see:

    https://github.com/openflighthpc/flight-cloud#configuring-cloud-authentication

EOF

flight cloud configure

echo
echo

##########################
#                        #
# END OF PROBLEM SECTION #
#                        #
##########################

#
# ARCHITECT
#

# Get user input
ask_question "Name for the default cluster" CLUSTER

echo "Finishing cluster configuration..."

# Initialise cluster
set +m # Silence background job creation message
{ flight architect cluster init $CLUSTER > /dev/null & } 2>/dev/null
PID=$!
sleep 5 
kill -9 $PID 2> /dev/null
set -m # Enable background job creation message

# Configure domain
flight architect configure domain -a "{ \"cluster_name\": \"$CLUSTER\", \"root_password\": \"$(openssl rand -base64 16)\", \"root_ssh_key\": \"$(cat /root/.ssh/id_rsa.pub)\", \"network2_defined\": false, \"network3_defined\": false }"

echo "Generating Templates"
flight architect template

EXPORT=$(flight architect export |sed 's/.*: //g')
cp /var/lib/architect/clusters/$CLUSTER/var/rendered/kickstart/domain/platform/manifest.yaml /var/lib/architect/clusters/$CLUSTER/var/rendered/

#
# CLOUD
#
flight cloud cluster init $CLUSTER-azure azure > /dev/null
flight cloud import /var/lib/architect/clusters/$CLUSTER/var/rendered/manifest.yaml > /dev/null
flight cloud cluster init $CLUSTER-aws aws > /dev/null
flight cloud import /var/lib/architect/clusters/$CLUSTER/var/rendered/manifest.yaml > /dev/null

#
# METAL
#
flight metal import /var/lib/architect/clusters/$CLUSTER/var/rendered/manifest.yaml >> /dev/null


cat << EOF

OpenFlight Hub Configuration Complete!

To deploy your cluster:

1. Select AWS or Azure cluster (replace PLATFORM with 'aws' or 'azure')

    flight cloud cluster switch $CLUSTER-PLATFORM

2. Deploy the domain

    flight cloud deploy domain

3. Deploy the gateway

    flight cloud deploy gateway1 -p "securitygroup,network1SubnetID=*domain"

4. Copy the SSH key to the gateway

    scp /root/.ssh/id_rsa root@GATEWAY-IP:/root/.ssh/

5. Deploy the nodes (example given: node01)

    flight cloud deploy node01 -p "securitygroup,network1SubnetID=*$CLUSTER-domain"

EOF

rm -f /opt/flight/.firstrun

