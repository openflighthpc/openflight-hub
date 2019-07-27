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
SOURCE_AMI=ami-061656cdacd730e4a # Clean CentOS 7 build image in Alces Flight account, hosted in eu-west-2 (Apparently STEVETMP)
REGION=eu-west-2
IMAGE_NAME="${IMAGE_NAME:-openflight-hub-$(date +%Y%m%d%H%M%S)}"
KEY_PATH="/root/.ssh/aws_ireland.pem"

# Launch base CentOS Instance
echo "Launching Instance..."
INSTANCE_ID=$(aws ec2 run-instances --image-id $SOURCE_AMI --count 1 --instance-type t2.micro --key-name aws_ireland --region $REGION --output text |grep "INSTANCES" |awk '{print $7}')

# Wait for image to boot
aws ec2 wait --region $REGION instance-running --instance-ids $INSTANCE_ID

IP=$(aws ec2 describe-instances --region $REGION --instance-ids $INSTANCE_ID --output text |grep INSTANCES |awk '{print $15}')
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
AMI_ID=$(aws ec2 create-image --region $REGION --instance-id $INSTANCE_ID --name $IMAGE_NAME --output text)
aws ec2 wait image-available --region $REGION --image-ids $AMI_ID

# Make image public
echo "Publicising image..."
aws ec2 modify-image-attribute --region $REGION --image-id $AMI_ID --launch-permission "Add=[{Group=all}]"

echo "Tidying up..."
aws ec2 terminate-instances --region $REGION --instance-id $INSTANCE_ID 
echo "Done."

cat << EOF

To distribute this image around all regions will require something like:

  IMAGE_NAME=$IMAGE_NAME
  REGION=$REGION
  AMI=$AMI_ID
  AWS_REGIONS=\$(aws ec2 describe-regions |grep RegionName |awk '{print \$2}' |grep -v \$REGION |sed 's/"//g')

  # Copy to all regions
  for region in \$AWS_REGIONS ; do
    echo "Copying \$AMI to \$region"
    aws ec2 copy-image --source-region \$REGION --source-image-id \$AMI --region \$region --name \$IMAGE_NAME --description \$IMAGE_NAME
  done

  # Ensure images are public (once copies have complete)
  for region in \$AWS_REGIONS ; do
    ami=\$(aws ec2 describe-images --filters Name=name,Values=\$IMAGE_NAME --region \$region |grep ImageId |awk '{print \$2}' |sed 's/"//g;s/,//g')
    aws ec2 modify-image-attribute --image-id \$ami --region \$region --launch-permission "Add=[{Group=all}]"
  done

EOF
