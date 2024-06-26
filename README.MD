## Archival notice

Google Domain was purchased by Squarespace on 2023-06-15, with all domains transferred a year later on 2024-06-15. Google's DDNS API has since been shut down, and Squarespace irritatingly does not offer DDNS support. Therefore this repository is no longer useful.

Personally I have transferred my domain to [NameSilo](https://www.namesilo.com/). Their offering is inexpensive, reputable, and feature-rich (includes DDNS). For DDNS client, I can recommend [ddns-go](https://github.com/jeessy2/ddns-go/). It's written in a *real* language and is actively-maintained.

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
- Comes with an archiver script to reduce disk use by log files
- Written by an egotistic author who loves to write overly illustrious praises for his own work
