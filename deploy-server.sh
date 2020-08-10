#!/bin/bash
#
[ -n "${AWS_ACCESS_KEY_ID}" ] || { echo "AWS_ACCESS_KEY_ID environment variable not defined"; exit 1; }
[ -n "${AWS_SECRET_ACCESS_KEY}" ] || { echo "AWS_SECRET_ACCESS_KEY environment variable not defined"; exit 1; }
[ -n "${PDXC_ENV}" ] || { echo "PDXC_ENV environment variable not defined"; exit 1; }
echo "############# deploy.sh starting ###############"

# Command line parsing
if [ "$1" == "--plan-only" ]; then
    terraformAction="plan"
elif [ "$1" == "--auto-apply" ]; then
    terraformAction="apply"
elif [ "$#" -eq 0 ]; then
    terraformAction="apply"
fi

echo "AWS_DEFAULT_REGION=${AWS_DEFAULT_REGION}"



# Setup bucket name

pip show docutils

aws_account=$(aws sts get-caller-identity --output text --query Account)

export TF_VAR_region="${AWS_DEFAULT_REGION}"
export TF_VAR_PDXC_ENV="$PDXC_ENV"
export PDXC_ENV_LOWERCASE=$(echo "$PDXC_ENV" |  tr '[:upper:]' '[:lower:]' | sed "s/_/-/g")

export app_three_letter_prefix="ctk"

export TF_VAR_tf_state_bucket="${app_three_letter_prefix}-tfstate-${aws_account}${AWS_DEFAULT_REGION}"


echo "====>TF_VAR_tf_state_bucket=$TF_VAR_tf_state_bucket"



if aws s3 ls $TF_VAR_tf_state_bucket 2>&1 | grep -q 'NoSuchBucket';
then
    if [ $AWS_DEFAULT_REGION = 'us-east-1' ]
    then
        echo "Creating state Terraform backend bucket at ${AWS_DEFAULT_REGION}"
        aws s3api create-bucket --bucket $TF_VAR_tf_state_bucket --region $TF_VAR_region
    else
        echo "Creating state Terraform backend bucket at ${AWS_DEFAULT_REGION}"
        aws s3api create-bucket --bucket $TF_VAR_tf_state_bucket --region $TF_VAR_region --create-bucket-configuration LocationConstraint="${TF_VAR_region}"


    fi
else
    echo "Terraform backend bucket already exists."

fi



cd server
rm -rf .terraform

echo "==============TF Start ================="

terraform --version
terraform init -backend-config "bucket=$TF_VAR_tf_state_bucket" -backend-config "region=$TF_VAR_region" -backend-config "key=$app_three_letter_prefix" -backend-config "encrypt=true"

# Deploy
if [[ "${terraformAction}" == "plan" ]]; then
    echo "Plan Section=$AWS_DEFAULT_REGION & $app_three_letter_prefix"
    terraform plan -var aws_region=$AWS_DEFAULT_REGION -var app_three_letter_prefix=$app_three_letter_prefix
elif [[ "${terraformAction}" == "apply" ]]; then

    # Regular
    echo "Apply=$AWS_DEFAULT_REGION & $app_three_letter_prefix"
    terraform plan -out tfplan -input=false -var aws_region=$AWS_DEFAULT_REGION -var app_three_letter_prefix=$app_three_letter_prefix
    terraform apply -input=false tfplan    
else
    echo "Invalid terraform action: ${terraformAction}"
    # Always return an exit code when it is not handle by the command you use.
   exit 2
fi
if [ $? -eq 1 ]; then
    echo "====>Terraform failed applying plan "
    exit 2
fi

