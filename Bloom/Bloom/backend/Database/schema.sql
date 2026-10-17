-- Initial schema; apply once through Supabase MCP. No local Supabase stack.
create table public.profiles (
 id uuid primary key references auth.users(id) on delete cascade,
 display_name text not null check (char_length(btrim(display_name)) between 1 and 50),
 affiliation text check (char_length(affiliation) <= 100),
 bio text check (char_length(bio) <= 500),
 avatar_path text,
 is_discoverable boolean not null default true,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now()
);
create table public.profile_contents (
 id uuid primary key default gen_random_uuid(),
 profile_id uuid not null references public.profiles(id) on delete cascade,
 content_type text not null check (content_type in ('text','image','music','url','video')),
 title text not null check (char_length(btrim(title)) between 1 and 100),
 content_value text not null check (char_length(btrim(content_value)) between 1 and 2000),
 unlock_after_seconds integer not null default 0 check (unlock_after_seconds >= 0),
 display_order integer not null default 0 check (display_order >= 0),
 is_public boolean not null default true,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now()
);
create index profile_contents_profile_order_idx on public.profile_contents(profile_id, display_order);
create function public.bloom_set_updated_at() returns trigger
language plpgsql set search_path = '' as $$
begin
 new.updated_at = now();
 return new;
end;
$$;
create trigger profiles_updated_at before update on public.profiles
for each row execute function public.bloom_set_updated_at();
create trigger profile_contents_updated_at before update on public.profile_contents
for each row execute function public.bloom_set_updated_at();

alter table public.profiles enable row level security;
alter table public.profile_contents enable row level security;
revoke all on public.profiles, public.profile_contents from anon, authenticated;
grant select on public.profiles, public.profile_contents to authenticated;
grant insert (id, display_name, affiliation, bio, avatar_path, is_discoverable),
 update (display_name, affiliation, bio, avatar_path, is_discoverable) on public.profiles to authenticated;
grant insert (profile_id, content_type, title, content_value, unlock_after_seconds, display_order, is_public),
 update (content_type, title, content_value, unlock_after_seconds, display_order, is_public),
 delete on public.profile_contents to authenticated;
revoke all on function public.bloom_set_updated_at() from public;

create policy profiles_select on public.profiles for select to authenticated
using (id = (select auth.uid()) or (is_discoverable and (select auth.uid()) is not null));
create policy profiles_insert on public.profiles for insert to authenticated
with check (id = (select auth.uid()));
create policy profiles_update on public.profiles for update to authenticated
using (id = (select auth.uid())) with check (id = (select auth.uid()));
create policy contents_select on public.profile_contents for select to authenticated
using (profile_id = (select auth.uid()) or (
 is_public and (select auth.uid()) is not null and exists (
 select 1 from public.profiles p where p.id = profile_id and p.is_discoverable
 )));
create policy contents_insert on public.profile_contents for insert to authenticated
with check (profile_id = (select auth.uid()));
create policy contents_update on public.profile_contents for update to authenticated
using (profile_id = (select auth.uid())) with check (profile_id = (select auth.uid()));
create policy contents_delete on public.profile_contents for delete to authenticated
using (profile_id = (select auth.uid()));

-- Enforce length on the stored value, including surrounding whitespace.
alter table public.profiles add constraint profiles_display_name_raw_length check (char_length(display_name) <= 50);
alter table public.profile_contents add constraint profile_contents_title_raw_length check (char_length(title) <= 100);
alter table public.profile_contents add constraint profile_contents_value_raw_length check (char_length(content_value) <= 2000);

