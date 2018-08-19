#! /bin/sh

username="anonymous"
game=''
watch_pid=''
count_cmd=$(PATH=$PWD:$PATH which counter.sh)

validate='
/^register \S+$/p;
/^list$/p;
/^create$/p;
/^join \w{4}$/p;
/^leave$/p;
/^start$/p;
/^submit [a-fA-F0-9]{6}$/p;
'

echo "hello"

while read line
do
  cmd=$(echo "$line" | sed -rn "$validate" | cut -d ' ' -f 1)
  case $cmd in
    "")
    echo "`date -Ins` $username bad-message $line"
    continue
    ;;
  "register")
    username=$(echo $line | cut -d ' ' -f 2)
    echo "`date -Ins` $username registered"
    continue
    ;;
  "list")
    prefix="`date -Ins` $username gameitem"
    ls -rt "$GAME_FOLDER" | sed "s/^/$prefix /;s/\.log//g"
    game=''
    continue
    ;;
  "create")
    game=$(mktemp "$GAME_FOLDER/XXXX.log")
    line="$line $(basename -s .log $game)"
    echo "`date -Ins` $username $line"
    continue
    ;;
  "join")
    if [ -w $game ]; then
      kill $watch_pid 2>/dev/null
      hash=$(echo $line | cut -d ' ' -f 2)
      game="$GAME_FOLDER/$hash.log"
      tail -f -n 0 --pid=$$ $game & watch_pid=$!
      cat $game
      sleep 0.5
    else
      cat $game
      continue
    fi
    ;;
  "leave")
    kill $watch_pid 2>/dev/null
    game=''
    ;;
  "start")
    line="$line `head -c 100 /dev/urandom | sha1sum -b | head -c 6`"
    `$count_cmd $game` &
    ;;
  esac

  echo "`date -Ins` $username $line" >> $game
done
