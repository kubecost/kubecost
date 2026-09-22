#!/bin/bash

set -e

# AWS Specific Requirements
CLUSTER_NAME="${1}"
S3_BUCKET_NAME="${2}"
TRAFFIC_TYPE="ALL"
MAX_AGGREGATION_INTERVAL="600"

# Network Costs Monitoring tag to avoid duplicate flow logs
MONITORED_BY_TAG_KEY="MonitoredBy"
MONITORED_BY_TAG_VALUE="kubecost-network-costs"

# Required Log Formatting Output for the NAT Gateway Network Interface (ENI)
CUSTOM_LOG_FORMAT='${pkt-srcaddr} ${srcaddr} ${srcport} ${pkt-dstaddr} ${dstaddr} ${dstport} ${flow-direction} ${packets} ${bytes}'

# Validate inputs
if [ -z "$CLUSTER_NAME" ] || [ -z "$S3_BUCKET_NAME" ]; then
    echo "Usage: $0 <cluster-name> <s3-bucket-name>"
    echo ""
    echo "Arguments:"
    echo "  cluster-name      : Name of the EKS cluster (required)"
    echo "  s3-bucket-name    : S3 bucket name for flow logs (required)"
    echo "                      Example: kubecost-data-bucket"
    echo "                      Logs will be written to: s3://kubecost-data-bucket/flow-logs/<cluster-name>/"
    exit 1
fi

# Construct S3 ARN with cluster-specific path - this is *required* for network-costs to be able
# to locate the specific flow logs.
S3_PREFIX="flow-logs"
S3_LOG_EXPIRATION_DAYS="2"
S3_LIFECYCLE_ID="KubecostNATGatewayLogExpiration"
S3_DESTINATION="arn:aws:s3:::${S3_BUCKET_NAME}/${S3_PREFIX}/${CLUSTER_NAME}"

# Check to see if there exists an S3 expiration policy for our bucket with the
# flow-logs prefix. If there isn't one, we should create it. This will keep the
# age of the flow-logs within 2 days and prevents logs from being stored indefinitely
echo "=== S3 Flow Logs Policy Setup ==="
echo "S3 Bucket: ${S3_BUCKET_NAME}"
echo "Prefix: ${S3_PREFIX}/"
echo ""

CREATE_S3_POLICY=false
S3_LIFECYCLE=$(aws s3api get-bucket-lifecycle-configuration --bucket "${S3_BUCKET_NAME}" 2>&1) || true

# If there are no policies, we can just create the first one for flow-logs lifecycle.
if echo "$S3_LIFECYCLE" | grep -q "NoSuchLifecycleConfiguration"; then
  echo "No existing policies for bucket: ${S3_BUCKET_NAME}."
  CREATE_S3_POLICY=true
else
  # Otherwise, this request returns the policies as json -- we need to parse through them
  # and find if there exists a policy for the flow-logs prefix
  IS_PREFIX_MATCH=$(echo "$S3_LIFECYCLE" | jq -r --arg prefix "${S3_PREFIX}/" \
    '.Rules[] | select(.Filter.Prefix == $prefix) | .ID' 2>/dev/null)

  if [ -z "$IS_PREFIX_MATCH" ]; then
    echo "No existing policy for Prefix: ${S3_PREFIX}/"
    CREATE_S3_POLICY=true
  else
    echo "Existing Lifecycle Configuration was found for: ${S3_PREFIX}..."
  fi
fi

# Lastly, check our creation flag. If there were any issues checking for the policy,
# we default to _not_ creating the policy.
if $CREATE_S3_POLICY; then
  echo "Creating S3 Lifecycle Configuration Policy for Prefix: ${S3_PREFIX}/ for ${S3_LOG_EXPIRATION_DAYS} days..."
  # Get existing rules
  EXISTING_RULES=$(aws s3api get-bucket-lifecycle-configuration \
    --bucket "${S3_BUCKET_NAME}" \
    --query 'Rules' 2>/dev/null || echo '[]')

  # Append new rule
  S3_LIFECYCLE_CONFIG=$(jq -n \
    --argjson existing "$EXISTING_RULES" \
    --arg id "${S3_LIFECYCLE_ID}" \
    --arg prefix "${S3_PREFIX}" \
    --argjson days "${S3_LOG_EXPIRATION_DAYS}" \
    '{Rules: ($existing + [{
      "ID": $id,
      "Filter": {"Prefix": $prefix},
      "Status": "Enabled",
      "Expiration": {"Days": $days},
      "NoncurrentVersionExpiration": {"NoncurrentDays": $days},
      "AbortIncompleteMultipartUpload": {"DaysAfterInitiation": $days}
    }])}')

  echo "${S3_LIFECYCLE_CONFIG}"

  aws s3api put-bucket-lifecycle-configuration \
    --bucket "${S3_BUCKET_NAME}" \
    --lifecycle-configuration "${S3_LIFECYCLE_CONFIG}" 2>&1 > /dev/null
else
  echo "S3 Lifecycle Configuration was skipped"
fi

echo ""

echo "=== EKS NAT Gateway Flow Logs Setup ==="
echo "Cluster: $CLUSTER_NAME"
echo "S3 Destination: $S3_DESTINATION"
echo "Log Format: $CUSTOM_LOG_FORMAT"
echo "Traffic Type: $TRAFFIC_TYPE"
echo "Aggregation Interval: $MAX_AGGREGATION_INTERVAL seconds"
echo ""

# Find the VPC ID associated with the EKS cluster
echo "Finding VPC for EKS cluster '$CLUSTER_NAME'..."
VPC_ID=$(aws eks describe-cluster \
    --name "$CLUSTER_NAME" \
    --query 'cluster.resourcesVpcConfig.vpcId' \
    --output text)

if [ -z "$VPC_ID" ] || [ "$VPC_ID" == "None" ]; then
    echo "Error: Could not find VPC for cluster '$CLUSTER_NAME'"
    exit 1
fi

echo "Found VPC: $VPC_ID"
echo ""

# Find all NAT Gateways in the VPC
echo "Finding NAT Gateways in VPC '$VPC_ID'..."
NAT_GATEWAY_IDS=$(aws ec2 describe-nat-gateways \
    --filter "Name=vpc-id,Values=$VPC_ID" "Name=state,Values=available" \
    --query 'NatGateways[*].NatGatewayId' \
    --output text)

if [ -z "$NAT_GATEWAY_IDS" ]; then
    echo "No NAT Gateways found in VPC '$VPC_ID'"
    exit 0
fi

echo "Found NAT Gateways: $NAT_GATEWAY_IDS"
echo ""

# Find network interfaces and enable flow logs for each NAT Gateway
echo "Creating Flow Logs for NAT Gateways on Cluster: $CLUSTER_NAME, VPC: $VPC_ID..."
for NAT_ID in $NAT_GATEWAY_IDS; do
    echo "  Finding Network Interface for NAT Gateway: $NAT_ID..."

    # Get network interface ID for this NAT Gateway
    ENI_ID=$(aws ec2 describe-nat-gateways \
        --nat-gateway-ids "$NAT_ID" \
        --query 'NatGateways[0].NatGatewayAddresses[0].NetworkInterfaceId' \
        --output text)

    if [ -z "$ENI_ID" ] || [ "$ENI_ID" == "None" ]; then
        echo "  Warning: No network interface found for $NAT_ID"
        continue
    fi

    echo "    Network Interface: $ENI_ID"

    # Check if flow logs already exist for this ENI
    EXISTING_FLOW_LOGS=$(aws ec2 describe-flow-logs \
        --filter "Name=resource-id,Values=$ENI_ID" "Name=log-destination-type,Values=s3" "Name=tag:$MONITORED_BY_TAG_KEY,Values=$MONITORED_BY_TAG_VALUE" \
        --query 'FlowLogs[*].FlowLogId' \
        --output text)

    if [ -n "$EXISTING_FLOW_LOGS" ]; then
        echo "    Kubecost Network-Costs Flow logs already exist: $EXISTING_FLOW_LOGS"
    else
        echo "    Creating Flow Log on NAT Gateway: $NAT_ID Network Interface: $ENI_ID..."

        # Capture the flow log id for logging and verification
        FLOW_LOG_ID=$(aws ec2 create-flow-logs \
            --resource-type NetworkInterface \
            --resource-ids "$ENI_ID" \
            --traffic-type "$TRAFFIC_TYPE" \
            --log-destination-type s3 \
            --log-destination "$S3_DESTINATION" \
            --log-format "$CUSTOM_LOG_FORMAT" \
            --max-aggregation-interval "$MAX_AGGREGATION_INTERVAL" \
            --destination-options "FileFormat=plain-text,HiveCompatiblePartitions=false,PerHourPartition=true" \
            --tag-specifications "ResourceType=vpc-flow-log,Tags=[{Key=$MONITORED_BY_TAG_KEY,Value=$MONITORED_BY_TAG_VALUE}]" \
            --query 'FlowLogIds[0]' \
            --output text)

        if [ -n "$FLOW_LOG_ID" ] && [ "$FLOW_LOG_ID" != "None" ]; then
            echo "  ✓ Flow log created: $FLOW_LOG_ID"
        else
            echo "  ✗ Failed to create flow log"
        fi
    fi
    echo ""
done

echo "=== Setup Complete ==="
