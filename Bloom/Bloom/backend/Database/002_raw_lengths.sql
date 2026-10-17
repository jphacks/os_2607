-- Enforce length on the stored value, including surrounding whitespace.
alter table public.profiles add constraint profiles_display_name_raw_length check (char_length(display_name) <= 50);
alter table public.profile_contents add constraint profile_contents_title_raw_length check (char_length(title) <= 100);
alter table public.profile_contents add constraint profile_contents_value_raw_length check (char_length(content_value) <= 2000);

