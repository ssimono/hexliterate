#! /bin/sh

username="anonymous"
game=''
watch_pid=''

validate='
/^register [a-zA-Z0-9_\-]\{1,\}$/p;
/^list$/p;
/^create$/p;
/^join [a-zA-Z0-9]\{4\}$/p;
/^leave$/p;
/^start$/p;
/^submit [a-fA-F0-9]\{6\}$/p;
'

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
  "list")
    echo -n "`date -Ins` $username $line "
    ls -m "$GAME_FOLDER" | sed 's/\.log//g'
    continue
    ;;
  "create")
    game=$(mktemp "$GAME_FOLDER/XXXX.log")
    line="$line $(basename -s .log $game)"
    echo "`date -Ins` $username $line"
    ;;
  "join")
    hash=$(echo $line | cut -d ' ' -f 2)
    kill $watch_pid 2>/dev/null
    game="$GAME_FOLDER/$hash.log"
    tail -f -n 0 --pid=$$ $game & watch_pid=$!
    cat $game
    ;;
  "leave")
    kill $watch_pid 2>/dev/null
    game=''
    ;;
  "start")
    line="$line `head -c 100 /dev/urandom | sha1sum -b | head -c 6`"
    ;;
  esac

  echo "`date -Ins` $username $line" >> $game
done
