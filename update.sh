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
tmp_path="/tmp/google-ddns-client" # path to temp file
log_path="./log.txt" # path to log file

# go to script's source dir
cd `dirname "$0"`

# exit if script has previously errored
if [ -f "./script_error" ]; then
  echo "G-DDNS: [$(date +"%F %T")] Script has previously errored; exiting" | tee -a "$log_path"
  exit 3
fi

# clear proxy
export http_proxy=""
export https_proxy=""

# get current DNS mapping
dns_records=`dig +short "$hostname"`
dig_exit_code="$?"
if [[ "$dig_exit_code" != "0" ]]; then
  echo "G-DDNS: [$(date +"%F %T")] Cannot get current DNS mapping (dig error $dig_exit_code); exiting; will keep retrying" | tee -a "$log_path"
  exit 4
fi
dns_public_ip=`echo "$dns_records" | grep -v ":" | head -1` # filter out IPv6 and use 1st entry
if [[ "$dns_public_ip" == "" ]]; then
  echo "G-DDNS: [$(date +"%F %T")] Found no current DNS mapping" | tee -a "$log_path"
fi

# get actual IP
curl_status=`curl --silent --output "$tmp_path" --write-out "%{http_code}" "https://api.ipify.org"`
curl_exit_code="$?"
if [[ "$curl_exit_code" != "0" ]]; then
  echo "G-DDNS: [$(date +"%F %T")] Cannot get current IP via ipify API (cURL error $curl_exit_code); exiting; will keep retrying" | tee -a "$log_path"
  exit 4
fi
if (( $curl_status > 399 )); then
  echo "G-DDNS: [$(date +"%F %T")] Cannot get current IP via ipify API (bad response $curl_status); exiting; will keep retrying" | tee -a "$log_path"
  exit 4
fi
actual_public_ip=`cat "$tmp_path"`

# check for IP change
if [[ "$dns_public_ip" == "$actual_public_ip" ]]; then
  echo "G-DDNS: [$(date +"%F %T")] Public IP has not changed: $dns_public_ip" | tee -a "$log_path"
  exit 0
fi

# set proxy required for DDNS API
export http_proxy=$ddns_api_proxy
export https_proxy=$ddns_api_proxy

# send update request to DDNS API
req_url="https://$username:$password@domains.google.com/nic/update?hostname=$hostname&myip=$actual_public_ip"
curl_status=`curl --silent --output "$tmp_path" --write-out "%{http_code}" "$req_url"`
curl_exit_code="$?"
echo "G-DDNS: [$(date +"%F %T")] Update request sent:" | tee -a "$log_path"
echo -e "G-DDNS: [$(date +"%F %T")] \t$req_url" | tee -a "$log_path"
if [[ "$curl_exit_code" != "0" ]]; then
  echo "G-DDNS: [$(date +"%F %T")] Update request via G-DDNS API failed (cURL error $curl_exit_code); exiting; will keep retrying" | tee -a "$log_path"
  exit 4
fi
if (( $curl_status > 399 )); then
  echo "G-DDNS: [$(date +"%F %T")] Update request via G-DDNS API failed (bad response $curl_status); exiting; will keep retrying" | tee -a "$log_path"
  exit 4
fi
ddns_res=`cat "$tmp_path"`

# handle API response
if [[ "$ddns_res" =~ "good" ]]; then
  echo "G-DDNS: [$(date +"%F %T")] Public IP successfully updated from $dns_public_ip to $actual_public_ip; exiting" | tee -a "$log_path"
  exit 0
elif [[ "$ddns_res" =~ "nochg" ]]; then
  echo "G-DDNS: [$(date +"%F %T")] G-DDNS API reports public IP has not changed: $actual_public_ip; please wait for DNS record to propagate; exiting" | tee -a "$log_path"
  exit 0
elif [[ "$ddns_res" =~ "911" ]]; then
  echo "G-DDNS: [$(date +"%F %T")] G-DDNS API has errored; exiting; will keep retrying" | tee -a "$log_path"
  exit 1
else
  touch "./script_error"
  echo "G-DDNS: [$(date +"%F %T")] G-DDNS API reports request error: $ddns_res; exiting; will stop retrying" | tee -a "$log_path"
  exit 2
fi
