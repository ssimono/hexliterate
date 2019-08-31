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
      'join_game',
      'start_game'
    ) or (id = 1 and type = 'init')),
  arg1 varchar,
  arg2 varchar,
  foreign key (user_id) references user (id)
);

create table user (
  id integer primary key autoincrement,
  username varchar
    constraint username_length check (length(username) between 3 and 15),
  created_at integer default (datetime('now'))
);

create table session (
  id integer not null primary key,
  created_at integer default (datetime('now')),
  expires_at integer default (datetime('now', '+1 day')),
  user_id integer default null,
  foreign key (user_id) references user (id)
);

create table notification (
  id integer not null primary key autoincrement,
  command_id integer not null,
  timestamp integer not null default (datetime('now')),
  name varchar not null,
  body varchar default null,
  scope varchar not null default 'system',
  foreign key (command_id) references command (id)
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

create view active_user (user_id, session_id, username) as
  select
    user.id as user_id,
    session.id as session_id,
    user.username
  from user inner join session on session.user_id = user.id
  where session.expires_at > datetime('now');

create view effect (type, shell_cmd) as
  select 'nudge', printf('kill -s USR1 %d', session_id) as shell_cmd
  from active_user;

create view get__notifications (session_id, event, timestamp, body) as
  with scoped_user as (
    select user_id, session_id, printf(
      'broadcast,user:%d,%s',
      user_id,
      case game.id
        when null then 'lobby'
        else case game.status
          when 'created' then printf('lobby,game:%d', game.id)
          when 'running' then printf('game:%d', game.id)
          else 'lobby'
        end
      end
    ) as scopes
    from active_user
    left join user_game using(user_id)
    left join game on user_game.game_id=game.id and game.status <> 'done'
  )
  select
    scoped_user.session_id,
    notification.name,
    cast (strftime('%s', notification.timestamp) as numeric) as timestamp,
    notification.body
  from notification
  inner join scoped_user on instr(scoped_user.scopes, notification.scope) > 0
  where notification.timestamp > datetime('now', '-1 day')
  order by notification.timestamp;

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

create view get__players (session_id, item, game_id, user, is_owner, user_status) as
  select
    active_user.session_id,
    'player' as item,
    user_game.game_id,
    player.user,
    player.is_owner,
    player.user_status
  from (
    select
      user_game.game_id,
      printf('%d:%s', user.id, user.username) as user,
      user.id=game.owner as is_owner,
      'guessing' as user_status,
      user_game.created_at
    from game
    inner join user_game on user_game.game_id=game.id
    inner join user on user.id=user_game.user_id
  ) as player
  inner join user_game using(game_id)
  inner join active_user using(user_id)
  order by player.created_at;

--------------
-- triggers --
--------------


create trigger register instead of insert on create_command
  when new.type = 'register'
  begin
    insert into user (username) values (new.arg1);
    update session set
      user_id = last_insert_rowid()
      where id=new.session_id;
    insert into command(user_id, type, arg1)
      values (last_insert_rowid(), 'register', new.arg1);
    insert into notification (command_id, name, body, scope)
      select
        last_insert_rowid() as command_id,
        'registered' as name,
        printf('%d:%s', user.id, user.username) as body,
        printf('user:%d', user.id) as scope
      from command
      inner join user on user.id=command.user_id
      where command.id=last_insert_rowid();
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
    insert into notification (command_id, name, body, scope)
      values(new.id, 'game_created', last_insert_rowid(), 'lobby');
  end;

create trigger on_join_game after insert on command
  when new.type = 'join_game'
  begin
    insert into user_game(user_id, game_id) values (new.user_id, new.arg1);
    insert into notification (command_id, name, body, scope)
      select
        new.id,
        'game_joined',
        printf('%d|%d:%s', new.arg1, new.user_id, username),
        printf('game:%s', new.arg1)
      from user where id=new.user_id;
  end;

create trigger on_start_game after insert on command
  when new.type = 'start_game'
  begin
    with current_game as (select * from game where id=new.arg1)
    select case exists (select id from current_game) when 0 then raise(abort, 'not_found') end
    union select case
        when current_game.owner <> new.user_id then raise(abort, 'forbidden')
        when current_game.status <> 'created' then raise(abort, 'invalid')
      end
    from current_game;
    update game
      set status='running', ends_at=datetime('now', '+30 seconds')
      where id=new.arg1;
    insert into notification (command_id, name, body, scope)
      select
        new.id,
        'game_started',
        printf('%d|%s', game.id, game.secret_color),
        printf('game:%s', new.arg1)
      from game where id=new.arg1;
  end;

----------
-- data --
----------

insert into command(user_id, type) values (NULL, 'init');
