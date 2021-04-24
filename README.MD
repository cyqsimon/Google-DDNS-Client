## Google-DNS-Client
A bash script that uses Google Domain API to set DDNS for host

## Features
- Uses https://www.ipify.org/ to check for public IP
- Can use a custom proxy to access API if necessary
- Does not send request to API if current public IP matches DNS record
- Does not send further requests if API reports request error, to prevent being blacklisted
- Logs reason of failure in `script_error`
