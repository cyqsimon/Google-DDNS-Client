#!/usr/bin/env bash

# parameters
log_path="./log.txt" # path to log file
log_archive_dir="./log_archive" # directory of archived logs

# go to script's source dir
cd `dirname "$0"`

# exit if log file is empty
if [[ ! -s "$log_path" ]]; then
  echo "Log file is empty; exiting"
  exit 0
fi

# check if 7za exists, else fall back to zip
which 7za 1> /dev/null 2> 1
use_zip="$?"

# make archive directory
mkdir -p "$log_archive_dir"

# archive and clear
if [[ "$use_zip" == "0" ]]; then
  archive_name="$log_archive_dir/log_$(date +"%F_%T").7z"
  7za a -y -bsp0 -bso0 "$archive_name" "$log_path"
  7za t -y -bsp0 -bso0 "$archive_name"
  if [[ "$?" == "0" ]]; then
    > "$log_path"
    echo "Current logs archived to $(realpath "$archive_name")"
  else
    rm -f "$archive_name"
    echo "Archiving with 7za failed, exiting"
  fi
else
  archive_name="$log_archive_dir/log_$(date +"%F_%T").zip"
  zip --quiet --move --test "$archive_name" "$log_path"
  if [[ "$?" == "0" ]]; then
    touch "$log_path"
    echo "Current logs archived to $(realpath "$archive_name")"
  else
    rm -f "$archive_name"
    echo "Archiving with zip failed, exiting"
  fi
fi
