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
IP="$(curl http://169.254.169.254/latest/meta-data/public-ipv4 2> /dev/null)"
sed -i "s,renderedurl:.*,renderedurl: http://$IP/architect/<%=node.config.cluster%>/var/rendered/<%=node.platform%>/node/<%=node.name%>,g" /opt/flight/opt/architect/data/base/etc/configs/domain.yaml


#
# CLOUD
#

# Get access details
cat << EOF

Deploying cloud resources requires at least one of either AWS or Azure credentials. 

For information on locating your cloud credentials, see:

    https://github.com/openflighthpc/flight-cloud#configuring-cloud-authentication
EOF


while [[ $AWS != 'y' && $AZURE != 'y' ]] ; do
    echo
    echo "At least one cloud provider must be configured"
    echo 
    # AWS
    ask_question_yn "Configure AWS Access Credentials" AWS

    if [[ $AWS =~ ^[Yy]$ ]] ; then
        ask_question "AWS Default Region" AWS_REGION
        ask_question "AWS Access Key ID" AWS_ACCESS_KEY_ID
        ask_question "AWS Secret Access Key" AWS_SECRET_ACCESS_KEY
    fi

    # Azure
    #ask_question_yn "Configure Azure Access Credentials" AZURE

    #if [[ $AZURE =~ ^[Yy]$ ]] ; then
    #    ask_question "Azure Default Region" AZURE_REGION
    #    ask_question "Azure Tenant ID" AZURE_TENANT_ID
    #    ask_question "Subscription ID" AZURE_SUBSCRIPTION_ID
    #    ask_question "Client Secret" AZURE_CLIENT_SECRET
    #    ask_question "Client ID" AZURE_CLIENT_ID
    #fi
done

echo
echo

# Configure config.yaml
cat << EOF > /opt/flight/opt/cloud/etc/config.yaml
prefix_tag:

# Provider credentials
#azure:
#  default_region: $AZURE_REGION
#  tenant_id: $AZURE_TENANT_ID
#  subscription_id: $AZURE_SUBSCRIPTION_ID
#  client_secret: $AZURE_CLIENT_SECRET
#  client_id: $AZURE_CLIENT_ID

aws:
  default_region: $AWS_REGION
  access_key_id: $AWS_ACCESS_KEY_ID
  secret_access_key: $AWS_SECRET_ACCESS_KEY
EOF

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

# 
# COMPLETION MESSAGES
#

if [[ $AWS == 'y' && $AZURE == 'y' ]] ; then
    PROMPT="[aws/azure]"
elif [[ $AWS == 'y' ]] ; then
    PROMPT="aws"
elif [[ $AZURE == 'y' ]] ; then
    PROMPT="azure"
fi

cat << EOF

OpenFlight Hub Configuration Complete!

To deploy your cluster:

1. Deploy the domain

    flight cloud $PROMPT deploy $CLUSTER-domain domain

2. Deploy the gateway

    flight cloud $PROMPT deploy gateway1 node/gateway1 -p "securitygroup,network1SubnetID=*$CLUSTER-domain"

3. Copy the SSH key to the gateway

    scp /root/.ssh/id_rsa root@GATEWAY-IP:/root/.ssh/

4. Deploy the nodes (example given: node01)

    flight cloud $PROMPT deploy node01 node/node01 -p "securitygroup,network1SubnetID=*$CLUSTER-domain"

EOF

rm -f /home/centos/.firstrun

