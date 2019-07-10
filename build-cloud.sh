#!/bin/bash
#
# This script builds both the Azure and AWS hub images with the 
# same image name for consistencies sake.
#

export IMAGE_NAME="openflight-hub-$(date +%Y%m%d%H%M%S)"

cat << EOF
================================================
BUILDING AWS
================================================
EOF
bash build-aws.sh

cat << EOF
================================================
BUILDING AZURE
================================================
EOF
bash build-azure.sh
