#!/bin/bash
# vim: fdm=marker fdl=0
#
# This script will download the latest Maxware from Maxeler given your account and Password without root access
# It is modified from maxupdater
#
# Author: Conghui He <heconghui@gmail.com>
#

download_folder=maxdownload
cookie=${download_folder}/mymaxeler.cookiejar

function get { #{{{
  # $1 is long filename
  # $2 is the filename
  # $3 is the timestamp
  # $4 is the md5sum

  if [[  -e "$download_folder/${2}" && `md5sum "$download_folder/${2}"` != "$2" ]]; then
    return 0
  else
    wget -O "$download_folder/${2}" \
      --user-agent "MaxUpdater/2.0" \
      --keep-session-cookies \
      --load-cookies $cookie \
      "https://www.maxeler.com/${1}"
  fi
}
#}}}
function get_and_install { #{{{
  # $1 is the line from the website
  # $2 is 1 if this is a core package, or 0 otherwise
  long_filename=`echo "$1" | awk -F';' '{ print $2 }'`
  filename=`basename $long_filename`
  pkgname=`basename "$filename"| awk -F_ '{print $1}'`
  md5=`echo "$1" | awk -F';' '{ print $4 }'`

  echo "Processing ${filename}"

  get "${long_filename}" "${filename}" "${md5}"
}#}}}

echo "Please provide your MyMaxeler details to authenticate with the update server"
read -p "MyMaxeler Email: " mymax_user
read -s -p "MyMaxeler Password: " mymax_pass

mkdir -p $download_folder

echo ""
echo "Authenticating..."
wget --user-agent "MaxUpdater/2.0" \
  --save-cookies $cookie \
  --keep-session-cookies \
  --post-data "email=${mymax_user}&pwd=${mymax_pass}&redirect_to=/mymaxeler/autoupdate&wp-submit=Sign In" \
  -qO - \
  https://www.maxeler.com//mymaxeler/ | grep "password is not recognised" > /dev/null

if [ $? -eq 0 ]; then
  echo "Login failed. Please check your login details and try again" >&2
  abort 10
fi

echo "Retrieving file listing..."
wget --user-agent "MaxUpdater/2.0" \
  --load-cookies $cookie \
  --keep-session-cookies \
  -qO /tmp/maxupdater_listing \
  https://www.maxeler.com/mymaxeler/autoupdate/

grep -q BEGIN-AUTO-UPDATE /tmp/maxupdater_listing
if [ $? -ne 0 ]; then
  echo "Could not retrieve update listing. Please try again later" >&2
  abort 2
fi
sed -i -e ' 1,/BEGIN-AUTO-UPDATE/d' -e '/END-AUTO-UPDATE/,$d' /tmp/maxupdater_listing

corelines=`grep MaxelerOS\; /tmp/maxupdater_listing`
compilerlines=`grep MaxCompiler\; /tmp/maxupdater_listing`
otherlines=`grep -v MaxelerOS\; /tmp/maxupdater_listing|grep -v MaxCompiler\; |grep \;`
corelines=$(for line in $corelines; do echo $line | grep -v maxeleros-mpcx; done)

while read line; do
  if [[ -n $line ]]; then
    get_and_install "${line}" 1
  fi
done < /tmp/maxupdater_listing
