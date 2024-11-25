#! /bin/bash

# run this manually: 
# helm package ./cost-analyzer

# This script is used for manually performing copying of a Helm chart as an OCI artifact from a source registry
# to AWS ECR. Currently, Helm versions 3.13.0-2 have known bugs and cannot be used to execute this command.

export HELMTAG='2.4.3'
export role_arn='arn:aws:iam::297945954695:role/kubecost-add-on-role-maintainer'
export role_session_name='ecr'
export profile_name='ecr'

temp_role=$(aws sts assume-role --role-arn $role_arn --role-session-name $role_session_name --region us-east-1 --output json)

export AWS_ACCESS_KEY_ID=$(echo $temp_role | jq -r .Credentials.AccessKeyId)
export AWS_SECRET_ACCESS_KEY=$(echo $temp_role | jq -r .Credentials.SecretAccessKey)
export AWS_SESSION_TOKEN=$(echo $temp_role | jq -r .Credentials.SessionToken)

aws ecr get-login-password --region us-east-1 | helm registry login --username AWS --password-stdin 709825985650.dkr.ecr.us-east-1.amazonaws.com
### Download Helm chart. Only download if no local modifications were necessary.
# wget https://raw.githubusercontent.com/kubecost/cost-analyzer/gh-pages/cost-analyzer-$HELMTAG.tgz
helm push cost-analyzer-$HELMTAG.tgz oci://709825985650.dkr.ecr.us-east-1.amazonaws.com/stackwatch/eks/helm

