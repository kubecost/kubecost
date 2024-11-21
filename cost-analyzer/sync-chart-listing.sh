#! /bin/bash
role_arn='arn:aws:iam::297945954695:role/kubecost-add-on-role-maintainer'
role_session_name='ecr'
profile_name='ecr'
temp_role=$(aws sts assume-role \
        --role-arn $role_arn \
        --role-session-name $role_session_name --region us-east-1 --output json)
export AWS_ACCESS_KEY_ID=$(echo $temp_role | jq -r .Credentials.AccessKeyId)
export AWS_SECRET_ACCESS_KEY=$(echo $temp_role | jq -r .Credentials.SecretAccessKey)
export AWS_SESSION_TOKEN=$(echo $temp_role | jq -r .Credentials.SessionToken)
export PRODUCT_ID="753cea16-f450-4cfa-93eb-f55dcde11e91"
export DOCUMENT_JSON=$(cat sync-chart-listing.json)
DOCUMENT_JSON_STRING="$(echo "${DOCUMENT_JSON}" | jq 'tostring')"
CHANGE_SET_JSON="[
    {
        \"ChangeType\": \"AddDeliveryOptions\",
        \"Entity\": {
            \"Identifier\": \"${PRODUCT_ID}\",
            \"Type\": \"ContainerProduct@1.0\"
        },
        \"Details\": ${DOCUMENT_JSON_STRING}
    }
]"
# echo ${CHANGE_SET_JSON}
# exit 0
aws marketplace-catalog start-change-set \
--region us-east-1 \
--catalog "AWSMarketplace" \
--change-set="${CHANGE_SET_JSON}"

# see https://aws.amazon.com/marketplace/management/requests

### output
# {
#     "ChangeSetId": "6k828fgbvou3syx3020i40t5u",
#     "ChangeSetArn": "arn:aws:aws-marketplace:us-east-1:297945954695:AWSMarketplace/ChangeSet/6k828fgbvou3syx3020i40t5u"
# }
# {
#     "ChangeSetId": "876hgo0wi2z7bspsvotbxp18e",
#     "ChangeSetArn": "arn:aws:aws-marketplace:us-east-1:297945954695:AWSMarketplace/ChangeSet/876hgo0wi2z7bspsvotbxp18e"
# }
# aws marketplace-catalog describe-change-set \
# --catalog "AWSMarketplace" \
# --change-set-id "876hgo0wi2z7bspsvotbxp18e \
# --region us-east-1 | jq -r ".Status"
echo "Change set submitted. see https://aws.amazon.com/marketplace/management/requests"