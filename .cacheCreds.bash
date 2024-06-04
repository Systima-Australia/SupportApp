#!/bin/bash

autotaskURL="https://webservices6.autotask.net/atservicesrest/v1.0"

# Get the API credentials from the secure keychain
source "/var/root/$(sudo ls /var/root | grep $(sudo defaults read "/Library/Application Support/Systima/.provisioning.plist" Shunt))"
security unlock-keychain -p "$keypass" "$keychain" > /dev/null 2>&1
ATAPIIntCode=$(security find-generic-password -a "" -s "ATAPIIntCode" -w "$keychain")
ATAPIUsername=$(security find-generic-password -a "" -s "ATAPIUsername" -w "$keychain")
ATAPISecretKey=$(security find-generic-password -a "" -s "ATAPISecretKey" -w "$keychain")
security lock-keychain "$keychain" > /dev/null 2>&1

# Autotask API query
ATAPIQuery() {
    curl -sSL --globoff "$autotaskURL/$1/query?search=$2" \
    -H "ApiIntegrationCode: $ATAPIIntCode" \
    -H "UserName: $ATAPIUsername" \
    -H "Secret: $ATAPISecretKey" \
    -H "Content-Type: application/json"
}

ATAPIPost() {
    curl -sSL --globoff "$autotaskURL/Tickets" \
    -H "ApiIntegrationCode: $ATAPIIntCode" \
    -H "UserName: $ATAPIUsername" \
    -H "Secret: $ATAPISecretKey" \
    -H "Content-Type: application/json" \
    --data "$1"
}