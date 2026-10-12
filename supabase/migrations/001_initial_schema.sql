-- CLUBHOUSE initial schema. Review and apply only to a test Supabase project first.
create extension if not exists pgcrypto;
do $$ begin create type public.card_rarity as enum ('Bronze','Silber','Gold','Ultimate','Legendär'); exception when duplicate_object then null; end $$;
do $$ begin create type public.club_role as enum ('player','trainer','admin','spectator'); exception when duplicate_object then null; end $$;

create table if not exists public.profiles(
 id uuid primary key references auth.users(id) on delete cascade,
 username text unique,
 display_name text not null default 'Spieler',
 avatar_path text,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now()
);
create table if not exists public.user_roles(
 user_id uuid not null references auth.users(id) on delete cascade,
 role public.club_role not null default 'player',
 granted_by uuid references auth.users(id),
 granted_at timestamptz not null default now(),
 primary key(user_id,role)
);
create or replace function public.has_role(required_role text) returns boolean
 language sql stable security definer set search_path=public
 as $$ select exists(select 1 from public.user_roles where user_id=auth.uid() and role::text=required_role) $$;
revoke all on function public.has_role(text) from public;
grant execute on function public.has_role(text) to authenticated;

create table if not exists public.seasons(id uuid primary key default gen_random_uuid(),name text not null,start_date date,end_date date,is_active boolean not null default false);
create table if not exists public.teams(id uuid primary key default gen_random_uuid(),name text not null,format jsonb not null default '{"field_players":4,"goalkeepers":1,"substitutes":2}'::jsonb);
create table if not exists public.players(id uuid primary key default gen_random_uuid(),display_name text not null,shirt_number integer,position text,secondary_positions text[] not null default '{}',image_path text,is_active boolean not null default true,created_at timestamptz not null default now());
create table if not exists public.player_seasons(id uuid primary key default gen_random_uuid(),player_id uuid not null references public.players(id) on delete cascade,season_id uuid not null references public.seasons(id) on delete cascade,appearances integer not null default 0 check(appearances>=0),goals integer not null default 0 check(goals>=0),assists integer not null default 0 check(assists>=0),yellow_cards integer not null default 0 check(yellow_cards>=0),red_cards integer not null default 0 check(red_cards>=0),unique(player_id,season_id));
create table if not exists public.competitions(id uuid primary key default gen_random_uuid(),name text not null,season_id uuid references public.seasons(id) on delete set null,kind text not null default 'league');
create table if not exists public.matches(id uuid primary key default gen_random_uuid(),competition_id uuid references public.competitions(id) on delete set null,season_id uuid references public.seasons(id) on delete set null,opponent text not null,venue text,date_time timestamptz,status text not null default 'scheduled' check(status in('scheduled','live','completed','cancelled')),home_score integer check(home_score>=0),away_score integer check(away_score>=0),report text,created_at timestamptz not null default now());
create table if not exists public.match_events(id uuid primary key default gen_random_uuid(),match_id uuid not null references public.matches(id) on delete cascade,player_id uuid references public.players(id) on delete set null,minute integer check(minute between 0 and 150),event_type text not null,details jsonb not null default '{}');
create table if not exists public.lineups(id uuid primary key default gen_random_uuid(),match_id uuid not null references public.matches(id) on delete cascade,player_id uuid not null references public.players(id) on delete cascade,slot text not null,is_starting boolean not null default true,unique(match_id,player_id));
create table if not exists public.transfers(id uuid primary key default gen_random_uuid(),player_id uuid references public.players(id) on delete set null,kind text not null,from_team text,to_team text,announced_at timestamptz not null default now(),details text);
create table if not exists public.news(id uuid primary key default gen_random_uuid(),author_id uuid references auth.users(id) on delete set null,title text not null,body text not null,image_path text,category text not null default 'Verein',is_published boolean not null default false,pinned boolean not null default false,published_at timestamptz,created_at timestamptz not null default now());
create table if not exists public.calendar_events(id uuid primary key default gen_random_uuid(),title text not null,details text,starts_at timestamptz not null,ends_at timestamptz,kind text not null default 'training',created_by uuid references auth.users(id) on delete set null);
create table if not exists public.attendance_responses(event_id uuid not null references public.calendar_events(id) on delete cascade,user_id uuid not null references auth.users(id) on delete cascade,response text not null check(response in('yes','no','maybe')),updated_at timestamptz not null default now(),primary key(event_id,user_id));
create table if not exists public.polls(id uuid primary key default gen_random_uuid(),question text not null,options jsonb not null,ends_at timestamptz,created_by uuid references auth.users(id) on delete set null);
create table if not exists public.poll_votes(poll_id uuid not null references public.polls(id) on delete cascade,user_id uuid not null references auth.users(id) on delete cascade,option_index integer not null,created_at timestamptz not null default now(),primary key(poll_id,user_id));
create table if not exists public.notifications(id uuid primary key default gen_random_uuid(),user_id uuid not null references auth.users(id) on delete cascade,title text not null,body text not null,read_at timestamptz,created_at timestamptz not null default now());
create table if not exists public.audit_logs(id uuid primary key default gen_random_uuid(),actor_id uuid references auth.users(id) on delete set null,action text not null,target_type text,target_id text,reason text,details jsonb not null default '{}',created_at timestamptz not null default now());

create table if not exists public.card_definitions(
 id uuid primary key default gen_random_uuid(),display_name text not null,position text not null,overall integer not null check(overall between 45 and 99),rarity public.card_rarity not null,pace integer not null default 50 check(pace between 1 and 99),shooting integer not null default 50 check(shooting between 1 and 99),passing integer not null default 50 check(passing between 1 and 99),dribbling integer not null default 50 check(dribbling between 1 and 99),defense integer not null default 50 check(defense between 1 and 99),physical integer not null default 50 check(physical between 1 and 99),edition text not null default 'SVHS · Saison',season_id uuid references public.seasons(id) on delete set null,image_path text,is_available boolean not null default true,created_at timestamptz not null default now()
);
create table if not exists public.pack_definitions(
 id uuid primary key default gen_random_uuid(),name text not null unique,price integer not null check(price>=0),card_count integer not null check(card_count between 1 and 20),rarity_weights jsonb not null,guaranteed_rarity public.card_rarity,guaranteed_count integer not null default 0 check(guaranteed_count>=0),is_active boolean not null default false,available_from timestamptz,available_until timestamptz,created_at timestamptz not null default now()
);
create table if not exists public.pack_probability_versions(
 id uuid primary key default gen_random_uuid(),pack_id uuid not null references public.pack_definitions(id) on delete cascade,version integer not null,rarity_weights jsonb not null,created_at timestamptz not null default now(),unique(pack_id,version)
);
create table if not exists public.club_point_balances(user_id uuid primary key references auth.users(id) on delete cascade,balance bigint not null default 0 check(balance>=0),updated_at timestamptz not null default now());
create table if not exists public.club_point_transactions(
 id uuid primary key default gen_random_uuid(),user_id uuid not null references auth.users(id) on delete cascade,delta bigint not null check(delta<>0),reason text not null,reference_id uuid,idempotency_key uuid not null,created_at timestamptz not null default now(),unique(user_id,idempotency_key)
);
create table if not exists public.card_inventory(
 id uuid primary key default gen_random_uuid(),user_id uuid not null references auth.users(id) on delete cascade,card_definition_id uuid not null references public.card_definitions(id),upgrade_level integer not null default 0 check(upgrade_level between 0 and 3),locked boolean not null default false,obtained_at timestamptz not null default now()
);
create table if not exists public.pack_openings(
 id uuid primary key default gen_random_uuid(),user_id uuid not null references auth.users(id) on delete cascade,pack_id uuid not null references public.pack_definitions(id),probability_version_id uuid references public.pack_probability_versions(id),cost integer not null check(cost>=0),idempotency_key uuid not null,created_at timestamptz not null default now(),unique(user_id,idempotency_key)
);
create table if not exists public.card_upgrade_history(id uuid primary key default gen_random_uuid(),user_id uuid not null references auth.users(id) on delete cascade,source_inventory_id uuid not null references public.card_inventory(id),consumed_inventory_ids uuid[] not null,from_level integer not null,to_level integer not null,created_at timestamptz not null default now());
create table if not exists public.card_album_definitions(id uuid primary key default gen_random_uuid(),name text not null,season_id uuid references public.seasons(id) on delete set null,is_active boolean not null default true);
create table if not exists public.album_slots(id uuid primary key default gen_random_uuid(),album_id uuid not null references public.card_album_definitions(id) on delete cascade,card_definition_id uuid not null references public.card_definitions(id) on delete cascade,slot_number integer not null,unique(album_id,slot_number),unique(album_id,card_definition_id));
create table if not exists public.user_album_progress(user_id uuid not null references auth.users(id) on delete cascade,album_id uuid not null references public.card_album_definitions(id) on delete cascade,completed_at timestamptz,reward_claimed_at timestamptz,primary key(user_id,album_id));
create table if not exists public.reward_definitions(id uuid primary key default gen_random_uuid(),name text not null,points integer not null default 0 check(points>=0),kind text not null,criteria jsonb not null default '{}',is_active boolean not null default true);
create table if not exists public.reward_claims(id uuid primary key default gen_random_uuid(),user_id uuid not null references auth.users(id) on delete cascade,reward_id uuid not null references public.reward_definitions(id),idempotency_key uuid not null,claimed_at timestamptz not null default now(),unique(user_id,reward_id),unique(user_id,idempotency_key));
create table if not exists public.objectives(id uuid primary key default gen_random_uuid(),title text not null,description text not null,period text not null default 'daily',points_reward integer not null default 0 check(points_reward>=0),starts_at timestamptz,ends_at timestamptz,is_active boolean not null default true);
create table if not exists public.objective_progress(user_id uuid not null references auth.users(id) on delete cascade,objective_id uuid not null references public.objectives(id) on delete cascade,progress integer not null default 0 check(progress>=0),completed_at timestamptz,claimed_at timestamptz,primary key(user_id,objective_id));
create table if not exists public.ultimate_squads(id uuid primary key default gen_random_uuid(),user_id uuid not null references auth.users(id) on delete cascade,name text not null default 'Mein Team',formation text not null default '4+1',created_at timestamptz not null default now(),updated_at timestamptz not null default now());
create table if not exists public.squad_slots(id uuid primary key default gen_random_uuid(),squad_id uuid not null references public.ultimate_squads(id) on delete cascade,inventory_id uuid not null references public.card_inventory(id) on delete cascade,slot_number integer not null,position text not null,unique(squad_id,slot_number),unique(squad_id,inventory_id));
create table if not exists public.ai_opponents(id uuid primary key default gen_random_uuid(),name text not null,formation text not null default '4+1',overall integer not null check(overall between 45 and 99),style text not null default 'balanced',difficulty text not null default 'normal',roster jsonb not null default '[]',is_active boolean not null default true);
create table if not exists public.simulated_matches(id uuid primary key default gen_random_uuid(),user_id uuid not null references auth.users(id) on delete cascade,opponent_id uuid references public.ai_opponents(id) on delete set null,home_score integer,away_score integer,status text not null default 'completed',seed bigint,points_awarded integer not null default 0 check(points_awarded>=0),created_at timestamptz not null default now());
create table if not exists public.simulated_match_events(id uuid primary key default gen_random_uuid(),match_id uuid not null references public.simulated_matches(id) on delete cascade,minute integer not null check(minute between 0 and 100),event_type text not null,details jsonb not null default '{}');
create table if not exists public.trade_offers(id uuid primary key default gen_random_uuid(),sender_id uuid not null references auth.users(id) on delete cascade,receiver_id uuid not null references auth.users(id) on delete cascade,status text not null default 'pending' check(status in('pending','accepted','rejected','withdrawn','completed')),created_at timestamptz not null default now(),expires_at timestamptz,check(sender_id<>receiver_id));
create table if not exists public.trade_offer_items(id uuid primary key default gen_random_uuid(),offer_id uuid not null references public.trade_offers(id) on delete cascade,inventory_id uuid not null references public.card_inventory(id) on delete cascade,owner_id uuid not null references auth.users(id) on delete cascade,unique(offer_id,inventory_id));
create table if not exists public.completed_trades(id uuid primary key default gen_random_uuid(),offer_id uuid not null unique references public.trade_offers(id),completed_at timestamptz not null default now());
create table if not exists public.push_subscriptions(id uuid primary key default gen_random_uuid(),user_id uuid not null references auth.users(id) on delete cascade,endpoint text not null,p256dh text not null,auth_secret text not null,created_at timestamptz not null default now(),unique(user_id,endpoint));

create index if not exists idx_players_active on public.players(is_active);
create index if not exists idx_matches_date on public.matches(date_time);
create index if not exists idx_news_published on public.news(is_published,published_at desc);
create index if not exists idx_card_inventory_user on public.card_inventory(user_id);
create index if not exists idx_pack_openings_user on public.pack_openings(user_id,created_at desc);
create index if not exists idx_cp_transactions_user on public.club_point_transactions(user_id,created_at desc);
create index if not exists idx_sim_matches_user on public.simulated_matches(user_id,created_at desc);

-- Every newly registered account receives the player role, never admin.
create or replace function public.handle_new_user() returns trigger language plpgsql security definer set search_path=public as $$
begin
 insert into public.profiles(id,display_name) values(new.id,coalesce(nullif(new.raw_user_meta_data->>'display_name',''),split_part(coalesce(new.email,'Spieler'),'@',1)));
 insert into public.user_roles(user_id,role) values(new.id,'player') on conflict do nothing;
 insert into public.club_point_balances(user_id,balance) values(new.id,1250) on conflict do nothing;
 insert into public.club_point_transactions(user_id,delta,reason,idempotency_key) values(new.id,1250,'welcome_bonus',gen_random_uuid());
 return new;
end $$;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users for each row execute procedure public.handle_new_user();

-- Default deny; read/write policies are explicit per table.
do $$ declare t text; begin
 foreach t in array array['profiles','user_roles','seasons','teams','players','player_seasons','competitions','matches','match_events','lineups','transfers','news','calendar_events','attendance_responses','polls','poll_votes','notifications','audit_logs','card_definitions','pack_definitions','pack_probability_versions','club_point_balances','club_point_transactions','card_inventory','pack_openings','card_upgrade_history','card_album_definitions','album_slots','user_album_progress','reward_definitions','reward_claims','objectives','objective_progress','ultimate_squads','squad_slots','ai_opponents','simulated_matches','simulated_match_events','trade_offers','trade_offer_items','completed_trades','push_subscriptions'] loop
 execute format('alter table public.%I enable row level security',t);
 end loop;
end $$;
create policy "profiles read authenticated" on public.profiles for select to authenticated using(true);
create policy "profile owner update" on public.profiles for update to authenticated using(id=auth.uid()) with check(id=auth.uid());
create policy "roles own or admin read" on public.user_roles for select to authenticated using(user_id=auth.uid() or public.has_role('admin'));
create policy "public player roster read" on public.players for select to authenticated using(true);
create policy "public card catalog read" on public.card_definitions for select to authenticated using(is_available or public.has_role('admin'));
create policy "active packs read" on public.pack_definitions for select to authenticated using(is_active or public.has_role('admin'));
create policy "probability versions read" on public.pack_probability_versions for select to authenticated using(exists(select 1 from public.pack_definitions p where p.id=pack_id and (p.is_active or public.has_role('admin'))));
create policy "own balance read" on public.club_point_balances for select to authenticated using(user_id=auth.uid() or public.has_role('admin'));
create policy "own transactions read" on public.club_point_transactions for select to authenticated using(user_id=auth.uid() or public.has_role('admin'));
create policy "own inventory read" on public.card_inventory for select to authenticated using(user_id=auth.uid() or public.has_role('admin'));
create policy "own openings read" on public.pack_openings for select to authenticated using(user_id=auth.uid() or public.has_role('admin'));
create policy "published news read" on public.news for select to authenticated using(is_published or public.has_role('admin') or public.has_role('trainer'));
create policy "calendar read authenticated" on public.calendar_events for select to authenticated using(auth.uid() is not null);
create policy "own attendance read" on public.attendance_responses for select to authenticated using(user_id=auth.uid() or public.has_role('admin') or public.has_role('trainer'));
create policy "own attendance insert" on public.attendance_responses for insert to authenticated with check(user_id=auth.uid());
create policy "own attendance update" on public.attendance_responses for update to authenticated using(user_id=auth.uid()) with check(user_id=auth.uid());
create policy "own notifications read" on public.notifications for select to authenticated using(user_id=auth.uid());
create policy "own notifications update" on public.notifications for update to authenticated using(user_id=auth.uid()) with check(user_id=auth.uid());
create policy "own squad read" on public.ultimate_squads for select to authenticated using(user_id=auth.uid());
create policy "own squad create" on public.ultimate_squads for insert to authenticated with check(user_id=auth.uid());
create policy "own squad update" on public.ultimate_squads for update to authenticated using(user_id=auth.uid()) with check(user_id=auth.uid());
create policy "own squad slots read" on public.squad_slots for select to authenticated using(exists(select 1 from public.ultimate_squads s where s.id=squad_id and s.user_id=auth.uid()));
create policy "own squad slots create" on public.squad_slots for insert to authenticated with check(exists(select 1 from public.ultimate_squads s where s.id=squad_id and s.user_id=auth.uid()) and exists(select 1 from public.card_inventory i where i.id=inventory_id and i.user_id=auth.uid()));
create policy "own squad slots delete" on public.squad_slots for delete to authenticated using(exists(select 1 from public.ultimate_squads s where s.id=squad_id and s.user_id=auth.uid()));
create policy "ai opponents read" on public.ai_opponents for select to authenticated using(is_active or public.has_role('admin'));
create policy "own simulated matches read" on public.simulated_matches for select to authenticated using(user_id=auth.uid() or public.has_role('admin'));
create policy "own simulated events read" on public.simulated_match_events for select to authenticated using(exists(select 1 from public.simulated_matches m where m.id=match_id and m.user_id=auth.uid()));
create policy "album catalog read" on public.card_album_definitions for select to authenticated using(is_active or public.has_role('admin'));
create policy "album slots read" on public.album_slots for select to authenticated using(exists(select 1 from public.card_album_definitions a where a.id=album_id and (a.is_active or public.has_role('admin'))));
create policy "own album progress read" on public.user_album_progress for select to authenticated using(user_id=auth.uid());
create policy "objectives read" on public.objectives for select to authenticated using(is_active or public.has_role('admin'));
create policy "own objective progress read" on public.objective_progress for select to authenticated using(user_id=auth.uid());
create policy "rewards read" on public.reward_definitions for select to authenticated using(is_active or public.has_role('admin'));
create policy "own reward claims read" on public.reward_claims for select to authenticated using(user_id=auth.uid());
create policy "own trades read" on public.trade_offers for select to authenticated using(sender_id=auth.uid() or receiver_id=auth.uid());
create policy "own trade items read" on public.trade_offer_items for select to authenticated using(owner_id=auth.uid() or exists(select 1 from public.trade_offers o where o.id=offer_id and (o.sender_id=auth.uid() or o.receiver_id=auth.uid())));
-- No direct client writes for balances, inventory, pack results, upgrades, completed trades or audit logs.
