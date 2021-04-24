#!/usr/bin/env bash

# exit codes:
## 0: updated / no change
## 1: API errored
## 2: API reports script error
## 3: script has previously errored

# parameters
hostname="CHANGE_ME" # your fully qualified domain name (FQDN)
username="CHANGE_ME" # your username, provided by DDNS service provider
password="CHANGE_ME" # your password, provided by DDNS service provider
ddns_api_proxy="CHANGE_ME" # proxy used for DDNS API in cURL format; set to "" if proxy is unnecessary

# go to script's source dir
cd `dirname "$0"`

# exit if script has previously errored
if [ -f "./script_error" ]; then
  echo "Script has previously errored; exiting"
  exit 3
fi

# clear proxy
export http_proxy=""
export https_proxy=""

# get current DNS info
dns_public_ip=`dig +short "$hostname"`
actual_public_ip=`curl --silent "https://api.ipify.org"`

# check for IP change
if [[ "$dns_public_ip" == "$actual_public_ip" ]]; then
  echo "Public IP has not changed: $dns_public_ip"
  exit 0
fi

# set proxy required for DDNS API
export http_proxy=$ddns_api_proxy
export https_proxy=$ddns_api_proxy

# send update request to DDNS API
req_url="https://$username:$password@domains.google.com/nic/update?hostname=$hostname&myip=$actual_public_ip"
ddns_res=`curl --silent "$req_url"`
echo "Update request sent:"
echo -e "\t$req_url"

# handle API response
if [[ "$ddns_res" =~ "good" ]]; then
  echo "Public IP successfully updated from $dns_public_ip to $actual_public_ip"
  exit 0
elif [[ "$ddns_res" =~ "nochg" ]]; then
  echo "API reports public IP has not changed: $dns_public_ip"
  exit 0
elif [[ "$ddns_res" =~ "911" ]]; then
  echo "API has errored; will keep retrying"
  exit 1
else
  echo "Error reason: $ddns_res" > "./script_error"
  echo "API reports request error: $ddns_res; will stop retrying"
  exit 2
fi
