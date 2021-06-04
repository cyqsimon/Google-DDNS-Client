#!/usr/bin/env bash

# exit codes:
## 0: updated / no change
## 1: Google DDNS API errored
## 2: Google DDNS API reports request error
## 3: Google DDNS API request has previously errored
## 4: network error
## 5: ipify API errored

# parameters
hostname="CHANGE_ME" # your fully qualified domain name (FQDN)
username="CHANGE_ME" # your username, provided by DDNS service provider
password="CHANGE_ME" # your password, provided by DDNS service provider
ddns_api_proxy="CHANGE_ME" # proxy used for DDNS API in cURL format; set to "" if proxy is unnecessary
tmp_path="/tmp/google-ddns-client" # path to temp file
log_path="./log.txt" # path to log file

# helper functions
function prefix_log {
  echo -e "G-DDNS: [$(date +"%F %T")] $1" | tee -a "$log_path"
}

# go to script's source dir
cd `dirname "$0"`

# exit if script has previously errored
if [ -f "./script_error" ]; then
  prefix_log "Google API DDNS request has previously errored; exiting"
  exit 3
fi

# clear proxy
export http_proxy=""
export https_proxy=""

# get current DNS mapping
# retry in case DNS is badly-behaved (e.g. many ISP routers)
dig_attempts=0
while true; do
  dns_records=`dig +short "$hostname"`
  dig_exit_code="$?"
  if [[ "$dig_exit_code" != "0" ]]; then
    prefix_log "Cannot get current DNS mapping (dig error $dig_exit_code); exiting; will keep retrying"
    exit 4
  fi
  dns_public_ip=`echo "$dns_records" | grep -v ":" | head -1` # filter out IPv6 and use 1st entry
  if [[ "$dns_public_ip" == "" ]]; then
    # dig found no IP
    if [[ $dig_attempts -lt 2 ]]; then # try up to 3 times
      dig_attempts=$((dig_attempts + 1))
      prefix_log "dig found no current DNS mapping (attempt #$dig_attempts); retrying in 3 seconds"
      sleep 3
      continue
    else
      prefix_log "dig found no current DNS mapping after $dig_attempts attempts; continuing with update"
      break
    fi
  else
    prefix_log "$hostname is currently mapped to $dns_public_ip"
    break
  fi
done

# get actual IP
curl_status=`curl --silent --output "$tmp_path" --write-out "%{http_code}" "https://api.ipify.org"`
curl_exit_code="$?"
if [[ "$curl_exit_code" != "0" ]]; then
  prefix_log "Cannot get current IP via ipify API (cURL error $curl_exit_code); exiting; will keep retrying"
  exit 4
fi
if (( $curl_status > 399 )); then
  prefix_log "Cannot get current IP via ipify API (bad http status $curl_status); exiting; will keep retrying"
  exit 5
fi
actual_public_ip=`cat "$tmp_path"`

# check for IP change
if [[ "$dns_public_ip" == "$actual_public_ip" ]]; then
  prefix_log "Public IP has not changed: $dns_public_ip"
  exit 0
fi

# set proxy required for DDNS API
export http_proxy=$ddns_api_proxy
export https_proxy=$ddns_api_proxy

# send update request to DDNS API
req_url="https://$username:$password@domains.google.com/nic/update?hostname=$hostname&myip=$actual_public_ip"
req_url_print="https://****:****@domains.google.com/nic/update?hostname=$hostname&myip=$actual_public_ip"
curl_status=`curl --silent --output "$tmp_path" --write-out "%{http_code}" "$req_url"`
curl_exit_code="$?"
prefix_log "Update request sent:"
prefix_log "\t(username & password hidden) $req_url_print"
if [[ "$curl_exit_code" != "0" ]]; then
  prefix_log "Update request via G-DDNS API failed (cURL error $curl_exit_code); exiting; will keep retrying"
  exit 4
fi
if (( $curl_status > 399 )); then
  prefix_log "G-DDNS API has errored (bad http status $curl_status); exiting; will keep retrying"
  exit 1
fi
ddns_res=`cat "$tmp_path"`

# handle API response
if [[ "$ddns_res" =~ "good" ]]; then
  prefix_log "Public IP successfully updated from $dns_public_ip to $actual_public_ip; exiting"
  exit 0
elif [[ "$ddns_res" =~ "nochg" ]]; then
  prefix_log "G-DDNS API reports public IP has not changed: $actual_public_ip; please wait for DNS record to propagate; exiting"
  exit 0
elif [[ "$ddns_res" =~ "911" ]]; then
  prefix_log "G-DDNS API has errored (response body 911); exiting; will keep retrying"
  exit 1
else
  touch "./script_error"
  prefix_log "G-DDNS API reports request error: $ddns_res; exiting; will stop retrying"
  exit 2
fi
