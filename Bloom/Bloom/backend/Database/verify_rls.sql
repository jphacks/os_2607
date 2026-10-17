begin;
-- Temporary test users: rolled back with the entire transaction.
insert into auth.users(id) values
 ('a1000000-0000-4000-8000-000000000001'),
 ('a1000000-0000-4000-8000-000000000002');
set local role authenticated;
select set_config('request.jwt.claim.sub', 'a1000000-0000-4000-8000-000000000001', true);
insert into public.profiles(id,display_name) values ('a1000000-0000-4000-8000-000000000001','Owner');
update public.profiles set bio='Updated' where id=auth.uid();
insert into public.profile_contents(profile_id,content_type,title,content_value,is_public)
values (auth.uid(),'text','Public','value',true),(auth.uid(),'text','Private','secret',false);
do $$ begin
 if (select count(*) from public.profiles where id=auth.uid() and bio='Updated') <> 1 then raise exception 'owner profile read/update failed'; end if;
 if (select count(*) from public.profile_contents where profile_id=auth.uid()) <> 2 then raise exception 'owner content read failed'; end if;
 begin
  insert into public.profiles(id,display_name) values ('a1000000-0000-4000-8000-000000000002','Spoof');
  raise exception 'foreign insert accepted';
 exception when insufficient_privilege then null; end;
 begin
  update public.profiles set display_name='' where id=auth.uid();
  raise exception 'empty name accepted';
 exception when check_violation then null; end;
 begin
  update public.profiles set bio=repeat('x',501) where id=auth.uid();
  raise exception 'long bio accepted';
 exception when check_violation then null; end;
 begin
  insert into public.profile_contents(profile_id,content_type,title,content_value,display_order)
  values(auth.uid(),'text','Invalid','value',-1);
  raise exception 'negative order accepted';
 exception when check_violation then null; end;
 begin
  insert into public.profile_contents(profile_id,content_type,title,content_value)
  values(auth.uid(),'invalid','Invalid','value');
  raise exception 'invalid type accepted';
 exception when check_violation then null; end;
end $$;
select set_config('request.jwt.claim.sub', 'a1000000-0000-4000-8000-000000000002', true);
do $$ declare affected integer; begin
 if (select count(*) from public.profiles where id='a1000000-0000-4000-8000-000000000001') <> 1 then raise exception 'public profile hidden'; end if;
 if (select count(*) from public.profile_contents where profile_id='a1000000-0000-4000-8000-000000000001') <> 1 then raise exception 'content privacy failed'; end if;
 update public.profiles set display_name='Attacker' where id='a1000000-0000-4000-8000-000000000001';
 get diagnostics affected = row_count;
 if affected <> 0 then raise exception 'foreign profile updated'; end if;
 update public.profile_contents set title='Attacker' where profile_id='a1000000-0000-4000-8000-000000000001';
 get diagnostics affected = row_count;
 if affected <> 0 then raise exception 'foreign content updated'; end if;
 delete from public.profile_contents where profile_id='a1000000-0000-4000-8000-000000000001';
 get diagnostics affected = row_count;
 if affected <> 0 then raise exception 'foreign content deleted'; end if;
end $$;
select set_config('request.jwt.claim.sub', 'a1000000-0000-4000-8000-000000000001', true);
update public.profiles set is_discoverable=false where id=auth.uid();
update public.profile_contents set title='Changed' where profile_id=auth.uid();
do $$ begin
 if (select count(*) from public.profile_contents where profile_id=auth.uid() and title='Changed') <> 2 then raise exception 'owner content update failed'; end if;
end $$;
select set_config('request.jwt.claim.sub', 'a1000000-0000-4000-8000-000000000002', true);
do $$ begin
 if exists(select 1 from public.profiles where id='a1000000-0000-4000-8000-000000000001') then raise exception 'private profile leaked'; end if;
 if exists(select 1 from public.profile_contents where profile_id='a1000000-0000-4000-8000-000000000001') then raise exception 'private profile contents leaked'; end if;
end $$;
select set_config('request.jwt.claim.sub', 'a1000000-0000-4000-8000-000000000001', true);
delete from public.profile_contents where profile_id=auth.uid();
do $$ begin
 if exists(select 1 from public.profile_contents where profile_id=auth.uid()) then raise exception 'owner content delete failed'; end if;
end $$;
rollback;
select 'PASS: owner CRUD, cross-user RLS, private profile/content, constraints; all fixtures rolled back' as result;

