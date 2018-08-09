#! /bin/sh

for count in $(seq 20 -1 0)
do
  sleep 1
  echo `date -Ins` countdown $count >> "$1"
done
chmod a-w "$1"
