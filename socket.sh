#! /bin/bash

database='db.db'
session_id=$$
debug=$([[ -z $SQL_OUTPUT ]] && echo '' || echo ".trace $SQL_OUTPUT")

query(){
  sqlite3 -noheader -bail -cmd '.timeout 400' -cmd "$debug" $database <<< "$1"
}

# start the session
query "insert into session (id) values ($session_id);"
echo 'hello'

# handler for notification
read_notifications(){
  query "
    begin immediate transaction;
    select timestamp, event, arg1, arg2 from notification
      where session_id = $session_id;
    update active_user
      set last_command_id = (select seq from sqlite_sequence where name = 'command')
      where session_id = $session_id;
    commit;"
}
trap 'read_notifications' USR1

logout(){
  query "delete from session where id=$session_id"
}
trap 'logout' EXIT KILL

# read input from the client
while read cmd arg1 arg2
do
  grep -P '^[a-z_]{3,32}(:[a-zA-Z0-9+/]{0,100}){2}$' <<<"$cmd:$arg1:$arg2" >/dev/null || continue

  [[ $cmd == 'get' ]] && query "select * from [get__$arg1] where session_id=$session_id;" \
  || query "pragma foreign_keys=on; begin transaction;
    insert into create_command (session_id, type, arg1, arg2)
      values ($session_id, '$cmd', '$arg1', '$arg2');
    select shell_cmd from effect
      where command_id = (select seq from sqlite_sequence where name = 'command');
    commit;
    " | while read effect; do (eval $effect); done
done
