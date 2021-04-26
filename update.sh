#!/usr/bin/env bash

# exit codes:
## 0: updated / no change
## 1: API errored
## 2: API reports script error
## 3: script has previously errored
## 4: other network error

# parameters
hostname="CHANGE_ME" # your fully qualified domain name (FQDN)
username="CHANGE_ME" # your username, provided by DDNS service provider
password="CHANGE_ME" # your password, provided by DDNS service provider
ddns_api_proxy="CHANGE_ME" # proxy used for DDNS API in cURL format; set to "" if proxy is unnecessary

# go to script's source dir
cd `dirname "$0"`

# exit if script has previously errored
if [ -f "./script_error" ]; then
  echo "G-DDNS: [$(date +"%F %T")] Script has previously errored; exiting"
  exit 3
fi

# clear proxy
export http_proxy=""
export https_proxy=""

# get current DNS mapping
dns_public_ip=`dig +short "$hostname"`

# get actual IP
actual_public_ip=`curl --silent --fail "https://api.ipify.org"`
curl_exit_code="$?"
if [[ "$curl_exit_code" != "0" ]]; then
  echo "G-DDNS: [$(date +"%F %T")] Cannot get current IP via API (cURL error $curl_exit_code); exiting; will keep retrying"
  exit 4
fi

# check for IP change
if [[ "$dns_public_ip" == "$actual_public_ip" ]]; then
  echo "G-DDNS: [$(date +"%F %T")] Public IP has not changed: $dns_public_ip"
  exit 0
fi

# set proxy required for DDNS API
export http_proxy=$ddns_api_proxy
export https_proxy=$ddns_api_proxy

# send update request to DDNS API
req_url="https://$username:$password@domains.google.com/nic/update?hostname=$hostname&myip=$actual_public_ip"
ddns_res=`curl --silent --fail "$req_url"`
curl_exit_code="$?"
echo "G-DDNS: [$(date +"%F %T")] Update request sent:"
echo -e "G-DDNS: [$(date +"%F %T")] \t$req_url"
if [[ "$curl_exit_code" != "0" ]]; then
  echo "G-DDNS: [$(date +"%F %T")] Update request via API failed (cURL error $curl_exit_code); exiting; will keep retrying"
  exit 4
fi

# handle API response
if [[ "$ddns_res" =~ "good" ]]; then
  echo "G-DDNS: [$(date +"%F %T")] Public IP successfully updated from $dns_public_ip to $actual_public_ip; exiting"
  exit 0
elif [[ "$ddns_res" =~ "nochg" ]]; then
  echo "G-DDNS: [$(date +"%F %T")] API reports public IP has not changed: $actual_public_ip; please wait for DNS record to propagate; exiting"
  exit 0
elif [[ "$ddns_res" =~ "911" ]]; then
  echo "G-DDNS: [$(date +"%F %T")] API has errored; exiting; will keep retrying"
  exit 1
else
  echo "[$(date +"%F %T")] Error reason: $ddns_res" > "./script_error"
  echo "G-DDNS: [$(date +"%F %T")] API reports request error: $ddns_res; exiting; will stop retrying"
  exit 2
fi
