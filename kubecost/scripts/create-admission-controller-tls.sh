#!/bin/bash

set -eo pipefail

if [ -z "$1" ]; then
  namespace=kubecost
else
  namespace="$1"
fi

echo -e "\nCreating certificates ..."
mkdir certs
openssl genrsa -out certs/tls.key 2048
openssl req -new -key certs/tls.key -out certs/tls.csr -subj "/CN=webhook-server.${namespace}.svc"
openssl x509 -req -days 500 -extfile <(printf "subjectAltName=DNS:webhook-server.%s.svc" "${namespace}") -in certs/tls.csr -signkey certs/tls.key -out certs/tls.crt

echo -e "\nCreating Webhook Server TLS Secret ..."
kubectl create secret tls webhook-server-tls \
    --cert "certs/tls.crt" \
    --key "certs/tls.key" -n "${namespace}"

ENCODED_CA=$(base64 < certs/tls.crt | tr -d '\n')

if [ -f "../values.yaml" ]; then
  echo -e "\nUpdating values.yaml ..."
  sed -i '' 's@${CA_BUNDLE}@'"${ENCODED_CA}"'@g' ../values.yaml
else
  echo -e "\nThe CA bundle to use in your values file is: \n${ENCODED_CA}"
fi