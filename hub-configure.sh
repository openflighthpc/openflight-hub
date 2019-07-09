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
IP="$(curl -f http://169.254.169.254/latest/meta-data/public-ipv4 2> /dev/null)"
if [ $? != 0 ] ; then
    IP="$(curl -f -H Metadata:true 'http://169.254.169.254/metadata/instance/network/interface/0/ipv4/ipAddress/0/publicIpAddress?api-version=2019-06-01&format=text')"
fi
sed -i "s,renderedurl:.*,renderedurl: http://$IP/architect/<%=node.config.cluster%>/var/rendered/<%=node.platform%>/node/<%=node.name%>,g" /opt/flight/opt/architect/data/base/etc/configs/domain.yaml


#
# CLOUD
#

# Get access details
cat << EOF

Deploying cloud resources requires AWS access credentials. 

EOF
flight cloud aws configure

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

#
# CLOUD
#
flight cloud aws import $EXPORT > /dev/null
flight cloud azure import $EXPORT > /dev/null

#
# METAL
#
cp /var/lib/underware/clusters/$CLUSTER/var/rendered/kickstart/domain/platform/manifest.yaml /var/lib/underware/clusters/$CLUSTER/var/rendered/
flight metal import /var/lib/underware/clusters/$CLUSTER/var/rendered/manifest.yaml >> /dev/null

cat << EOF

OpenFlight Hub Configuration Complete!

To deploy your cluster:

1. Deploy the domain

    flight cloud aws deploy $CLUSTER-domain domain

2. Deploy the gateway

    flight cloud aws deploy gateway1 node/gateway1 -p "securitygroup,network1SubnetID=*$CLUSTER-domain"

3. Copy the SSH key to the gateway

    scp /root/.ssh/id_rsa root@GATEWAY-IP:/root/.ssh/

4. Deploy the nodes (example given: node01)

    flight cloud aws deploy node01 node/node01 -p "securitygroup,network1SubnetID=*$CLUSTER-domain"

EOF

rm -f /home/centos/.firstrun

