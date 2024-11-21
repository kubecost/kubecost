#! /bin/bash

# This script is used for manually performing copying of a container image from a source registry
# to AWS ECR. Requires skopeo to be installed.

export IMAGETAG='prod-2.4.2'
# May not need to assume role as a human, only service account
export role_arn='arn:aws:iam::297945954695:role/kubecost-add-on-role-maintainer'
export role_session_name='ecr'
export profile_name='ecr'

temp_role=$(aws sts assume-role --role-arn $role_arn --role-session-name $role_session_name --region us-east-1 --output json)

export AWS_ACCESS_KEY_ID=$(echo $temp_role | jq -r .Credentials.AccessKeyId)
export AWS_SECRET_ACCESS_KEY=$(echo $temp_role | jq -r .Credentials.SecretAccessKey)
export AWS_SESSION_TOKEN=$(echo $temp_role | jq -r .Credentials.SessionToken)

export CLUSTER_CONTROLLER_TAG=$(yq '.clusterController.image.tag' values.yaml)

# Use AWS_PROFILE=EngineeringDeveloper when running as a human
aws ecr get-login-password --region us-east-1 | skopeo login --username AWS --password-stdin 709825985650.dkr.ecr.us-east-1.amazonaws.com
skopeo copy -a docker://gcr.io/kubecost1/cost-model:$IMAGETAG docker://709825985650.dkr.ecr.us-east-1.amazonaws.com/stackwatch/eks/cost-model:${IMAGETAG}
skopeo copy -a docker://gcr.io/kubecost1/frontend:$IMAGETAG docker://709825985650.dkr.ecr.us-east-1.amazonaws.com/stackwatch/eks/frontend:${IMAGETAG}
skopeo copy -a docker://gcr.io/kubecost1/kubecost-modeling:v0.1.16 docker://709825985650.dkr.ecr.us-east-1.amazonaws.com/stackwatch/eks/kubecost-modeling:v0.1.16
skopeo copy -a docker://gcr.io/kubecost1/kubecost-network-costs:v0.17.6 docker://709825985650.dkr.ecr.us-east-1.amazonaws.com/stackwatch/eks/kubecost-network-costs:v0.17.6
skopeo copy -a docker://gcr.io/kubecost1/cluster-controller:$CLUSTER_CONTROLLER_TAG docker://709825985650.dkr.ecr.us-east-1.amazonaws.com/stackwatch/eks/cluster-controller:$CLUSTER_CONTROLLER_TAG
skopeo copy -a docker://cgr.dev/chainguard/prometheus:latest docker://709825985650.dkr.ecr.us-east-1.amazonaws.com/stackwatch/eks/quay.io/prometheus:kc-2.4
skopeo copy -a docker://cgr.dev/chainguard/prometheus-alertmanager:latest docker://709825985650.dkr.ecr.us-east-1.amazonaws.com/stackwatch/eks/quay.io/prometheus/alertmanager:kc-2.4
skopeo copy -a docker://cgr.dev/chainguard/prometheus-config-reloader:latest docker://709825985650.dkr.ecr.us-east-1.amazonaws.com/stackwatch/eks/prometheus-config-reloader:kc-2.4
skopeo copy -a docker://cgr.dev/chainguard/grafana:latest docker://709825985650.dkr.ecr.us-east-1.amazonaws.com/stackwatch/eks/grafana/grafana:kc-2.4
skopeo copy -a docker://cgr.dev/chainguard/k8s-sidecar:latest docker://709825985650.dkr.ecr.us-east-1.amazonaws.com/stackwatch/eks/k8s-sidecar:kc-2.4
skopeo copy -a docker://cgr.dev/chainguard/prometheus-config-reloader:latest docker://709825985650.dkr.ecr.us-east-1.amazonaws.com/stackwatch/eks/quay.io/prometheus-operator/prometheus-config-reloader:kc-2.4
skopeo copy -a docker://gcr.io/kubecost1/awsstore:latest docker://709825985650.dkr.ecr.us-east-1.amazonaws.com/stackwatch/eks/awsstore:latest

