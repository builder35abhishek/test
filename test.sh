#!/bin/bash

## Variables ##
whitelist="/etc/apache2/whitelist.conf"
vhost_conf="/etc/apache2/mods-available/info.conf"
log_file="/var/log/whitelist.log"
searchprm="Require ip"
whitelisted_ip="/etc/apache2/whitelisted_ip.lst"
tmp1=/tmp/tmp1.log


## Funtions ##

function check_rc {
  if [ "$2" != "0" ];then
    echo "`date "+%Y-%m-%d %H:%M:%S "` $1" | tee -a $log_file
    echo "$1" | mail -s "Error: Whitelistscript" root@localhost
  else
    echo "`date "+%Y-%m-%d %H:%M:%S "` $1" | tee -a $log_file
    echo "$1" | mail -s "Whitelistscript" root@localhost
  fi
  
}

## Prerequisites ## 

#Check if required files exisits
if [ ! -f $whitelist ]; then
  check_rc "$whitelist doesent exists" "2"
fi

if [ ! -f $vhost_conf ]; then
  check_rc "$vhost_conf doesent exists." "3"
fi

if [ ! -f $log_file ]; then
  echo "`date "+%Y-%m-%d %H:%M:%S "` Creating log file at $log_file" >> $log_file
  touch $log_file
fi

if [ ! -f $whitelisted_ip ]; then
  echo "`date "+%Y-%m-%d %H:%M:%S "` Creating whitelisted IP list at $whitelisted_ip" >> $log_file
  touch $whitelisted_ip
fi


## Main ##

inotifywait -e close_write -m  |
while :
 do

  # List currently whitelisted IP
  grep "\$searchprm" $vhost_conf > $whitelisted_ip
  sed -i 's/\$searchprm //g' $whitelisted_ip
  sed 's/\s\+/\n/g' $whitelisted_ip
  
  # Check if difference whitelisted_ip and whitelist.conf
  diff $whitelisted_ip $whitelist | egrep ">" | awk '{print $2}' > $tmp1
  check_rc "Error while checking difference" "$?"
  
  if [ ! -s $tmp1 ]; then
    echo "`date "+%Y-%m-%d %H:%M:%S "` All IPs are already whitelisted. No any new IP found in $whitelist" >> $log_file
  else
    echo "Backing up $vhost_conf"
    cp -rp $vhost_conf $vhost_conf_bkp_`date "+%Y%m%d_%H%M"`
  fi
  
  # Add new IP in vhost_conf
  for i in `cat $tmp1` 
  do
    sed -i '/\$searchprm/ s/$/\$i ' $vhost_conf
    check_rc "Error while adding IP in $vhost_conf" "$?"
    echo "`date "+%Y-%m-%d %H:%M:%S "` Verifying new IP in $vhost_conf" >> $log_file
    if [ "X`grep $i $vhost_conf`" != "X" ]; then
      echo "`date "+%Y-%m-%d %H:%M:%S "` IP $i successfully added in $vhost_conf" >> $log_file
    else
      echo "`date "+%Y-%m-%d %H:%M:%S "` IP $i not added in $vhost_conf" >> $log_file
    fi
  done
done

## End ##
#########
