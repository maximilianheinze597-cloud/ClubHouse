-- Fictional game-only characters; no real player photos or performance claims.
insert into public.card_definitions(display_name,position,overall,rarity,pace,shooting,passing,dribbling,defense,physical,edition,is_available)
select v.display_name,v.position,v.overall,v.rarity::public.card_rarity,v.pace,v.shooting,v.passing,v.dribbling,v.defense,v.physical,v.edition,v.is_available
from (values
('Mika Sommer','ST',58,'Bronze',62,59,51,60,28,55,'SVHS · Saison 26/27',true),
('Toni Feld','IV',70,'Silber',65,42,60,55,73,75,'SVHS · Saison 26/27',true),
('Kai Grün','ZM',80,'Gold',78,76,82,80,64,72,'SVHS · Saison 26/27',true),
('Nico Licht','TW',88,'Ultimate',65,20,70,42,30,82,'SVHS · Special Edition',true),
('Robin Stern','LF',96,'Legendär',95,94,88,96,45,86,'SVHS · Legend Edition',true)
) as v(display_name,position,overall,rarity,pace,shooting,passing,dribbling,defense,physical,edition,is_available)
where not exists(select 1 from public.card_definitions c where c.display_name=v.display_name and c.edition=v.edition);
with s as (insert into public.pack_definitions(name,price,card_count,rarity_weights,is_active) values('Starter-Pack',250,3,'{"Bronze":55,"Silber":30,"Gold":12,"Ultimate":2.8,"Legendär":0.2}',true) on conflict(name) do update set rarity_weights=excluded.rarity_weights returning id),
g as (insert into public.pack_definitions(name,price,card_count,rarity_weights,is_active) values('Gold-Pack',750,5,'{"Bronze":25,"Silber":35,"Gold":32,"Ultimate":7.5,"Legendär":0.5}',true) on conflict(name) do update set rarity_weights=excluded.rarity_weights returning id)
insert into public.pack_probability_versions(pack_id,version,rarity_weights)
select p.id,1,p.rarity_weights from public.pack_definitions p where p.name in('Starter-Pack','Gold-Pack') and not exists(select 1 from public.pack_probability_versions v where v.pack_id=p.id and v.version=1);
-- Ultimate-Pack stays inactive until its guaranteed Gold+ rule is implemented server-side.
-- Fictional, clearly game-only AI opponents.
insert into public.ai_opponents(name,formation,overall,style,difficulty,roster,is_active)
select v.name,v.formation,v.overall,v.style,v.difficulty,v.roster::jsonb,true
from (values
('Greenfield AI','4+1',58,'defensive','easy','[{"name":"AI Keeper","position":"TW"},{"name":"AI Defender","position":"IV"},{"name":"AI Midfielder","position":"ZM"},{"name":"AI Winger","position":"LF"},{"name":"AI Striker","position":"ST"}]'),
('Riverside AI','4+1',68,'balanced','normal','[{"name":"AI Keeper II","position":"TW"},{"name":"AI Defender II","position":"IV"},{"name":"AI Midfielder II","position":"ZM"},{"name":"AI Winger II","position":"LF"},{"name":"AI Striker II","position":"ST"}]'),
('Night Owls AI','4+1',78,'attacking','hard','[{"name":"AI Keeper III","position":"TW"},{"name":"AI Defender III","position":"IV"},{"name":"AI Midfielder III","position":"ZM"},{"name":"AI Winger III","position":"LF"},{"name":"AI Striker III","position":"ST"}]')
) as v(name,formation,overall,style,difficulty,roster)
where not exists(select 1 from public.ai_opponents a where a.name=v.name);
insert into public.objectives(title,description,period,points_reward,is_active)
select v.title,v.description,v.period,v.reward,true from (values
('Erstes Match','Schließe ein serverseitig simuliertes Match ab.','daily',100),
('Pack-Sammler','Öffne ein Pack mit Club Points.','daily',75),
('Wochenstarter','Schließe drei simulierte Matches ab.','weekly',250)
) as v(title,description,period,reward)
where not exists(select 1 from public.objectives o where o.title=v.title);
insert into public.card_album_definitions(name,is_active)
select 'Saison 26/27 · SVHS',true where not exists(select 1 from public.card_album_definitions where name='Saison 26/27 · SVHS');
