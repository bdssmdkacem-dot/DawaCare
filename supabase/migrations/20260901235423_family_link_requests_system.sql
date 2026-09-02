-- DawaCare — replace instant permanent-code linking with a temporary,
-- one-time code + patient-approval request flow.

-- Retire the old permanent-code mechanism.
drop function if exists public.link_family_member(text);

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id, full_name)
  values (new.id, coalesce(new.raw_user_meta_data ->> 'full_name', ''));
  return new;
end;
$$;

alter table public.profiles drop column if exists family_code;
drop function if exists public.generate_family_code();

create table if not exists public.family_link_codes (
  id          uuid primary key default gen_random_uuid(),
  patient_id  uuid not null references public.profiles (id) on delete cascade,
  code        text not null,
  expires_at  timestamptz not null,
  used        boolean not null default false,
  used_by     uuid references public.profiles (id),
  created_at  timestamptz not null default now()
);

create unique index if not exists idx_family_link_codes_active_code
  on public.family_link_codes (code) where (used = false);
create index if not exists idx_family_link_codes_patient
  on public.family_link_codes (patient_id, used, expires_at);

create table if not exists public.family_link_requests (
  id                 uuid primary key default gen_random_uuid(),
  code_id            uuid references public.family_link_codes (id),
  patient_id         uuid not null references public.profiles (id) on delete cascade,
  caregiver_id       uuid not null references public.profiles (id) on delete cascade,
  relationship_label text,
  role               text not null default 'CAREGIVER' check (role in ('PRIMARY_CAREGIVER', 'CAREGIVER', 'VIEWER')),
  status             text not null default 'PENDING' check (status in ('PENDING', 'APPROVED', 'REJECTED', 'CANCELLED')),
  requested_at       timestamptz not null default now(),
  responded_at       timestamptz
);

create unique index if not exists idx_one_pending_request_per_pair
  on public.family_link_requests (patient_id, caregiver_id) where (status = 'PENDING');
create index if not exists idx_family_link_requests_patient on public.family_link_requests (patient_id, status);
create index if not exists idx_family_link_requests_caregiver on public.family_link_requests (caregiver_id, status);

alter table public.caregiver_patient add column if not exists relationship_label text;

create or replace function public.is_linked_or_pending_with(other_id uuid)
returns boolean
language sql
security definer set search_path = public
stable
as $$
  select exists (
    select 1 from public.caregiver_patient
    where (caregiver_id = auth.uid() and patient_id = other_id)
       or (patient_id = auth.uid() and caregiver_id = other_id)
  ) or exists (
    select 1 from public.family_link_requests
    where status = 'PENDING'
      and ((patient_id = auth.uid() and caregiver_id = other_id)
        or (caregiver_id = auth.uid() and patient_id = other_id))
  );
$$;

drop policy if exists "profiles_select_own_or_linked" on public.profiles;
create policy "profiles_select_own_or_linked" on public.profiles
  for select using (id = auth.uid() or public.is_linked_or_pending_with(id));

create or replace function public.create_family_link_code()
returns table (code text, expires_at timestamptz)
language plpgsql
security definer set search_path = public
as $$
declare
  new_code text;
  new_expiry timestamptz := now() + interval '15 minutes';
  attempts int := 0;
begin
  update public.family_link_codes fc
     set used = true
   where fc.patient_id = auth.uid() and fc.used = false and fc.expires_at > now();

  loop
    new_code := lpad(floor(random() * 1000000)::text, 6, '0');
    exit when not exists (
      select 1 from public.family_link_codes fc where fc.code = new_code and fc.used = false
    ) or attempts > 20;
    attempts := attempts + 1;
  end loop;

  insert into public.family_link_codes (patient_id, code, expires_at)
  values (auth.uid(), new_code, new_expiry);

  return query select new_code, new_expiry;
end;
$$;

grant execute on function public.create_family_link_code() to authenticated;

create or replace function public.request_family_link(p_code text, p_relationship_label text default null)
returns table (request_id uuid, patient_id uuid, patient_name text)
language plpgsql
security definer set search_path = public
as $$
declare
  v_code_row public.family_link_codes%rowtype;
  v_patient_name text;
  v_request_id uuid;
begin
  select fc.* into v_code_row
  from public.family_link_codes fc
  where fc.code = upper(trim(p_code)) and fc.used = false and fc.expires_at > now()
  order by fc.created_at desc
  limit 1;

  if v_code_row.id is null then raise exception 'CODE_INVALID_OR_EXPIRED'; end if;
  if v_code_row.patient_id = auth.uid() then raise exception 'CANNOT_LINK_SELF'; end if;

  if exists (
    select 1 from public.caregiver_patient cp
    where cp.patient_id = v_code_row.patient_id and cp.caregiver_id = auth.uid()
  ) then raise exception 'ALREADY_LINKED'; end if;

  if exists (
    select 1 from public.family_link_requests flr
    where flr.patient_id = v_code_row.patient_id and flr.caregiver_id = auth.uid() and flr.status = 'PENDING'
  ) then raise exception 'REQUEST_ALREADY_PENDING'; end if;

  update public.family_link_codes fc set used = true, used_by = auth.uid() where fc.id = v_code_row.id;

  insert into public.family_link_requests (code_id, patient_id, caregiver_id, relationship_label, role, status)
  values (v_code_row.id, v_code_row.patient_id, auth.uid(), nullif(trim(p_relationship_label), ''), 'CAREGIVER', 'PENDING')
  returning id into v_request_id;

  select p.full_name into v_patient_name from public.profiles p where p.id = v_code_row.patient_id;
  return query select v_request_id, v_code_row.patient_id, coalesce(v_patient_name, 'مريض');
end;
$$;

grant execute on function public.request_family_link(text, text) to authenticated;

create or replace function public.respond_family_link_request(p_request_id uuid, p_approve boolean)
returns table (status text)
language plpgsql
security definer set search_path = public
as $$
declare
  v_req public.family_link_requests%rowtype;
  v_new_status text;
begin
  select flr.* into v_req
  from public.family_link_requests flr
  where flr.id = p_request_id and flr.patient_id = auth.uid() and flr.status = 'PENDING';

  if v_req.id is null then raise exception 'REQUEST_NOT_FOUND'; end if;

  v_new_status := case when p_approve then 'APPROVED' else 'REJECTED' end;

  update public.family_link_requests flr
     set status = v_new_status, responded_at = now()
   where flr.id = p_request_id;

  if p_approve then
    insert into public.caregiver_patient (caregiver_id, patient_id, role, relationship_label)
    values (v_req.caregiver_id, v_req.patient_id, v_req.role, v_req.relationship_label)
    on conflict (caregiver_id, patient_id) do nothing;
  end if;

  return query select v_new_status;
end;
$$;

grant execute on function public.respond_family_link_request(uuid, boolean) to authenticated;

create or replace function public.cancel_family_link_request(p_request_id uuid)
returns void
language plpgsql
security definer set search_path = public
as $$
begin
  update public.family_link_requests flr
     set status = 'CANCELLED', responded_at = now()
   where flr.id = p_request_id and flr.caregiver_id = auth.uid() and flr.status = 'PENDING';
  if not found then raise exception 'REQUEST_NOT_FOUND'; end if;
end;
$$;

grant execute on function public.cancel_family_link_request(uuid) to authenticated;

alter table public.family_link_codes enable row level security;
alter table public.family_link_requests enable row level security;

create policy "family_link_codes_select_own" on public.family_link_codes
  for select using (patient_id = auth.uid());
create policy "family_link_requests_select" on public.family_link_requests
  for select using (patient_id = auth.uid() or caregiver_id = auth.uid());
