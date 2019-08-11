.bail on

------------
-- tables --
------------

create table command (
  id integer primary key autoincrement,
  timestamp integer default (datetime('now')),
  user_id integer default null,
  type varchar not null
    constraint valid_command_name check (type in (
      'register',
      'create_game',
      'join_game'
    ) or (id = 1 and type = 'init')),
  arg1 varchar,
  arg2 varchar,
  foreign key (user_id) references user (id)
);

create table user (
  id integer primary key autoincrement,
  username varchar
    constraint username_length check (length(username) between 3 and 15),
  created_at integer default (datetime('now')),
  last_command_id integer not null,
  foreign key (last_command_id) references command (id)
);

create table session (
  id integer not null primary key,
  created_at integer default (datetime('now')),
  expires_at integer default (datetime('now', '+1 day')),
  user_id integer default null,
  foreign key (user_id) references user (id)
);

create table game (
  id integer not null primary key autoincrement,
  created_at integer default (datetime('now')),
  ends_at integer default null,
  owner integer not null,
  status varchar default 'created'
    constraint valid_game_status check (status in ('created', 'running', 'done')),
  secret_color varchar not null default (printf('%02x%02x%02x',
    abs(random()) % 255, abs(random()) % 255, abs(random()) % 255))
    constraint valid_color check (length(secret_color) = 6),
  foreign key (owner) references user (id)
);

create table user_game (
  user_id integer not null,
  game_id integer not null,
  created_at integer default (datetime('now')),
  primary key(user_id, game_id),
  foreign key (user_id) references user (id),
  foreign key (game_id) references game (id)
);

-----------
-- views --
-----------

create view create_command(session_id, type, arg1, arg2) as
  select raise(abort, 'write_only_view');

create view active_user (user_id, session_id, username, last_command_id) as
  select
    user.id as user_id,
    session.id as session_id,
    user.username,
    user.last_command_id
  from user inner join session on session.user_id = user.id
  where session.expires_at > datetime('now');

create view effect (command_id, type, shell_cmd) as
  -- nudge command author
  select id, 'nudge', printf('kill -s USR1 %d', session_id) as shell_cmd
  from command
  inner join active_user using (user_id)
  where command.type in ('register')

  -- nudge all active users to read their notifications
  union
  select id, 'nudge', printf('kill -s USR1 %d', session_id) as shell_cmd
  from command
  cross join active_user
  where command.type in ('create_game', 'join_game');

create view notification (session_id, event, timestamp, arg1, arg2) as
  select
    session_id,
    case type
      when 'register' then 'registered'
      when 'create_game' then 'game_created'
      when 'join_game' then 'game_joined'
    end as event,
    [timestamp], arg1, arg2
  from command
  cross join active_user
  where command.id > active_user.last_command_id
  and (
    case type
      when 'register' then command.user_id = active_user.user_id
      when 'create_game' then 1
      when 'join_game' then 1
    end
  )
  order by command.timestamp;

create view get__recentgames (session_id, item, id, status, secret_color) as
  select
    active_user.session_id,
    'game' as item,
    game.id,
    game.status,
    case game.status
      when 'done' then game.secret_color
      else null
      end as secret_color
  from game
  inner join active_user
  where created_at > datetime('now', '-30 minutes');

--------------
-- triggers --
--------------


create trigger register instead of insert on create_command
  when new.type = 'register'
  begin
    insert into user (username, last_command_id)
      values (new.arg1, (select seq from sqlite_sequence where name='command'));
    update session set
      user_id = last_insert_rowid()
      where id=new.session_id;
    insert into command(user_id, type, arg1, arg2)
      values (last_insert_rowid(), 'register', new.arg1, printf('%d:%s', last_insert_rowid(), new.arg1));
  end;

create trigger auth_layer instead of insert on create_command
  when new.type <> 'register'
  begin
    insert into command(user_id, type, arg1, arg2)
    select
      ifnull(active_user.user_id, raise(abort, 'login_required')) as user_id,
      new.type, new.arg1, new.arg2
    from session
    left join active_user on active_user.session_id = session.id
    where session.id = new.session_id;
  end;

create trigger on_create_game after insert on command
  when new.type = 'create_game'
  begin
    insert into game(owner) values (new.user_id);
    update command set arg1 = last_insert_rowid() where id = new.id;
  end;

create trigger on_join_game after insert on command
  when new.type = 'join_game'
  begin
    insert into user_game(user_id, game_id) values (new.user_id, new.arg1);
    update command set arg2 = (select printf('%d:%s', new.user_id, username) from user where id=new.user_id);
  end;

create trigger last_command instead of update of last_command_id on active_user
  begin
    update user set last_command_id = new.last_command_id
    where id = old.user_id;
  end;

----------
-- data --
----------

insert into command(user_id, type) values (NULL, 'init');
