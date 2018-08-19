#! /bin/sh

[ -z $TIMEOUT ] && export TIMEOUT=30

for count in $(seq $TIMEOUT -1 0)
do
  sleep 1
  echo `date -Ins` countdown $count >> "$1"
done
chmod a-w "$1"
