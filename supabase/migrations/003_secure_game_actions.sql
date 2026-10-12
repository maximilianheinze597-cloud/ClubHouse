-- Secure game actions: server-verified AI match rewards, card upgrades and card-only trades.
alter table public.simulated_matches add column if not exists idempotency_key uuid;
create unique index if not exists simulated_matches_user_idempotency on public.simulated_matches(user_id,idempotency_key) where idempotency_key is not null;
alter table public.card_upgrade_history add column if not exists idempotency_key uuid;
create unique index if not exists card_upgrade_history_user_idempotency on public.card_upgrade_history(user_id,idempotency_key) where idempotency_key is not null;
alter table public.trade_offer_items add column if not exists side text not null default 'give';
alter table public.trade_offer_items alter column inventory_id drop not null;
alter table public.trade_offer_items add column if not exists card_definition_id uuid references public.card_definitions(id);
do $$ begin alter table public.trade_offer_items add constraint trade_item_side_check check(side in('give','want')); exception when duplicate_object then null; end $$;
alter table public.trade_offers add column if not exists idempotency_key uuid;
create unique index if not exists trade_offers_sender_idempotency on public.trade_offers(sender_id,idempotency_key) where idempotency_key is not null;

create or replace function public.simulate_ai_match(p_opponent_id uuid,p_idempotency_key uuid)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare uid uuid:=auth.uid(); prior public.simulated_matches%rowtype; opp public.ai_opponents%rowtype; team_rating integer; home_goals integer; away_goals integer; reward integer; match_id uuid; bal bigint; minute_value integer; i integer; event_list jsonb:='[]'::jsonb;
begin
 if uid is null then raise exception 'authentication_required'; end if;
 if p_idempotency_key is null then raise exception 'idempotency_key_required'; end if;
 perform pg_advisory_xact_lock(hashtextextended(uid::text||':match:'||p_idempotency_key::text,0));
 select * into prior from public.simulated_matches where user_id=uid and idempotency_key=p_idempotency_key;
 if found then return jsonb_build_object('match_id',prior.id,'home_score',prior.home_score,'away_score',prior.away_score,'points_awarded',prior.points_awarded,'replayed',true); end if;
 select * into opp from public.ai_opponents where id=p_opponent_id and is_active=true;
 if not found then select * into opp from public.ai_opponents where is_active=true order by overall limit 1; end if;
 if not found then raise exception 'no_active_ai_opponent'; end if;
 if (select count(*) from public.simulated_matches where user_id=uid and created_at>now()-interval '24 hours')>=20 then raise exception 'daily_match_limit_reached'; end if;
 select coalesce(round(avg(d.overall+i.upgrade_level)),55)::integer into team_rating from public.card_inventory i join public.card_definitions d on d.id=i.card_definition_id where i.user_id=uid and not i.locked;
 home_goals:=greatest(0,least(6,round(1.25+(team_rating-opp.overall)::numeric/17+random()*2.5)::integer));
 away_goals:=greatest(0,least(6,round(1.2+(opp.overall-team_rating)::numeric/19+random()*2.5)::integer));
 reward:=case when home_goals>away_goals then 180 when home_goals=away_goals then 100 else 70 end;
 insert into public.simulated_matches(user_id,opponent_id,home_score,away_score,status,points_awarded,idempotency_key)
 values(uid,opp.id,home_goals,away_goals,'completed',reward,p_idempotency_key) returning id into match_id;
 for i in 1..(home_goals+away_goals) loop
   minute_value:=1+floor(random()*89)::integer;
   insert into public.simulated_match_events(match_id,minute,event_type,details)
   values(match_id,minute_value,'goal',jsonb_build_object('team',case when i<=home_goals then 'user' else 'opponent' end,'note','Server-simulated goal'));
 end loop;
 insert into public.simulated_match_events(match_id,minute,event_type,details) values(match_id,45,'halftime','{}'),(match_id,90,'fulltime',jsonb_build_object('score',home_goals||':'||away_goals));
 insert into public.club_point_balances(user_id,balance) values(uid,1250) on conflict(user_id) do nothing;
 update public.club_point_balances set balance=balance+reward,updated_at=now() where user_id=uid returning balance into bal;
 insert into public.club_point_transactions(user_id,delta,reason,reference_id,idempotency_key)
 values(uid,reward,'ai_match_reward',match_id,p_idempotency_key);
 return jsonb_build_object('match_id',match_id,'opponent',opp.name,'team_rating',team_rating,'opponent_rating',opp.overall,'home_score',home_goals,'away_score',away_goals,'points_awarded',reward,'balance',bal,'replayed',false);
end $$;
revoke all on function public.simulate_ai_match(uuid,uuid) from public,anon;
grant execute on function public.simulate_ai_match(uuid,uuid) to authenticated;

create or replace function public.upgrade_card(p_inventory_id uuid,p_duplicate_inventory_id uuid,p_idempotency_key uuid)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare uid uuid:=auth.uid(); src public.card_inventory%rowtype; dup public.card_inventory%rowtype; old_level integer; new_level integer; hist public.card_upgrade_history%rowtype;
begin
 if uid is null then raise exception 'authentication_required'; end if;
 if p_inventory_id is null or p_duplicate_inventory_id is null or p_idempotency_key is null then raise exception 'upgrade_parameters_required'; end if;
 perform pg_advisory_xact_lock(hashtextextended(uid::text||':upgrade:'||p_idempotency_key::text,0));
 select * into hist from public.card_upgrade_history where user_id=uid and idempotency_key=p_idempotency_key;
 if found then return jsonb_build_object('source_inventory_id',hist.source_inventory_id,'level',hist.to_level,'replayed',true); end if;
 select * into src from public.card_inventory where id=p_inventory_id and user_id=uid and not locked for update;
 if not found then raise exception 'source_card_not_owned_or_locked'; end if;
 select * into dup from public.card_inventory where id=p_duplicate_inventory_id and user_id=uid and not locked for update;
 if not found then raise exception 'duplicate_card_not_owned_or_locked'; end if;
 if src.id=dup.id or src.card_definition_id<>dup.card_definition_id then raise exception 'duplicate_must_match_card_edition'; end if;
 if exists(select 1 from public.trade_offer_items ti join public.trade_offers t on t.id=ti.offer_id where ti.inventory_id in(src.id,dup.id) and t.status='pending') then raise exception 'card_reserved_for_trade'; end if;
 if src.upgrade_level>=3 then raise exception 'maximum_upgrade_reached'; end if;
 old_level:=src.upgrade_level;new_level:=old_level+1;
 delete from public.card_inventory where id=dup.id;
 update public.card_inventory set upgrade_level=new_level where id=src.id;
 insert into public.card_upgrade_history(user_id,source_inventory_id,consumed_inventory_ids,from_level,to_level,idempotency_key)
 values(uid,src.id,array[dup.id],old_level,new_level,p_idempotency_key);
 insert into public.audit_logs(actor_id,action,target_type,target_id,reason,details)
 values(uid,'card_upgrade','card_inventory',src.id::text,'Duplicate card consumed',jsonb_build_object('from_level',old_level,'to_level',new_level,'consumed_inventory_id',dup.id));
 return jsonb_build_object('source_inventory_id',src.id,'level',new_level,'replayed',false);
end $$;
revoke all on function public.upgrade_card(uuid,uuid,uuid) from public,anon;
grant execute on function public.upgrade_card(uuid,uuid,uuid) to authenticated;
create policy "own upgrade history read" on public.card_upgrade_history for select to authenticated using(user_id=auth.uid() or public.has_role('admin'));

create or replace function public.create_trade_offer(p_receiver_id uuid,p_give_inventory_ids uuid[],p_want_card_definition_ids uuid[],p_idempotency_key uuid)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare uid uuid:=auth.uid(); offer_id uuid; card_id uuid; def_id uuid;
begin
 if uid is null then raise exception 'authentication_required'; end if;
 if p_receiver_id is null or p_receiver_id=uid or p_idempotency_key is null then raise exception 'invalid_trade_request'; end if;
 if coalesce(cardinality(p_give_inventory_ids),0)<1 or coalesce(cardinality(p_want_card_definition_ids),0)<1 then raise exception 'trade_requires_cards_on_both_sides'; end if;
 if cardinality(p_give_inventory_ids)>5 or cardinality(p_want_card_definition_ids)>5 then raise exception 'trade_card_limit_exceeded'; end if;
 perform pg_advisory_xact_lock(hashtextextended(uid::text||':trade:'||p_idempotency_key::text,0));
 select id into offer_id from public.trade_offers where sender_id=uid and idempotency_key=p_idempotency_key;
 if offer_id is not null then return jsonb_build_object('offer_id',offer_id,'replayed',true); end if;
 if exists(select 1 from unnest(p_give_inventory_ids) x group by x having count(*)>1) or exists(select 1 from unnest(p_want_card_definition_ids) x group by x having count(*)>1) then raise exception 'duplicate_card_id_in_trade'; end if;
 perform 1 from public.card_inventory where id=any(p_give_inventory_ids) for update;
 if exists(select 1 from unnest(p_give_inventory_ids) x left join public.card_inventory i on i.id=x and i.user_id=uid and not i.locked where i.id is null) then raise exception 'offered_card_not_owned'; end if;
 if exists(select 1 from unnest(p_want_card_definition_ids) x left join public.card_definitions d on d.id=x and d.is_available where d.id is null) then raise exception 'requested_card_definition_unavailable'; end if;
 if exists(select 1 from public.trade_offer_items ti join public.trade_offers t on t.id=ti.offer_id where ti.inventory_id=any(p_give_inventory_ids) and t.status='pending') then raise exception 'card_already_reserved'; end if;
 insert into public.trade_offers(sender_id,receiver_id,status,idempotency_key) values(uid,p_receiver_id,'pending',p_idempotency_key) returning id into offer_id;
 foreach card_id in array p_give_inventory_ids loop
   select card_definition_id into def_id from public.card_inventory where id=card_id and user_id=uid;
   insert into public.trade_offer_items(offer_id,inventory_id,owner_id,side,card_definition_id) values(offer_id,card_id,uid,'give',def_id);
 end loop;
 foreach def_id in array p_want_card_definition_ids loop
   insert into public.trade_offer_items(offer_id,inventory_id,owner_id,side,card_definition_id) values(offer_id,null,p_receiver_id,'want',def_id);
 end loop;
 insert into public.notifications(user_id,title,body) values(p_receiver_id,'Neue Tauschanfrage','Du hast eine neue Karten-Tauschanfrage erhalten.');
 return jsonb_build_object('offer_id',offer_id,'replayed',false);
end $$;
revoke all on function public.create_trade_offer(uuid,uuid[],uuid[],uuid) from public,anon;
grant execute on function public.create_trade_offer(uuid,uuid[],uuid[],uuid) to authenticated;

create or replace function public.accept_trade(p_offer_id uuid,p_idempotency_key uuid)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare uid uuid:=auth.uid(); offer public.trade_offers%rowtype; existing public.completed_trades%rowtype; card_row record; selected_inventory uuid; moved integer:=0;
begin
 if uid is null then raise exception 'authentication_required'; end if;
 if p_offer_id is null or p_idempotency_key is null then raise exception 'trade_parameters_required'; end if;
 perform pg_advisory_xact_lock(hashtextextended(uid::text||':accept:'||p_offer_id::text,0));
 select * into offer from public.trade_offers where id=p_offer_id for update;
 if not found then raise exception 'trade_not_found'; end if;
 select * into existing from public.completed_trades where offer_id=p_offer_id;
 if found then return jsonb_build_object('offer_id',p_offer_id,'status','completed','replayed',true); end if;
 if offer.receiver_id<>uid then raise exception 'only_receiver_can_accept'; end if;
 if offer.status<>'pending' then raise exception 'trade_not_pending'; end if;
 perform 1 from public.card_inventory where id in(select inventory_id from public.trade_offer_items where offer_id=offer.id and side='give') for update;
 if exists(select 1 from public.trade_offer_items ti left join public.card_inventory i on i.id=ti.inventory_id where ti.offer_id=offer.id and ti.side='give' and (i.id is null or i.user_id<>ti.owner_id or i.locked)) then raise exception 'trade_card_ownership_changed'; end if;
 if exists(select 1 from public.trade_offer_items ti join public.trade_offer_items other on other.inventory_id=ti.inventory_id and other.offer_id<>ti.offer_id join public.trade_offers ot on ot.id=other.offer_id and ot.status='pending' where ti.offer_id=offer.id and ti.side='give') then raise exception 'trade_card_reserved_elsewhere'; end if;
 -- Resolve each requested definition to an actual card owned by the receiver.
 for card_row in select id,card_definition_id from public.trade_offer_items where offer_id=offer.id and side='want' for update loop
   select i.id into selected_inventory from public.card_inventory i
   where i.user_id=uid and i.card_definition_id=card_row.card_definition_id and not i.locked
     and not exists(select 1 from public.trade_offer_items other join public.trade_offers ot on ot.id=other.offer_id where other.inventory_id=i.id and ot.status='pending' and other.offer_id<>offer.id)
   order by i.obtained_at limit 1 for update;
   if selected_inventory is null then raise exception 'requested_card_not_available'; end if;
   update public.trade_offer_items set inventory_id=selected_inventory where id=card_row.id;
   selected_inventory:=null;
 end loop;
 if exists(select 1 from public.trade_offer_items ti left join public.card_inventory i on i.id=ti.inventory_id where ti.offer_id=offer.id and (i.id is null or i.user_id<>ti.owner_id or i.locked)) then raise exception 'trade_card_ownership_changed'; end if;
 for card_row in select inventory_id,owner_id,side from public.trade_offer_items where offer_id=offer.id for update loop
   update public.card_inventory set user_id=case when card_row.side='give' then offer.receiver_id else offer.sender_id end where id=card_row.inventory_id and user_id=card_row.owner_id;
   if not found then raise exception 'trade_card_transfer_failed'; end if;
   moved:=moved+1;
 end loop;
 update public.trade_offers set status='completed' where id=offer.id;
 insert into public.completed_trades(offer_id) values(offer.id);
 insert into public.notifications(user_id,title,body) values(offer.sender_id,'Tausch abgeschlossen','Dein Kartentausch wurde abgeschlossen.');
 insert into public.notifications(user_id,title,body) values(offer.receiver_id,'Tausch abgeschlossen','Dein Kartentausch wurde abgeschlossen.');
 insert into public.audit_logs(actor_id,action,target_type,target_id,reason,details) values(uid,'trade_completed','trade_offer',offer.id::text,'Both sides validated and transferred atomically',jsonb_build_object('cards_transferred',moved));
 return jsonb_build_object('offer_id',offer.id,'status','completed','cards_transferred',moved,'replayed',false);
end $$;
revoke all on function public.accept_trade(uuid,uuid) from public,anon;
grant execute on function public.accept_trade(uuid,uuid) to authenticated;

create or replace function public.close_trade(p_offer_id uuid,p_action text)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare uid uuid:=auth.uid(); offer public.trade_offers%rowtype; new_status text;
begin
 if uid is null then raise exception 'authentication_required'; end if;
 if p_action not in('rejected','withdrawn') then raise exception 'invalid_trade_action'; end if;
 select * into offer from public.trade_offers where id=p_offer_id for update;
 if not found then raise exception 'trade_not_found'; end if;
 if offer.status<>'pending' then raise exception 'trade_not_pending'; end if;
 if p_action='rejected' and offer.receiver_id<>uid then raise exception 'only_receiver_can_reject'; end if;
 if p_action='withdrawn' and offer.sender_id<>uid then raise exception 'only_sender_can_withdraw'; end if;
 update public.trade_offers set status=p_action where id=offer.id;
 insert into public.audit_logs(actor_id,action,target_type,target_id,reason) values(uid,'trade_'||p_action,'trade_offer',offer.id::text,'Participant closed pending offer');
 return jsonb_build_object('offer_id',offer.id,'status',p_action);
end $$;
revoke all on function public.close_trade(uuid,text) from public,anon;
grant execute on function public.close_trade(uuid,text) to authenticated;
