#!/bin/bash

set -e

csr=$(cat)
nodename="${1}"
timestamp='date +%m%d%Y-%H:%M:%S'
# Check for our vars file and source the envvars into the pe-puppet user's context
[ -r /opt/autosigner_vars ] && . /opt/autosigner_vars
if [ -z $AUTOSIGN_LOG ]; then
    log='/tmp/autosinger.log'
else
    log="${AUTOSIGN_LOG}"
fi
if [ -r "${log}" ]; then
    echo "$($timestamp) Autosigning started for ${nodename}" >> $log
else
    echo "$($timestamp) Autosigning started for ${nodename}" > $log
fi
[[ -z $VAULT_URL ]] && echo "$($timestamp) Envar VAULT_URL not set! Exiting!" >> $log; exit 1
vaulturl="${VAULT_URL}"
[[ -z $AUTOSIGN_UN ]] && echo "$($timestamp) Envar AUTOSIGN_UN not set! Exiting!" >> $log; exit 1
autosignun="${AUTOSIGN_UN}"
[[ -z $AUTOSIGN_PW ]] && echo "$($timestamp) Envar AUTOSIGN_PW not set! Exiting!" >> $log; exit 1
autosignpw="${AUTOSIGN_PW}"
encpsk=$(echo "${csr}" | openssl req -noout -text | fgrep -A0 challengePassword | sed -e 's/^.*\(vault:v1:\)//')
echo "$($timestamp) Encryted challengePassword: ${encpsk}" >> $log
# Log into Vault with the autosigner service account
token=$(curl --request POST --data "{\"password\": \"${autosignpw}\"}" "${vaulturl}/auth/userpass/login/${autosignun}" | jq -r '.auth.client_token')
# If Vault access token could no be retrieved, log error and exit
[[ -z $token ]] && echo "$($timestamp) Failed to authenticate to Vault with user ${autosignun}!" >> $log; exit 1 || echo "$($timestamp) Authenticated to Vault..." >> $log
header="X-Vault-token: ${token}"
# Decrypt the challengePassword
decpsk=$(curl --header "${header}" --request POST --data "{\"ciphertext\": \"${encpsk}\"}" "${vaulturl}/transit/decrypt/puppet_autosigner" | jq -r '.data.plaintext' | base64 --decode)
[[ -z $decpsk ]] && echo "$($timestamp) Failed to decrypt challengePassword!" >> $log; exit 1 || echo "$($timestamp) Decrypted challengePassword..." >> $log
if [ "${decpsk}" == "${nodename}" ]; then
    echo "$($timestamp) Autosigning has verified the CSR. The CSR will be signed." >> $log
    exit 0
else
    echo "$($timestamp) CSR is invalid! The CSR WILL NOT be signed!" >> $log
    exit 1
fi
