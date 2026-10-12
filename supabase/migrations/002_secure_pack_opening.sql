-- Atomic pack purchase. Client cannot choose outcomes, costs, or card IDs.
create table if not exists public.pack_opening_items(
 id uuid primary key default gen_random_uuid(),
 opening_id uuid not null references public.pack_openings(id) on delete cascade,
 inventory_id uuid not null references public.card_inventory(id),
 card_definition_id uuid not null references public.card_definitions(id),
 rarity public.card_rarity not null
);
alter table public.pack_opening_items enable row level security;
drop policy if exists "own pack opening items read" on public.pack_opening_items;
create policy "own pack opening items read" on public.pack_opening_items for select to authenticated
 using(exists(select 1 from public.pack_openings o where o.id=opening_id and (o.user_id=auth.uid() or public.has_role('admin'))));

create or replace function public.open_pack(p_pack_id uuid,p_idempotency_key uuid)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare
 uid uuid:=auth.uid();
 p public.pack_definitions%rowtype;
 bal bigint;
 opening uuid;
 version_id uuid;
 rarity_choice public.card_rarity;
 r public.card_rarity;
 roll numeric;
 cumulative numeric;
 weight_total numeric;
 eligible_total numeric;
 chosen public.card_definitions%rowtype;
 inv uuid;
 i integer;
 output jsonb:='[]'::jsonb;
 replay_items jsonb;
 weights jsonb;
 is_guaranteed boolean;
begin
 if uid is null then raise exception 'authentication_required'; end if;
 if p_pack_id is null or p_idempotency_key is null then raise exception 'packId_and_idempotencyKey_required'; end if;

 -- Serialise duplicate requests by user/key before checking the ledger.
 perform pg_advisory_xact_lock(hashtextextended(uid::text||':'||p_idempotency_key::text,0));
 select id into opening from public.pack_openings where user_id=uid and idempotency_key=p_idempotency_key;
 if opening is not null then
   select coalesce(jsonb_agg(jsonb_build_object('inventory_id',x.inventory_id,'card_id',x.card_definition_id,'rarity',x.rarity) order by x.id),'[]'::jsonb)
   into replay_items from public.pack_opening_items x where x.opening_id=opening;
   return jsonb_build_object('opening_id',opening,'replayed',true,'items',replay_items);
 end if;

 select * into p from public.pack_definitions where id=p_pack_id and is_active=true
   and (available_from is null or available_from<=now()) and (available_until is null or available_until>now())
 for share;
 if not found then raise exception 'pack_unavailable'; end if;
 weights:=p.rarity_weights;
 weight_total:=0;
 foreach r in array enum_range(null::public.card_rarity) loop
   if jsonb_typeof(weights->r::text) <> 'number' then raise exception 'invalid_probability_weights'; end if;
   if (weights->>r::text)::numeric < 0 then raise exception 'invalid_probability_weights'; end if;
   weight_total:=weight_total+(weights->>r::text)::numeric;
   if (weights->>r::text)::numeric>0 and not exists(select 1 from public.card_definitions d where d.is_available and d.rarity=r) then
     raise exception 'rarity_has_no_available_cards: %',r;
   end if;
 end loop;
 if abs(weight_total-100)>0.0001 then raise exception 'invalid_probability_total'; end if;
 if p.guaranteed_count>p.card_count then raise exception 'invalid_guarantee_count'; end if;
 if p.guaranteed_count>0 and p.guaranteed_rarity is null then raise exception 'guarantee_rarity_required'; end if;
 if p.guaranteed_count>0 and not exists(select 1 from public.card_definitions d where d.is_available and d.rarity>=p.guaranteed_rarity) then raise exception 'no_available_guaranteed_cards'; end if;

 insert into public.club_point_balances(user_id,balance) values(uid,1250) on conflict(user_id) do nothing;
 select balance into bal from public.club_point_balances where user_id=uid for update;
 if bal<p.price then raise exception 'insufficient_club_points'; end if;
 select id into version_id from public.pack_probability_versions where pack_id=p.id order by version desc limit 1;
 insert into public.pack_openings(user_id,pack_id,probability_version_id,cost,idempotency_key)
 values(uid,p.id,version_id,p.price,p_idempotency_key) returning id into opening;
 update public.club_point_balances set balance=balance-p.price,updated_at=now() where user_id=uid;
 insert into public.club_point_transactions(user_id,delta,reason,reference_id,idempotency_key)
 values(uid,-p.price,'pack_purchase',opening,p_idempotency_key);

 for i in 1..p.card_count loop
   is_guaranteed:=i<=p.guaranteed_count;
   eligible_total:=0;
   if is_guaranteed then
     foreach r in array enum_range(null::public.card_rarity) loop
       if r>=p.guaranteed_rarity then eligible_total:=eligible_total+coalesce((weights->>r::text)::numeric,0); end if;
     end loop;
     if eligible_total<=0 then raise exception 'guaranteed_probability_empty'; end if;
     roll:=random()*eligible_total;
   else
     roll:=random()*100;
   end if;
   cumulative:=0;
   rarity_choice:='Bronze';
   foreach r in array enum_range(null::public.card_rarity) loop
     if not is_guaranteed or r>=p.guaranteed_rarity then
       cumulative:=cumulative+coalesce((weights->>r::text)::numeric,0);
       if roll<cumulative then rarity_choice:=r; exit; end if;
     end if;
   end loop;
   select * into chosen from public.card_definitions d where d.is_available and d.rarity=rarity_choice order by random() limit 1;
   if not found then raise exception 'rarity_has_no_available_cards: %',rarity_choice; end if;
   insert into public.card_inventory(user_id,card_definition_id) values(uid,chosen.id) returning id into inv;
   insert into public.pack_opening_items(opening_id,inventory_id,card_definition_id,rarity) values(opening,inv,chosen.id,rarity_choice);
   output:=output||jsonb_build_array(jsonb_build_object('inventory_id',inv,'card_id',chosen.id,'name',chosen.display_name,'rating',chosen.overall,'rarity',rarity_choice,'position',chosen.position,'guaranteed',is_guaranteed));
 end loop;
 return jsonb_build_object('opening_id',opening,'replayed',false,'items',output,'balance',bal-p.price,'probability_version_id',version_id);
end $$;
revoke all on function public.open_pack(uuid,uuid) from public,anon;
grant execute on function public.open_pack(uuid,uuid) to authenticated;
