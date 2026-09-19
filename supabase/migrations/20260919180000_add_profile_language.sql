-- DawaCare — persist the user's selected UI language for all devices and push notifications.
alter table public.profiles
  add column if not exists language text not null default 'ar';

alter table public.profiles
  drop constraint if exists profiles_language_check;

alter table public.profiles
  add constraint profiles_language_check
  check (language in ('ar', 'en', 'fr'));

update public.profiles p
set language = case
  when u.raw_user_meta_data ->> 'language' in ('ar','en','fr')
    then u.raw_user_meta_data ->> 'language'
  else 'ar'
end
from auth.users u
where u.id = p.id;

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
declare
  new_code text;
  attempts int := 0;
  new_language text;
begin
  loop
    new_code := public.generate_family_code();
    exit when not exists (select 1 from public.profiles where family_code = new_code) or attempts > 10;
    attempts := attempts + 1;
  end loop;

  new_language := case
    when new.raw_user_meta_data ->> 'language' in ('ar','en','fr')
      then new.raw_user_meta_data ->> 'language'
    else 'ar'
  end;

  insert into public.profiles (id, full_name, family_code, language)
  values (new.id, coalesce(new.raw_user_meta_data ->> 'full_name', ''), new_code, new_language);
  return new;
end;
$$;