-- VSRG Hub online, update 2: replays checked against the score, plays sent in bulk, admins.
--
-- Run this whole file once in the Supabase SQL editor, after schema.sql (it can be run again).
--
-- Every score now comes with its replay's hit offsets. The server works the score's Wife% out again
-- from them, exactly as Etterna does (Wife3, judge 4), and only a score whose replay gives back its
-- Wife% counts for the rankings ("verified"); one whose replay gives something else is refused.
-- Every chart's note count is kept from its first verified score, so a later score claiming
-- another count doesn't count either. Scores sent before this update stay counted.
--
-- Admins (profiles.is_admin, set by hand: see the end) can take a score off the rankings and ban a
-- player.

alter table public.profiles add column if not exists is_admin boolean not null default false;
alter table public.profiles add column if not exists submit_window timestamptz not null default now();
alter table public.profiles add column if not exists submit_count int not null default 0;

-- which version of this script the server has (the launcher asks, and says when it's behind)
create table if not exists public.vh_meta (key text primary key, value text not null);
alter table public.vh_meta enable row level security;
drop policy if exists "meta is public" on public.vh_meta;
create policy "meta is public" on public.vh_meta for select using (true);
revoke insert, update, delete on public.vh_meta from anon, authenticated;
create or replace function public.server_version() returns int
language sql stable security definer set search_path = public as $$
	select coalesce((select value::int from public.vh_meta where key = 'schema_version'), 0)
$$;
grant execute on function public.server_version() to anon, authenticated;
alter table public.scores add column if not exists verified boolean not null default false;
alter table public.scores add column if not exists notes int not null default 0;
alter table public.scores add column if not exists removed_by uuid;

-- (the scores sent before this update were already counted: they stay so)
update public.scores set verified = true where not verified and not exists (select 1 from public.scores s2 where s2.verified);

create table if not exists public.replays (
	score_id bigint primary key references public.scores (id) on delete cascade,
	offsets real[] not null,          -- each tap's offset in ms (misses as Etterna keeps them, 1000)
	taps int not null,
	holds_missed int not null default 0,
	mines_hit int not null default 0
);
alter table public.replays enable row level security;
drop policy if exists "replays are public" on public.replays;
create policy "replays are public" on public.replays for select using (true);
revoke insert, update, delete on public.replays from anon, authenticated;

create table if not exists public.charts (
	chart_key text primary key,
	keys smallint not null,
	notes int not null,
	song_title text not null default '',
	song_artist text not null default '',
	chart_name text not null default '',
	first_score bigint
);
alter table public.charts enable row level security;
drop policy if exists "charts are public" on public.charts;
create policy "charts are public" on public.charts for select using (true);
revoke insert, update, delete on public.charts from anon, authenticated;

-- ---------------------------------------------------------------------------------------------
-- Etterna's Wife3 (RageUtil.h): points for a hit at maxms from the note at window scale ts (1 = J4),
-- with Etterna's own erf approximation (Abramowitz & Stegun 7.1.26) so the numbers are the same

create or replace function public.vh_erf(x double precision) returns double precision
language plpgsql immutable as $$
declare
	s double precision := sign(x);
	t double precision;
	y double precision;
begin
	if s = 0 then return 0; end if;
	x := abs(x);
	t := 1.0 / (1.0 + 0.3275911 * x);
	y := 1.0 - (((((1.061405429 * t + -1.453152027) * t) + 1.421413741) * t + -0.284496736) * t + 0.254829592) * t * exp(-x * x);
	return s * y;
end $$;

create or replace function public.vh_wife3(ms double precision, ts double precision default 1) returns double precision
language plpgsql immutable as $$
declare
	m double precision := abs(ms);
	ridic double precision := 5.0 * ts;
	max_boo double precision := 180.0 * ts;
	zero double precision := 65.0 * power(ts, 0.75);
	dev double precision := 22.7 * power(ts, 0.75);
begin
	if m <= ridic then return 2.0; end if;
	if m <= zero then return 2.0 * public.vh_erf((zero - m) / dev); end if;
	if m <= max_boo then return (m - zero) * -5.5 / (max_boo - zero); end if;
	return -5.5;
end $$;

-- a play's Wife% (J4) from its replay (one SQL expression over the offsets: a loop calling
-- vh_wife3 for each of thousands of offsets, a hundred scores at a time, ran past the server's
-- statement timeout)
create or replace function public.vh_rescore(offsets real[], taps int, holds_missed int, mines_hit int)
returns double precision language sql immutable as $$
	select case when taps is null or taps <= 0 then null else
		((select coalesce(sum(
			case when abs(o) <= 5.0 then 2.0
				when abs(o) <= 65.0 then 2.0 * (
					-- erf((65 - |o|) / 22.7), Abramowitz & Stegun 7.1.26
					(select s * (1.0 - (((((1.061405429 * tt + -1.453152027) * tt) + 1.421413741) * tt + -0.284496736) * tt + 0.254829592) * tt * exp(-x * x))
					 from (select (65.0 - abs(o)) / 22.7 as x0) a,
						lateral (select sign(x0) as s, abs(x0) as x) b,
						lateral (select 1.0 / (1.0 + 0.3275911 * x) as tt) c))
				when abs(o) <= 180.0 then (abs(o) - 65.0) * -5.5 / (180.0 - 65.0)
				else -5.5 end), 0)
		  from unnest(offsets) as o)
		 + coalesce(holds_missed, 0) * -4.5 + coalesce(mines_hit, 0) * -7.0) / (taps * 2.0) * 100.0 end
$$;

-- where a play came from: Etterna, or an osu! stable / osu!lazer replay VSRG Hub rated
alter table public.scores add column if not exists source text not null default 'etterna';
alter table public.scores drop constraint if exists scores_source_check;
alter table public.scores add constraint scores_source_check check (source in ('etterna', 'osu', 'lazer', 'quaver'));

-- (osu! plays sent before this column was there: told by their modifiers, "osu! ..." / "osu!lazer ...")
update public.scores set source = 'lazer' where source = 'etterna' and modifiers like 'osu!lazer%';
update public.scores set source = 'osu' where source = 'etterna' and modifiers like 'osu!%' and modifiers not like 'osu!lazer%';
update public.scores set source = 'quaver' where source = 'etterna' and modifiers like 'Quaver%';

-- ---------------------------------------------------------------------------------------------
-- ratings and rankings: verified scores only

create or replace function public.vh_refresh_rating(uid uuid, k smallint) returns void
language plpgsql security definer set search_path = public as $$
declare
	r public.player_ratings%rowtype;
begin
	with best as (
		select distinct on (chart_key, rate) *
		from public.scores
		where user_id = uid and keys = k and valid and verified
		order by chart_key, rate, ssr_overall desc
	)
	select uid, k, 0,
		public.vh_aggregate(array_agg(ssr_stream)), public.vh_aggregate(array_agg(ssr_jumpstream)),
		public.vh_aggregate(array_agg(ssr_handstream)), public.vh_aggregate(array_agg(ssr_stamina)),
		public.vh_aggregate(array_agg(ssr_jackspeed)), public.vh_aggregate(array_agg(ssr_chordjack)),
		public.vh_aggregate(array_agg(ssr_technical)), count(*), now()
	into r from best;
	-- (Etterna's calculator doesn't rate Technical for 7K: it gives every 7K chart the same 0.18, so
	-- the 7K overall is the mean of the six skillsets it does rate)
	if k = 7 then
		r.overall := (r.stream + r.jumpstream + r.handstream + r.stamina + r.jackspeed + r.chordjack) / 6.0;
	else
		r.overall := (r.stream + r.jumpstream + r.handstream + r.stamina + r.jackspeed + r.chordjack + r.technical) / 7.0;
	end if;
	insert into public.player_ratings values (r.*)
	on conflict (user_id, keys) do update set
		overall = excluded.overall, stream = excluded.stream, jumpstream = excluded.jumpstream,
		handstream = excluded.handstream, stamina = excluded.stamina, jackspeed = excluded.jackspeed,
		chordjack = excluded.chordjack, technical = excluded.technical, plays = excluded.plays,
		updated_at = excluded.updated_at;
end $$;
revoke all on function public.vh_refresh_rating(uuid, smallint) from public, anon, authenticated;

-- one score, kept (the replay checked): returns its keys, or null when it was already there.
-- Raises when it is refused.
create or replace function public.vh_insert_score(uid uuid, s jsonb) returns smallint
language plpgsql security definer set search_path = public as $$
declare
	k smallint := (s->>'keys')::smallint;
	wife real := (s->>'wife')::real;
	offs real[];
	taps int := coalesce((s->>'total_taps')::int, 0);
	holds int := coalesce((s->>'holds_missed')::int, 0);
	mines int := coalesce((s->>'mines_hit')::int, 0);
	judged int;
	again double precision;
	ok boolean := false;
	known public.charts;
	sid bigint;
begin
	judged := coalesce((s->>'marvelous')::int, 0) + coalesce((s->>'perfect')::int, 0) + coalesce((s->>'great')::int, 0)
		+ coalesce((s->>'good')::int, 0) + coalesce((s->>'bad')::int, 0) + coalesce((s->>'miss')::int, 0);
	if jsonb_typeof(s->'offsets') = 'array' then
		select array_agg(x::real) into offs from jsonb_array_elements_text(s->'offsets') as x;
	end if;
	if offs is not null then
		if taps <> judged or cardinality(offs) < taps - 2 or cardinality(offs) > taps + 2 then
			raise exception 'the replay doesn''t match the score''s judgements';
		end if;
		again := public.vh_rescore(offs, taps, holds, mines);
		if again is null or abs(again - wife) > 1.0 then
			raise exception 'the replay doesn''t give the score''s accuracy (% against %)', round(again::numeric, 2)::text || '%', round(wife::numeric, 2)::text || '%';
		end if;
		ok := abs(again - wife) <= 0.3;
		-- (the chart's note count, from the first verified score on it)
		select * into known from public.charts where chart_key = s->>'chart_key';
		if found and known.notes <> taps then ok := false; end if;
	end if;
	insert into public.scores (user_id, score_key, chart_key, keys, rate, wife,
		ssr_overall, ssr_stream, ssr_jumpstream, ssr_handstream, ssr_stamina, ssr_jackspeed,
		ssr_chordjack, ssr_technical, msd, marvelous, perfect, great, good, bad, miss, holds_ok,
		holds_ng, mines_hit, max_combo, modifiers, song_title, song_artist, chart_name, played_at,
		has_replay, verified, notes, source)
	values (uid, s->>'score_key', s->>'chart_key', k, (s->>'rate')::real, wife,
		coalesce((s->>'ssr_overall')::real, 0), coalesce((s->>'ssr_stream')::real, 0),
		coalesce((s->>'ssr_jumpstream')::real, 0), coalesce((s->>'ssr_handstream')::real, 0),
		coalesce((s->>'ssr_stamina')::real, 0), coalesce((s->>'ssr_jackspeed')::real, 0),
		coalesce((s->>'ssr_chordjack')::real, 0), coalesce((s->>'ssr_technical')::real, 0),
		coalesce((s->>'msd')::real, 0),
		coalesce((s->>'marvelous')::int, 0), coalesce((s->>'perfect')::int, 0),
		coalesce((s->>'great')::int, 0), coalesce((s->>'good')::int, 0),
		coalesce((s->>'bad')::int, 0), coalesce((s->>'miss')::int, 0),
		coalesce((s->>'holds_ok')::int, 0), coalesce((s->>'holds_ng')::int, 0),
		mines, coalesce((s->>'max_combo')::int, 0),
		left(coalesce(s->>'modifiers', ''), 200), left(coalesce(s->>'song_title', ''), 200),
		left(coalesce(s->>'song_artist', ''), 200), left(coalesce(s->>'chart_name', ''), 100),
		(s->>'played_at')::timestamptz, offs is not null, ok, taps,
		case when s->>'source' in ('osu', 'lazer', 'quaver') then s->>'source' else 'etterna' end)
	on conflict (user_id, score_key) do nothing
	returning id into sid;
	if sid is null then return null; end if;
	if offs is not null then
		insert into public.replays (score_id, offsets, taps, holds_missed, mines_hit) values (sid, offs, taps, holds, mines);
		if ok and known.chart_key is null then
			insert into public.charts (chart_key, keys, notes, song_title, song_artist, chart_name, first_score)
			values (s->>'chart_key', k, taps, left(coalesce(s->>'song_title', ''), 200), left(coalesce(s->>'song_artist', ''), 200),
				left(coalesce(s->>'chart_name', ''), 100), sid)
			on conflict (chart_key) do nothing;
		end if;
	end if;
	return k;
end $$;
revoke all on function public.vh_insert_score(uuid, jsonb) from public, anon, authenticated;

create or replace function public.submit_score(s jsonb) returns public.player_ratings
language plpgsql security definer set search_path = public as $$
declare
	uid uuid := auth.uid();
	k smallint := (s->>'keys')::smallint;
	r public.player_ratings;
begin
	if uid is null then raise exception 'not signed in'; end if;
	if not exists (select 1 from public.profiles where id = uid and not banned) then
		raise exception 'no player profile';
	end if;
	perform public.vh_insert_score(uid, s);
	perform public.vh_refresh_rating(uid, k);
	select * into r from public.player_ratings where user_id = uid and keys = k;
	return r;
end $$;
grant execute on function public.submit_score(jsonb) to authenticated;

-- many scores at once (your older plays): each kept or refused on its own; the ratings worked out once.
-- Returns {"kept": n, "refused": [{"score_key": ..., "error": ...}]}
create or replace function public.submit_scores(list jsonb) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
	uid uuid := auth.uid();
	s jsonb;
	kept int := 0;
	refused jsonb := '[]'::jsonb;
	did4 boolean := false;
	did7 boolean := false;
	k smallint;
begin
	if uid is null then raise exception 'not signed in'; end if;
	if not exists (select 1 from public.profiles where id = uid and not banned) then
		raise exception 'no player profile';
	end if;
	if jsonb_typeof(list) <> 'array' or jsonb_array_length(list) > 500 then
		raise exception 'send at most 500 scores at a time';
	end if;
	-- (a cap per player: 5000 scores in ten minutes is more than any real backfill needs)
	update public.profiles set submit_window = case when submit_window < now() - interval '10 minutes' then now() else submit_window end,
		submit_count = case when submit_window < now() - interval '10 minutes' then 0 else submit_count end
		where id = uid;
	if (select submit_count from public.profiles where id = uid) + jsonb_array_length(list) > 5000 then
		raise exception 'rate limit: too many scores sent lately, try again in a few minutes';
	end if;
	update public.profiles set submit_count = submit_count + jsonb_array_length(list) where id = uid;
	for s in select * from jsonb_array_elements(list) loop
		begin
			k := public.vh_insert_score(uid, s);
			if k is not null then
				kept := kept + 1;
				if k = 4 then did4 := true; elsif k = 7 then did7 := true; end if;
			end if;
		exception when others then
			refused := refused || jsonb_build_object('score_key', s->>'score_key', 'error', sqlerrm);
		end;
	end loop;
	if did4 then perform public.vh_refresh_rating(uid, 4::smallint); end if;
	if did7 then perform public.vh_refresh_rating(uid, 7::smallint); end if;
	return jsonb_build_object('kept', kept, 'refused', refused);
end $$;
grant execute on function public.submit_scores(jsonb) to authenticated;

drop function if exists public.chart_leaderboard(text, real, int);
create function public.chart_leaderboard(chart text, at_rate real default null,
	max_rows int default 50)
returns table (place bigint, username text, user_id uuid, wife real, rate real, ssr_overall real,
	marvelous int, perfect int, great int, good int, bad int, miss int, max_combo int,
	modifiers text, played_at timestamptz, source text, score_id bigint)
language sql stable security definer set search_path = public as $$
	with best as (
		select distinct on (s.user_id) s.*
		from public.scores s join public.profiles p on p.id = s.user_id
		where s.chart_key = chart and s.valid and s.verified and not p.banned
			and (at_rate is null or abs(s.rate - at_rate) < 0.001)
		order by s.user_id, (case when at_rate is null then s.ssr_overall else s.wife end) desc
	)
	select row_number() over (order by (case when at_rate is null then b.ssr_overall else b.wife end) desc),
		p.username, b.user_id, b.wife, b.rate, b.ssr_overall, b.marvelous, b.perfect, b.great,
		b.good, b.bad, b.miss, b.max_combo, b.modifiers, b.played_at, b.source, b.id
	from best b join public.profiles p on p.id = b.user_id
	order by 1
	limit least(greatest(max_rows, 1), 200)
$$;

create or replace function public.top_scores(player uuid, k smallint default 4, max_rows int default 25)
returns setof public.scores
language sql stable security definer set search_path = public as $$
	select * from public.scores
	where user_id = player and keys = k and valid and verified
	order by ssr_overall desc
	limit least(greatest(max_rows, 1), 100)
$$;

-- the best play (by SSR) of each day, newest day first: the launcher's "Plays of the day". Days
-- are the player's own (tz_minutes: their clock's offset from UTC); k: 4 or 7 for one key count, 0 for all.
drop function if exists public.plays_of_the_day(int);
drop function if exists public.plays_of_the_day(int, int);
drop function if exists public.plays_of_the_day(int, int, smallint);
create function public.plays_of_the_day(max_days int default 90, tz_minutes int default 0, k smallint default 0)
returns table(day date, id bigint, user_id uuid, username text, avatar int, avatar_ext text, chart_key text, keys smallint,
	rate real, wife real, ssr_overall real, song_title text, chart_name text, played_at timestamptz, source text)
language sql stable security definer set search_path = public as $$
	select distinct on (((s.played_at at time zone 'UTC') + make_interval(mins => tz_minutes))::date)
		((s.played_at at time zone 'UTC') + make_interval(mins => tz_minutes))::date as day,
		s.id, s.user_id, p.username, p.avatar, p.avatar_ext, s.chart_key, s.keys, s.rate, s.wife, s.ssr_overall,
		s.song_title, s.chart_name, s.played_at, s.source
	from public.scores s join public.profiles p on p.id = s.user_id
	where s.valid and not p.banned and s.played_at is not null and (k = 0 or s.keys = k)
	order by ((s.played_at at time zone 'UTC') + make_interval(mins => tz_minutes))::date desc, s.ssr_overall desc, s.id
	limit least(greatest(max_days, 1), 5000)
$$;
grant execute on function public.plays_of_the_day(int, int, smallint) to anon, authenticated;

-- the charts where someone took #1 from a player since a moment: the launcher's "X took #1 on Y"
create or replace function public.lost_firsts(player uuid, since timestamptz)
returns table(chart_key text, song_title text, chart_name text, keys smallint, by_name text, their_ssr real, my_ssr real)
language sql stable security definer set search_path = public as $$
	select distinct on (s.chart_key) s.chart_key, s.song_title, s.chart_name, s.keys, p.username, s.ssr_overall, m.ssr
	from public.scores s
	join public.profiles p on p.id = s.user_id
	join (select chart_key, max(ssr_overall) as ssr from public.scores where user_id = player and valid group by chart_key) m on m.chart_key = s.chart_key
	where s.valid and not p.banned and s.user_id <> player and s.submitted_at > since and s.ssr_overall > m.ssr
		and not exists (select 1 from public.scores o join public.profiles q on q.id = o.user_id
			where o.chart_key = s.chart_key and o.valid and not q.banned and o.user_id <> player and o.submitted_at <= since and o.ssr_overall > m.ssr)
	order by s.chart_key, s.ssr_overall desc
$$;
grant execute on function public.lost_firsts(uuid, timestamptz) to anon, authenticated;

-- a player's place in 4K or 7K (0 when unranked)
create or replace function public.player_place(player uuid, k smallint default 4) returns int
language sql stable security definer set search_path = public as $$
	select case when not exists (select 1 from public.player_ratings where user_id = player and keys = k and plays > 0) then 0
	else 1 + (select count(*)::int from public.player_ratings r join public.profiles p on p.id = r.user_id
		where r.keys = k and r.plays > 0 and not p.banned
			and r.overall > (select overall from public.player_ratings where user_id = player and keys = k)) end
$$;
grant execute on function public.player_place(uuid, smallint) to anon, authenticated;

-- ---------------------------------------------------------------------------------------------
-- admins

create or replace function public.vh_is_admin() returns boolean
language sql stable security definer set search_path = public as $$
	select coalesce((select is_admin from public.profiles where id = auth.uid()), false)
$$;

-- a score off the rankings (kept, marked removed), or back on
create or replace function public.admin_remove_score(score bigint, remove boolean default true) returns void
language plpgsql security definer set search_path = public as $$
declare
	u uuid;
	k smallint;
begin
	if not public.vh_is_admin() then raise exception 'admins only'; end if;
	update public.scores set valid = not remove, removed_by = case when remove then auth.uid() else null end
	where id = score returning user_id, keys into u, k;
	if u is not null then perform public.vh_refresh_rating(u, k); end if;
end $$;
grant execute on function public.admin_remove_score(bigint, boolean) to authenticated;

create or replace function public.admin_ban(player uuid, ban boolean default true) returns void
language plpgsql security definer set search_path = public as $$
begin
	if not public.vh_is_admin() then raise exception 'admins only'; end if;
	if player = auth.uid() then raise exception 'not yourself'; end if;
	update public.profiles set banned = ban where id = player;
end $$;
grant execute on function public.admin_ban(uuid, boolean) to authenticated;

-- the admin tools (the launcher's Admin page): who's who, numbers, the message of the day
create or replace function public.admin_players(q text default '', max_rows int default 50)
returns table (id uuid, username text, created_at timestamptz, banned boolean, is_admin boolean, avatar int,
	scores bigint, last_play timestamptz, rating4 real, rating7 real)
language plpgsql stable security definer set search_path = public as $$
begin
	if not public.vh_is_admin() then raise exception 'admins only'; end if;
	return query
	select p.id, p.username, p.created_at, p.banned, p.is_admin, p.avatar,
		(select count(*) from public.scores s where s.user_id = p.id and s.valid),
		(select max(s.submitted_at) from public.scores s where s.user_id = p.id),
		(select r.overall from public.player_ratings r where r.user_id = p.id and r.keys = 4),
		(select r.overall from public.player_ratings r where r.user_id = p.id and r.keys = 7)
	from public.profiles p
	where q = '' or p.username ilike '%' || q || '%'
	order by p.created_at desc
	limit least(greatest(max_rows, 1), 200);
end $$;
grant execute on function public.admin_players(text, int) to authenticated;

create or replace function public.admin_stats() returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
	if not public.vh_is_admin() then raise exception 'admins only'; end if;
	return jsonb_build_object(
		'players', (select count(*) from public.profiles),
		'banned', (select count(*) from public.profiles where banned),
		'admins', (select count(*) from public.profiles where is_admin),
		'new_players_7d', (select count(*) from public.profiles where created_at > now() - interval '7 days'),
		'scores', (select count(*) from public.scores where valid),
		'scores_removed', (select count(*) from public.scores where not valid),
		'scores_unverified', (select count(*) from public.scores where valid and not verified),
		'scores_today', (select count(*) from public.scores where submitted_at > now() - interval '1 day'),
		'scores_7d', (select count(*) from public.scores where submitted_at > now() - interval '7 days'),
		'players_7d', (select count(distinct user_id) from public.scores where submitted_at > now() - interval '7 days'),
		'charts', (select count(distinct chart_key) from public.scores where valid),
		'by_source', (select coalesce(jsonb_object_agg(source, n), '{}'::jsonb) from (select source, count(*) n from public.scores where valid group by source) x)
	);
end $$;
grant execute on function public.admin_stats() to authenticated;

create or replace function public.admin_set_admin(player uuid, make boolean default true) returns void
language plpgsql security definer set search_path = public as $$
begin
	if not public.vh_is_admin() then raise exception 'admins only'; end if;
	if player = auth.uid() then raise exception 'not yourself'; end if;
	update public.profiles set is_admin = make where id = player;
end $$;
grant execute on function public.admin_set_admin(uuid, boolean) to authenticated;

create or replace function public.admin_rename(player uuid, new_name text) returns void
language plpgsql security definer set search_path = public as $$
begin
	if not public.vh_is_admin() then raise exception 'admins only'; end if;
	if exists (select 1 from public.profiles where lower(username) = lower(btrim(new_name)) and id <> player) then
		raise exception 'that name is taken';
	end if;
	update public.profiles set username = btrim(new_name) where id = player;
end $$;
grant execute on function public.admin_rename(uuid, text) to authenticated;

-- all of a player's scores off the rankings (kept, marked), or back on
create or replace function public.admin_wipe_player(player uuid, remove boolean default true) returns int
language plpgsql security definer set search_path = public as $$
declare
	n int;
begin
	if not public.vh_is_admin() then raise exception 'admins only'; end if;
	update public.scores set valid = not remove, removed_by = case when remove then auth.uid() else null end
	where user_id = player and valid = remove;
	get diagnostics n = row_count;
	perform public.vh_refresh_rating(player, 4::smallint);
	perform public.vh_refresh_rating(player, 7::smallint);
	return n;
end $$;
grant execute on function public.admin_wipe_player(uuid, boolean) to authenticated;

-- every score on a chart off the rankings (a broken or duplicate chart), or back on
create or replace function public.admin_remove_chart(chart text, remove boolean default true) returns int
language plpgsql security definer set search_path = public as $$
declare
	n int;
	r record;
begin
	if not public.vh_is_admin() then raise exception 'admins only'; end if;
	update public.scores set valid = not remove, removed_by = case when remove then auth.uid() else null end
	where chart_key = chart and valid = remove;
	get diagnostics n = row_count;
	for r in select distinct user_id, keys from public.scores where chart_key = chart loop
		perform public.vh_refresh_rating(r.user_id, r.keys);
	end loop;
	return n;
end $$;
grant execute on function public.admin_remove_chart(text, boolean) to authenticated;

create or replace function public.admin_recalc(player uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
	if not public.vh_is_admin() then raise exception 'admins only'; end if;
	perform public.vh_refresh_rating(player, 4::smallint);
	perform public.vh_refresh_rating(player, 7::smallint);
end $$;
grant execute on function public.admin_recalc(uuid) to authenticated;

-- the message of the day: shown on the launcher's Online page (empty: none)
create or replace function public.admin_set_motd(text_ text) returns void
language plpgsql security definer set search_path = public as $$
begin
	if not public.vh_is_admin() then raise exception 'admins only'; end if;
	insert into public.vh_meta (key, value) values ('motd', coalesce(text_, ''))
	on conflict (key) do update set value = excluded.value;
end $$;
grant execute on function public.admin_set_motd(text) to authenticated;
create or replace function public.motd() returns text
language sql stable security definer set search_path = public as $$
	select coalesce((select value from public.vh_meta where key = 'motd'), '')
$$;
grant execute on function public.motd() to anon, authenticated;

-- scores worth a look: the newest unverified ones, and the newest very high accuracies
create or replace function public.admin_suspicious(max_rows int default 50)
returns table (id bigint, username text, user_id uuid, song_title text, chart_name text, keys smallint,
	rate real, wife real, ssr_overall real, verified boolean, valid boolean, has_replay boolean, submitted_at timestamptz)
language plpgsql stable security definer set search_path = public as $$
begin
	if not public.vh_is_admin() then raise exception 'admins only'; end if;
	return query
	select s.id, p.username, s.user_id, s.song_title, s.chart_name, s.keys, s.rate, s.wife, s.ssr_overall,
		s.verified, s.valid, s.has_replay, s.submitted_at
	from public.scores s join public.profiles p on p.id = s.user_id
	where (not s.verified or s.wife >= 99.7 or not s.valid)
	order by s.submitted_at desc
	limit least(greatest(max_rows, 1), 200);
end $$;
grant execute on function public.admin_suspicious(int) to authenticated;

-- ---------------------------------------------------------------------------------------------
-- profile pictures: avatars/<user id>.png in Storage (public), uploaded by the launcher at 128x128;
-- profiles.avatar counts the changes (0: none), so the picture's address changes with it
alter table public.profiles add column if not exists avatar int not null default 0;
alter table public.profiles add column if not exists avatar_ext text not null default 'png' check (avatar_ext in ('png', 'gif'));

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('avatars', 'avatars', true, 1048576, array['image/png', 'image/gif'])
on conflict (id) do update set public = true, file_size_limit = 1048576, allowed_mime_types = array['image/png', 'image/gif'];

drop policy if exists "vh avatars read" on storage.objects;
create policy "vh avatars read" on storage.objects for select using (bucket_id = 'avatars');
drop policy if exists "vh avatar insert" on storage.objects;
create policy "vh avatar insert" on storage.objects for insert to authenticated
	with check (bucket_id = 'avatars' and name in (auth.uid()::text || '.png', auth.uid()::text || '.gif'));
drop policy if exists "vh avatar update" on storage.objects;
create policy "vh avatar update" on storage.objects for update to authenticated
	using (bucket_id = 'avatars' and name in (auth.uid()::text || '.png', auth.uid()::text || '.gif'))
	with check (bucket_id = 'avatars' and name in (auth.uid()::text || '.png', auth.uid()::text || '.gif'));

drop function if exists public.set_avatar(boolean);
drop function if exists public.set_avatar(boolean, text);
create function public.set_avatar(remove boolean default false, ext text default 'png') returns int
language sql security definer set search_path = public as $$
	update public.profiles set avatar = case when remove then 0 else avatar + 1 end,
		avatar_ext = case when ext in ('png', 'gif') then ext else 'png' end
	where id = auth.uid() returning avatar
$$;
revoke all on function public.set_avatar(boolean, text) from public, anon;
grant execute on function public.set_avatar(boolean, text) to authenticated;

create or replace function public.admin_clear_avatar(player uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
	if not public.vh_is_admin() then raise exception 'admins only'; end if;
	update public.profiles set avatar = 0 where id = player;
end $$;
grant execute on function public.admin_clear_avatar(uuid) to authenticated;

-- the rankings, with each player's picture
drop function if exists public.rankings(smallint, text, int, int);
create function public.rankings(k smallint default 4, skill text default 'overall',
	max_rows int default 100, skip int default 0)
returns table (place bigint, username text, user_id uuid, rating real, overall real, stream real,
	jumpstream real, handstream real, stamina real, jackspeed real, chordjack real, technical real,
	plays int, avatar int, avatar_ext text)
language plpgsql stable security definer set search_path = public as $$
begin
	if skill not in ('overall', 'stream', 'jumpstream', 'handstream', 'stamina', 'jackspeed', 'chordjack', 'technical') then
		raise exception 'unknown skillset %', skill;
	end if;
	return query execute format(
		'select row_number() over (order by r.%1$I desc), p.username, r.user_id, r.%1$I, r.overall,
			r.stream, r.jumpstream, r.handstream, r.stamina, r.jackspeed, r.chordjack, r.technical, r.plays, p.avatar, p.avatar_ext
		from public.player_ratings r join public.profiles p on p.id = r.user_id
		where r.keys = $1 and not p.banned and r.plays > 0
		order by r.%1$I desc limit $2 offset $3', skill)
	using k, least(greatest(max_rows, 1), 200), greatest(skip, 0);
end $$;
grant execute on function public.rankings(smallint, text, int, int) to anon, authenticated;

-- pinned plays: the scores a player shows off on their profile (their own, up to 20)
create table if not exists public.pins (
	user_id uuid not null references public.profiles (id) on delete cascade,
	score_id bigint not null references public.scores (id) on delete cascade,
	pinned_at timestamptz not null default now(),
	primary key (user_id, score_id)
);
alter table public.pins enable row level security;
drop policy if exists "pins are public" on public.pins;
create policy "pins are public" on public.pins for select using (true);
revoke insert, update, delete on public.pins from anon, authenticated;

create or replace function public.pin_score(score bigint, pin boolean default true) returns void
language plpgsql security definer set search_path = public as $$
begin
	if auth.uid() is null then raise exception 'not signed in'; end if;
	if pin then
		if not exists (select 1 from public.scores where id = score and user_id = auth.uid() and valid) then
			raise exception 'not your score';
		end if;
		if (select count(*) from public.pins where user_id = auth.uid()) >= 20 then
			raise exception 'you can pin up to 20 plays';
		end if;
		insert into public.pins (user_id, score_id) values (auth.uid(), score) on conflict do nothing;
	else
		delete from public.pins where user_id = auth.uid() and score_id = score;
	end if;
end $$;
revoke all on function public.pin_score(bigint, boolean) from public, anon;
grant execute on function public.pin_score(bigint, boolean) to authenticated;

-- the order the player gave them (dragged in the launcher): ord, newest first until then
alter table public.pins add column if not exists ord int not null default 0;

create or replace function public.pinned_scores(player uuid) returns setof public.scores
language sql stable security definer set search_path = public as $$
	select s.* from public.pins p join public.scores s on s.id = p.score_id
	where p.user_id = player and s.valid
	order by p.ord, p.pinned_at desc
$$;

create or replace function public.reorder_pins(ids bigint[]) returns void
language plpgsql security definer set search_path = public as $$
begin
	if auth.uid() is null then raise exception 'not signed in'; end if;
	update public.pins p set ord = x.i
	from unnest(ids) with ordinality as x(score_id, i)
	where p.user_id = auth.uid() and p.score_id = x.score_id;
end $$;
revoke all on function public.reorder_pins(bigint[]) from public, anon;
grant execute on function public.reorder_pins(bigint[]) to authenticated;
grant execute on function public.pinned_scores(uuid) to anon, authenticated;

-- the 7K ratings already there, with the overall as the mean of six
do $$
declare r record;
begin
	for r in select distinct user_id from public.player_ratings where keys = 7 loop
		perform public.vh_refresh_rating(r.user_id, 7::smallint);
	end loop;
end $$;

-- when imported plays were really played: the launcher sends the dates it reads from the replays
-- again, for the ones sent before it read them right (own plays only, osu! / lazer / Quaver ones)
create or replace function public.fix_played_at(list jsonb) returns int
language plpgsql security definer set search_path = public as $$
declare
	uid uuid := auth.uid();
	n int;
begin
	if uid is null then raise exception 'not signed in'; end if;
	if jsonb_typeof(list) <> 'array' or jsonb_array_length(list) > 1000 then raise exception 'at most 1000 at a time'; end if;
	update public.scores s set played_at = (x->>'played_at')::timestamptz
	from jsonb_array_elements(list) as x
	where s.user_id = uid and s.score_key = x->>'score_key' and s.source in ('osu', 'lazer', 'quaver')
		and (x->>'played_at')::timestamptz is not null
		and (s.played_at is null or abs(extract(epoch from s.played_at - (x->>'played_at')::timestamptz)) > 60);
	get diagnostics n = row_count;
	return n;
end $$;
revoke all on function public.fix_played_at(jsonb) from public, anon;
grant execute on function public.fix_played_at(jsonb) to authenticated;

-- this script's version (the launcher expects it: cmd/triwheel/online.go, wantServerVersion)
insert into public.vh_meta (key, value) values ('schema_version', '14')
on conflict (key) do update set value = excluded.value;

-- To make yourself an admin, run once (with your player name):
--   update public.profiles set is_admin = true where username = 'YourName';
