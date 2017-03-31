#!/bin/bash

# This will run the cleanup function if ctrl-c is typed
trap cleanup INT

# temporary file to dump data
tmp_File="/tmp/access_logs.tmp"
# time limit for rerun question to be answered
time_limit="20"
# number of domains
default_num="3"
num=$1
if [[ -z "$num" ]]; then
  num="$default_num"
fi

# Removes temp file and deletes script
cleanup (){
  rm -f $tmp_File
  rm -f ./access_logs.sh && echo -e "\nScript deleted"
  exit 0
}

plesk_logCheck () {
  dom_sys_dirs=$(find /var/www/vhosts/system/* -maxdepth 0 -type d -print0 | xargs -0)
  for dom_Dir in $dom_sys_dirs; do
    total_hits=$(wc -l "$dom_Dir"/logs/access_log)
    # If access log has data, output of $total_hits is written to a temp file
    if [[ -s "$dom_Dir"/logs/access_log ]]; then
      echo "$total_hits" >> $tmp_File
    else
      echo "No domains found!"
      exit 0
    fi
  done
}

cpanel_logCheck () {
  domain_list=$(grep -Ev "*.accessdomain.com" /etc/localdomains | xargs)
  for dom in $domain_list; do
    log_Path="/usr/local/apache/domlogs/$dom"
    # If access log has data, output of $total_hits is written to a temp file
    if [[ -s "$log_Path" ]]; then
      total_hits=$(wc -l "$log_Path")
      echo "$total_hits" >> $tmp_File
    else
      echo "No domains found!"
      exit 0
    fi
  done
}

if [ -d "/usr/local/psa" ]; then
  plesk_logCheck
else [ -d "/usr/local/cpanel" ];
  cpanel_logCheck
fi

# total number of logs with data
access_count=$(wc -l $tmp_File | awk '{print $1}')
# sorts info in temp file and filters out top results
top_paths=$(sort -nr $tmp_File | head -$num | awk '{print $2}')
if [[ $access_count -lt "$default_num" ]]; then
  num="$access_count"
fi

# removes temp file after setting more variables
rm -f $tmp_File

clear
printf "\n===================================
Total domains with connections: $access_count
Showing connections for top: $num
==================================="
# this loop prints access log results
for log_Path in $top_paths; do
  domain=$(echo "$log_Path" | awk -F'/' '{print $6}')
  total_hits=$(wc -l "$log_Path" | awk '{print $1}')
  since_time=$(head -1 "$log_Path" | sed -e 's/.*\[\(.*\)\].*/\1/')
  echo -e "\n$domain - total hits: $total_hits - since: $since_time"
  echo "$log_Path"
  echo "Top 5 IPs:"
  # prints top 5 IPs in the access log
  awk '{print $1}' "$log_Path" | sort | uniq -c | sort -nr | head -5
  echo ""
done
# if more than 3 domains have data in access logs, ask to rerun
if [[ "$access_count" -gt "$default_num" ]] && [[ "$access_count" != "$num" ]]; then
  echo
  read -t $time_limit -n 1 -p 'Rerun the script on more domains?: ' rerun
  if [[ "$rerun" ]]; then
    echo
    case "$rerun" in
      Y|y)
        # allows you to enter num of domains to rerun script on
        read -t $time_limit -p "How many domains? (max:$access_count): " dom_choice
        # tests that an integer was passed in last question
        if ! [[ "$dom_choice" =~ ^[0-9]+$ ]] ; then
          echo -e "\nInvalid entry or script timed out. Removing script."
        # reruns script on specified num of domains if valid number is passed
        elif [[ "$dom_choice" -gt 0 ]] && [[ "$dom_choice" -lt "$access_count" ]]; then
          bash "$0" "$dom_choice"
          exit 0
        # if num entered is larger than total doms with data, rerun script on max num of domains with data
        elif [[ "$dom_choice" -ge "$access_count" ]]; then
          bash "$0" "$access_count"
          exit 0
        else
          echo -e "\nYou typed 0. Removing script."
        fi
        ;;
      *)
        echo -e "\nRemoving script."
    esac
  else
    echo -e "\nInvalid entry or script timed out. Removing script."
  fi
fi

# calls cleanup function
cleanup
