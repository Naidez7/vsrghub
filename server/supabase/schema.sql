-- VSRG Hub online: accounts, scores and rankings, on Supabase.
--
-- Paste this whole file into the Supabase SQL editor (Project > SQL Editor > New query) and run it.
-- It can be run again: it only creates what isn't there yet and replaces the functions.
--
-- Accounts are Supabase Auth accounts (e-mail and password; Discord can be linked to one) with a
-- VSRG Hub profile (a unique player name). Every chart is ranked: a chart is known by Etterna's
-- chart key (a fingerprint of its notes), whatever game or pack it came from. Players are rated as
-- Etterna rates them, from their scores' SSRs (per-skillset ratings of each score), separately for
-- 4K and 7K.
--
-- Nobody writes to the tables directly: the game's client goes through the functions at the end
-- (create_profile, submit_score), which check what they're given.

-- ---------------------------------------------------------------------------------------------
-- tables

create table if not exists public.profiles (
	id uuid primary key references auth.users (id) on delete cascade,
	username text not null check (username ~ '^[A-Za-z0-9_\-\.\[\] ]{3,20}$' and username = btrim(username)),
	created_at timestamptz not null default now(),
	discord_id text,
	discord_name text,
	banned boolean not null default false
);
create unique index if not exists profiles_username_lower on public.profiles (lower(username));

create table if not exists public.scores (
	id bigint generated always as identity primary key,
	user_id uuid not null references public.profiles (id) on delete cascade,
	score_key text not null check (length(score_key) between 10 and 64),
	chart_key text not null check (chart_key ~ '^X[0-9a-f]{40}$'),
	keys smallint not null check (keys in (4, 7)),
	rate real not null check (rate between 0.05 and 3.0),
	wife real not null check (wife between -500 and 100),          -- Wife% (J4)
	ssr_overall real not null default 0 check (ssr_overall between 0 and 80),
	ssr_stream real not null default 0 check (ssr_stream between 0 and 80),
	ssr_jumpstream real not null default 0 check (ssr_jumpstream between 0 and 80),
	ssr_handstream real not null default 0 check (ssr_handstream between 0 and 80),
	ssr_stamina real not null default 0 check (ssr_stamina between 0 and 80),
	ssr_jackspeed real not null default 0 check (ssr_jackspeed between 0 and 80),
	ssr_chordjack real not null default 0 check (ssr_chordjack between 0 and 80),
	ssr_technical real not null default 0 check (ssr_technical between 0 and 80),
	msd real not null default 0 check (msd between 0 and 80),        -- the chart's MSD at this rate
	marvelous int not null default 0 check (marvelous >= 0),
	perfect int not null default 0 check (perfect >= 0),
	great int not null default 0 check (great >= 0),
	good int not null default 0 check (good >= 0),
	bad int not null default 0 check (bad >= 0),
	miss int not null default 0 check (miss >= 0),
	holds_ok int not null default 0 check (holds_ok >= 0),
	holds_ng int not null default 0 check (holds_ng >= 0),
	mines_hit int not null default 0 check (mines_hit >= 0),
	max_combo int not null default 0 check (max_combo >= 0),
	modifiers text not null default '' check (length(modifiers) <= 200),
	song_title text not null default '' check (length(song_title) <= 200),
	song_artist text not null default '' check (length(song_artist) <= 200),
	chart_name text not null default '' check (length(chart_name) <= 100),
	played_at timestamptz,
	submitted_at timestamptz not null default now(),
	has_replay boolean not null default false,
	valid boolean not null default true,
	unique (user_id, score_key)
);
create index if not exists scores_chart on public.scores (chart_key, ssr_overall desc);
create index if not exists scores_user on public.scores (user_id, keys);

create table if not exists public.player_ratings (
	user_id uuid not null references public.profiles (id) on delete cascade,
	keys smallint not null check (keys in (4, 7)),
	overall real not null default 0,
	stream real not null default 0,
	jumpstream real not null default 0,
	handstream real not null default 0,
	stamina real not null default 0,
	jackspeed real not null default 0,
	chordjack real not null default 0,
	technical real not null default 0,
	plays int not null default 0,
	updated_at timestamptz not null default now(),
	primary key (user_id, keys)
);
create index if not exists ratings_overall on public.player_ratings (keys, overall desc);

-- ---------------------------------------------------------------------------------------------
-- who can read and write what: everyone can read profiles, scores and ratings; writing goes
-- through the functions below

alter table public.profiles enable row level security;
alter table public.scores enable row level security;
alter table public.player_ratings enable row level security;

drop policy if exists "profiles are public" on public.profiles;
create policy "profiles are public" on public.profiles for select using (true);
drop policy if exists "scores are public" on public.scores;
create policy "scores are public" on public.scores for select using (valid);
drop policy if exists "ratings are public" on public.player_ratings;
create policy "ratings are public" on public.player_ratings for select using (true);

revoke insert, update, delete on public.profiles, public.scores, public.player_ratings from anon, authenticated;

-- ---------------------------------------------------------------------------------------------
-- Etterna's rating (MinaCalcHelpers.h, aggregate_skill): a rating r such that the scores' SSRs,
-- each counted as 2 / erfc(0.1 * (ssr - r)) - 2, add up to 2^(r / 10); found by a binary search,
-- then times 1.05. The player's overall is the average of the seven skillsets.

-- erfc (Numerical Recipes' erfcc, fractional error under 1.2e-7: PostgreSQL has none built in)
create or replace function public.vh_erfc(x double precision) returns double precision
language plpgsql immutable as $$
declare
	z double precision := abs(x);
	t double precision := 1.0 / (1.0 + 0.5 * z);
	r double precision;
begin
	r := t * exp(-z * z - 1.26551223 + t * (1.00002368 + t * (0.37409196 + t * (0.09678418 +
		t * (-0.18628806 + t * (0.27886807 + t * (-1.13520398 + t * (1.48851587 +
		t * (-0.82215223 + t * 0.17087277)))))))));
	if x >= 0 then return r; else return 2.0 - r; end if;
end $$;

create or replace function public.vh_aggregate(ssrs real[], delta double precision default 0.1,
	mult double precision default 1.05) returns real
language plpgsql immutable as $$
declare
	rating double precision := 0;
	res double precision := 10.24;
	s double precision;
	v real;
	i int;
	e double precision;
begin
	if ssrs is null or cardinality(ssrs) = 0 then return 0; end if;
	for i in 1..11 loop
		loop
			rating := rating + res;
			s := 0;
			foreach v in array ssrs loop
				e := public.vh_erfc(delta * (v - rating));
				if e > 0 then s := s + greatest(0, 2.0 / e - 2); else s := s + 1e300; end if;
			end loop;
			exit when not (power(2, rating * 0.1) < s);
		end loop;
		rating := rating - res;
		res := res / 2.0;
	end loop;
	rating := rating + res * 2.0;
	return least(100, greatest(0, rating * mult))::real;
end $$;

-- a player's ratings for 4K or 7K, from their best score on each chart at each rate (as Etterna
-- counts its personal bests)
create or replace function public.vh_refresh_rating(uid uuid, k smallint) returns void
language plpgsql security definer set search_path = public as $$
declare
	r public.player_ratings%rowtype;
begin
	with best as (
		select distinct on (chart_key, rate) *
		from public.scores
		where user_id = uid and keys = k and valid
		order by chart_key, rate, ssr_overall desc
	)
	select uid, k,
		0,
		public.vh_aggregate(array_agg(ssr_stream)),
		public.vh_aggregate(array_agg(ssr_jumpstream)),
		public.vh_aggregate(array_agg(ssr_handstream)),
		public.vh_aggregate(array_agg(ssr_stamina)),
		public.vh_aggregate(array_agg(ssr_jackspeed)),
		public.vh_aggregate(array_agg(ssr_chordjack)),
		public.vh_aggregate(array_agg(ssr_technical)),
		count(*), now()
	into r
	from best;
	r.overall := (r.stream + r.jumpstream + r.handstream + r.stamina + r.jackspeed + r.chordjack + r.technical) / 7.0;
	insert into public.player_ratings values (r.*)
	on conflict (user_id, keys) do update set
		overall = excluded.overall, stream = excluded.stream, jumpstream = excluded.jumpstream,
		handstream = excluded.handstream, stamina = excluded.stamina, jackspeed = excluded.jackspeed,
		chordjack = excluded.chordjack, technical = excluded.technical, plays = excluded.plays,
		updated_at = excluded.updated_at;
end $$;
revoke all on function public.vh_refresh_rating(uuid, smallint) from public, anon, authenticated;

-- ---------------------------------------------------------------------------------------------
-- what the game calls

-- the signed-in account's player name, once (the name is checked: 3 to 20 letters, digits, spaces
-- and _ - . [ ], not taken by anyone else whatever the capitals)
create or replace function public.create_profile(name text) returns public.profiles
language plpgsql security definer set search_path = public as $$
declare
	uid uuid := auth.uid();
	p public.profiles;
begin
	if uid is null then raise exception 'not signed in'; end if;
	select * into p from public.profiles where id = uid;
	if found then return p; end if;
	name := btrim(name);
	if exists (select 1 from public.profiles where lower(username) = lower(name)) then
		raise exception 'that name is taken';
	end if;
	insert into public.profiles (id, username) values (uid, name) returning * into p;
	return p;
end $$;
grant execute on function public.create_profile(text) to authenticated;

-- a score from the game; returns the player's new ratings for that key count. The same score sent
-- again (its Etterna score key) is kept once.
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
	insert into public.scores (user_id, score_key, chart_key, keys, rate, wife,
		ssr_overall, ssr_stream, ssr_jumpstream, ssr_handstream, ssr_stamina, ssr_jackspeed,
		ssr_chordjack, ssr_technical, msd, marvelous, perfect, great, good, bad, miss, holds_ok,
		holds_ng, mines_hit, max_combo, modifiers, song_title, song_artist, chart_name, played_at)
	values (uid, s->>'score_key', s->>'chart_key', k, (s->>'rate')::real, (s->>'wife')::real,
		coalesce((s->>'ssr_overall')::real, 0), coalesce((s->>'ssr_stream')::real, 0),
		coalesce((s->>'ssr_jumpstream')::real, 0), coalesce((s->>'ssr_handstream')::real, 0),
		coalesce((s->>'ssr_stamina')::real, 0), coalesce((s->>'ssr_jackspeed')::real, 0),
		coalesce((s->>'ssr_chordjack')::real, 0), coalesce((s->>'ssr_technical')::real, 0),
		coalesce((s->>'msd')::real, 0),
		coalesce((s->>'marvelous')::int, 0), coalesce((s->>'perfect')::int, 0),
		coalesce((s->>'great')::int, 0), coalesce((s->>'good')::int, 0),
		coalesce((s->>'bad')::int, 0), coalesce((s->>'miss')::int, 0),
		coalesce((s->>'holds_ok')::int, 0), coalesce((s->>'holds_ng')::int, 0),
		coalesce((s->>'mines_hit')::int, 0), coalesce((s->>'max_combo')::int, 0),
		left(coalesce(s->>'modifiers', ''), 200), left(coalesce(s->>'song_title', ''), 200),
		left(coalesce(s->>'song_artist', ''), 200), left(coalesce(s->>'chart_name', ''), 100),
		(s->>'played_at')::timestamptz)
	on conflict (user_id, score_key) do nothing;
	perform public.vh_refresh_rating(uid, k);
	select * into r from public.player_ratings where user_id = uid and keys = k;
	return r;
end $$;
grant execute on function public.submit_score(jsonb) to authenticated;

-- a chart's leaderboard: each player's best score on it (all rates, or one rate), best first
create or replace function public.chart_leaderboard(chart text, at_rate real default null,
	max_rows int default 50)
returns table (place bigint, username text, user_id uuid, wife real, rate real, ssr_overall real,
	marvelous int, perfect int, great int, good int, bad int, miss int, max_combo int,
	modifiers text, played_at timestamptz)
language sql stable security definer set search_path = public as $$
	with best as (
		select distinct on (s.user_id) s.*
		from public.scores s join public.profiles p on p.id = s.user_id
		where s.chart_key = chart and s.valid and not p.banned
			and (at_rate is null or abs(s.rate - at_rate) < 0.001)
		order by s.user_id, (case when at_rate is null then s.ssr_overall else s.wife end) desc
	)
	select row_number() over (order by (case when at_rate is null then b.ssr_overall else b.wife end) desc),
		p.username, b.user_id, b.wife, b.rate, b.ssr_overall, b.marvelous, b.perfect, b.great,
		b.good, b.bad, b.miss, b.max_combo, b.modifiers, b.played_at
	from best b join public.profiles p on p.id = b.user_id
	order by 1
	limit least(greatest(max_rows, 1), 200)
$$;
grant execute on function public.chart_leaderboard(text, real, int) to anon, authenticated;

-- the rankings: players by their overall rating or one skillset's, for 4K or 7K
create or replace function public.rankings(k smallint default 4, skill text default 'overall',
	max_rows int default 100, skip int default 0)
returns table (place bigint, username text, user_id uuid, rating real, overall real, stream real,
	jumpstream real, handstream real, stamina real, jackspeed real, chordjack real, technical real,
	plays int)
language plpgsql stable security definer set search_path = public as $$
begin
	if skill not in ('overall', 'stream', 'jumpstream', 'handstream', 'stamina', 'jackspeed', 'chordjack', 'technical') then
		raise exception 'unknown skillset %', skill;
	end if;
	return query execute format(
		'select row_number() over (order by r.%1$I desc), p.username, r.user_id, r.%1$I, r.overall,
			r.stream, r.jumpstream, r.handstream, r.stamina, r.jackspeed, r.chordjack, r.technical, r.plays
		from public.player_ratings r join public.profiles p on p.id = r.user_id
		where r.keys = $1 and not p.banned and r.plays > 0
		order by r.%1$I desc limit $2 offset $3', skill)
	using k, least(greatest(max_rows, 1), 200), greatest(skip, 0);
end $$;
grant execute on function public.rankings(smallint, text, int, int) to anon, authenticated;

-- a player's best scores (their top plays by SSR), for profiles
create or replace function public.top_scores(player uuid, k smallint default 4, max_rows int default 25)
returns setof public.scores
language sql stable security definer set search_path = public as $$
	select * from public.scores
	where user_id = player and keys = k and valid
	order by ssr_overall desc
	limit least(greatest(max_rows, 1), 100)
$$;
grant execute on function public.top_scores(uuid, smallint, int) to anon, authenticated;
