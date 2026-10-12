-- All currency changes and card grants happen inside this transaction.
create table if not exists public.pack_opening_items(id uuid primary key default gen_random_uuid(),opening_id uuid not null references public.pack_openings(id) on delete cascade,inventory_id uuid not null references public.card_inventory(id),card_definition_id uuid not null references public.card_definitions(id),rarity public.card_rarity not null);
alter table public.pack_opening_items enable row level security;
create policy "own pack opening items read" on public.pack_opening_items for select to authenticated using(exists(select 1 from public.pack_openings o where o.id=opening_id and (o.user_id=auth.uid() or public.has_role('admin'))));
create or replace function public.open_pack(p_pack_id uuid,p_idempotency_key uuid) returns jsonb language plpgsql security definer set search_path=public as $$
declare uid uuid:=auth.uid(); p public.pack_definitions%rowtype; bal bigint; opening uuid; version_id uuid; rarity_choice public.card_rarity; roll numeric; cumulative numeric; weight_total numeric; chosen public.card_definitions%rowtype; inv uuid; i integer; output jsonb:='[]'::jsonb; replay_items jsonb;
begin
 if uid is null then raise exception 'authentication_required'; end if;
 if p_idempotency_key is null then raise exception 'idempotency_key_required'; end if;
 select * into p from public.pack_definitions where id=p_pack_id and is_active=true for share;
 if not found then raise exception 'pack_unavailable'; end if;
 select id into opening from public.pack_openings where user_id=uid and idempotency_key=p_idempotency_key;
 if opening is not null then select coalesce(jsonb_agg(jsonb_build_object('inventory_id',i.inventory_id,'card_id',i.card_definition_id,'rarity',i.rarity)),'[]'::jsonb) into replay_items from public.pack_opening_items i where i.opening_id=opening; return jsonb_build_object('opening_id',opening,'replayed',true,'items',replay_items); end if;
 weight_total:=coalesce((p.rarity_weights->>'Bronze')::numeric,0)+coalesce((p.rarity_weights->>'Silber')::numeric,0)+coalesce((p.rarity_weights->>'Gold')::numeric,0)+coalesce((p.rarity_weights->>'Ultimate')::numeric,0)+coalesce((p.rarity_weights->>'Legendär')::numeric,0);
 if abs(weight_total-100)>0.0001 then raise exception 'invalid_probability_total'; end if;
 insert into public.club_point_balances(user_id,balance) values(uid,1250) on conflict(user_id) do nothing;
 select balance into bal from public.club_point_balances where user_id=uid for update;
 if bal<p.price then raise exception 'insufficient_club_points'; end if;
 select id into version_id from public.pack_probability_versions where pack_id=p.id order by version desc limit 1;
 insert into public.pack_openings(user_id,pack_id,probability_version_id,cost,idempotency_key) values(uid,p.id,version_id,p.price,p_idempotency_key) returning id into opening;
 update public.club_point_balances set balance=balance-p.price,updated_at=now() where user_id=uid;
 insert into public.club_point_transactions(user_id,delta,reason,reference_id,idempotency_key) values(uid,-p.price,'pack_purchase',opening,p_idempotency_key);
 for i in 1..p.card_count loop
   roll:=random()*100; cumulative:=0; rarity_choice:='Bronze';
   foreach rarity_choice in array enum_range(null::public.card_rarity) loop
     cumulative:=cumulative+coalesce((p.rarity_weights->>rarity_choice::text)::numeric,0);
     if roll<cumulative then exit; end if;
   end loop;
   select * into chosen from public.card_definitions d where d.is_available and d.rarity=rarity_choice order by random() limit 1;
   if not found then raise exception 'rarity_has_no_available_cards: %',rarity_choice; end if;
   insert into public.card_inventory(user_id,card_definition_id) values(uid,chosen.id) returning id into inv;
   insert into public.pack_opening_items(opening_id,inventory_id,card_definition_id,rarity) values(opening,inv,chosen.id,rarity_choice);
   output:=output||jsonb_build_array(jsonb_build_object('inventory_id',inv,'card_id',chosen.id,'name',chosen.display_name,'rating',chosen.overall,'rarity',rarity_choice,'position',chosen.position));
 end loop;
 return jsonb_build_object('opening_id',opening,'replayed',false,'items',output,'balance',bal-p.price);
end; $$;
revoke all on function public.open_pack(uuid,uuid) from public,anon;
grant execute on function public.open_pack(uuid,uuid) to authenticated;
-- PostgreSQL random() is server-side but not cryptographic. For production, review the RNG and concurrency model before activating real users.
