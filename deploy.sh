#!/bin/bash
#
[ -n "${AWS_ACCESS_KEY_ID}" ] || { echo "AWS_ACCESS_KEY_ID environment variable not defined"; exit 1; }
[ -n "${AWS_SECRET_ACCESS_KEY}" ] || { echo "AWS_SECRET_ACCESS_KEY environment variable not defined"; exit 1; }
[ -n "${PDXC_ENV}" ] || { =echo "PDXC_ENV environment variable not defined"; exit 1; }
echo "############# deploy.sh starting ###############"
echo "PDXC_ENV=$PDXC_ENV"

AWS_ACCOUNT=$(aws sts get-caller-identity --output text --query Account)
export AWS_ACCOUNT=${AWS_ACCOUNT}

# Command line parsing, and check if file exist to run.
if [ "$1" == "--server-plan" ] && [ -f ./deploy-server.sh ]; then
    chmod +x ./deploy-server.sh
    ./deploy-server.sh --plan-only 

elif [ "$1" == "--server-apply" ] && [ -f ./deploy-server.sh ]; then
    chmod +x ./deploy-server.sh
    ./deploy-server.sh --auto-apply

# elif [ "$1" == "--serverless" ] && [ -f ./deploy-serverless.sh ]; then
#     chmod +x ./deploy-serverless.sh
# 	./deploy-serverless.sh

fi

