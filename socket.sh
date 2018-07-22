#! /bin/sh

game="$GAME_FOLDER/aaa"
username="anonymous"

validate='
/^register [a-zA-Z0-9_\-]\{1,\}$/p;
/^join$/p;
/^start$/p;
/^submit [a-fA-F0-9]\{6\}$/p;
'

# output any new entry from now on
tail -f -n 0 --pid=$$ $game &

# append new entries
while read line
do
  cmd=$(echo "$line" | sed -n "$validate" | cut -d ' ' -f 1)
  case $cmd in
  "register")
    username=$(echo $line | cut -d ' ' -f 2)
    echo "`date -Ins` $username registered"
    continue
    ;;
  "")
    echo "`date -Ins` $username bad-message: $line"
    continue
    ;;
  "join")
    cat $game
    ;;
  "start")
    line="$line `head -c 100 /dev/urandom | sha1sum -b | head -c 6`"
    ;;
  esac

  echo "`date -Ins` $username $line" >> $game
done
