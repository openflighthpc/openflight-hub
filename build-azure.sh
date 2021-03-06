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

# Variables
SOURCE_IMAGE=/subscriptions/d1e964ef-15c7-4b27-8113-e725167cee83/resourceGroups/openflight-cloud/providers/Microsoft.Compute/images/openflight-cloud-base-1.0-azure # OpenFlight CentOS Clean image (uksouth)
REGION=uksouth
IMAGE_NAME="${IMAGE_NAME:-openflight-hub-$(date +%Y%m%d%H%M%S)}"
KEY_PATH="/root/.ssh/aws_ireland.pem"
PUBLIC_KEY="ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCK8fxlYAcZHfZ9Rhcl0IIcFAleztyMkBF6CxfcaqI6XO9WYhy/sawZXnOHlACjLfx1RuDu+kDvPT/lhxay7yrQt0g1HsTs3xwW6luZuLxPvCS7Zqi0AGqr/LC6OWUKodpNe8ZUPxCWx+JiyaRb9SD+PWqV0WPiZXTmgd9lRYfWuvMl24sNvK8VWWzWSr8q2+1yGNbyzoFC/NUfoMuFEPyb+XV3BIKNyacAM8gep+mrFxadV1ehZConzeoJSFavlJUiU76JMKkbJcfUeXFqTBk/W1mXpmYPw+JUZzsDM2RZD/Ef4LrhyxjtLVLelrIU5j4DN/7lMCsMf3tdfXbJ2+fp aws_ireland"

# Launch base CentOS Instance
echo "Launching Instance..."

az group create --name $IMAGE_NAME --location $REGION >> /dev/null
INSTANCE_OUT=$(az vm create --location $REGION --resource-group $IMAGE_NAME --name $IMAGE_NAME --image $SOURCE_IMAGE --admin-username centos --ssh-key-value "$PUBLIC_KEY" -o yaml --tags delete_after=True)
INSTANCE_ID=$(echo "$INSTANCE_OUT" |grep 'id:' |sed 's/.*id: //g')
IP=$(echo "$INSTANCE_OUT" |grep 'publicIpAddress:' |sed 's/.*publicIpAddress: //g')

# Allow HTTP curl from VM
az vm open-port -g $IMAGE_NAME -n $IMAGE_NAME --port 80 --priority 100 >> /dev/null

while ! ssh -i $KEY_PATH -o "StrictHostKeyChecking no" centos@$IP echo -n 2> /dev/null ; do
    echo "Waiting for SSH..."
    sleep 15
done

# Run script
echo "Running Hub Setup..."
ssh -i $KEY_PATH -o "StrictHostKeyChecking no" centos@$IP "curl https://raw.githubusercontent.com/openflighthpc/openflight-hub/master/hub-setup.sh |sudo /bin/bash" > /tmp/$IMAGE_NAME 2>&1
echo "Setup Complete (output at /tmp/$IMAGE_NAME)"

# Create image
echo "Creating image..."
az vm stop --resource-group $IMAGE_NAME --name $IMAGE_NAME >> /dev/null
az vm generalize --resource-group $IMAGE_NAME --name $IMAGE_NAME >> /dev/null
az image create --resource-group $IMAGE_NAME \
        --name $IMAGE_NAME \
        --location $REGION \
        --os-type Linux \
        --source $INSTANCE_ID >> /dev/null

echo "Tidying up..."
az resource delete --ids $(az resource list --tag delete_after=True -otable --query "[].id" -otsv) >> /dev/null
echo "Done."

cat << EOF 

To distribute this image around all regions will require something like:

  IMAGE_NAME=$IMAGE_NAME
  REGION=$REGION
  AZURE_REGIONS=\$(az provider show --namespace Microsoft.Storage --query "resourceTypes[?resourceType=='storageAccounts'].locations | [0]" -o tsv |sed 's/ //g' | tr '[:upper:]' '[:lower:]' |grep -v \$REGION |sort)

  # Add extension to allow for image copying
  az extension add --name image-copy-extension

  # Copy to all regions
  az image copy --source-resource-group \$IMAGE_NAME --source-object-name \$IMAGE_NAME --target-location \$(for region in \$AZURE_REGIONS ; do echo -n "\$region " ; done) --target-resource-group \$IMAGE_NAME --cleanup

EOF
