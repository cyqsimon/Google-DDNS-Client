## Google-DDNS-Client
A bash script that uses Google Domain API to set DDNS for host

For API docs, see https://support.google.com/domains/answer/6147083

## Features
- Very, very minimal code, with lots of comments
- Handles network errors gracefully
- Uses https://www.ipify.org/ to check for real public IP
- Can use a custom proxy to access API if necessary
- Does not send request to API if current public IP matches DNS record
- Does not send further requests if API reports request error, to prevent being blacklisted
