#!/bin/bash

set -e

# ARG1 - Hostname: The machines hostname
# ARG2 - Vault URL: https://<vaultserver>:<port>/v1
# ARG3 - Vault service account for provisioning system
# ARG4 - Provisioner service account password
echo "Hostname: ${1}"
echo "Vault URL: ${2}"
echo "Provisioner account: ${3}"
# Transit secret store requires base64 encoded data
# The encoded hostname will be encrypted with transit encryption
# and stored in the CSR attribute challengePassword as our PSK
enchostname=$(base64 <<< "${1}")
echo "Encoded hostname: ${enchostname}"
# Login to Vault and get an access token
token=$(curl --request POST --data "{\"password\": \"${4}\"}" "${2}/auth/userpass/login/${3}" | jq -r '.auth.client_token')
# Create the common header for each request
# This is really just a time saver from having to type it out
header="X-Vault-Token: ${token}"
# Use transit encryption to encrypt our hostname
# The ciphertext hostname is what goes into the csr_attributes file
transitdata="{\"plaintext\": \"${enchostname}\"}"
cipher=$(curl --header "${header}" --request POST --data "${transitdata}" "${2}/transit/encrypt/puppet_autosigner" | jq -r '.data.ciphertext')
echo "Cipher: ${cipher}"
# Create custom trusted fact yaml
# Uses UID for challengePassword extension
cat > csr_attributes.yaml <<EOF
custom_attributes:
    1.2.840.113549.1.9.7: "$cipher"
EOF
echo "csr_attributes.yaml created successfully..."