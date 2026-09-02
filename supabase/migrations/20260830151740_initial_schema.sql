-- ============================================================================
-- DawaCare — initial Supabase schema
-- Migrated from the original supabase/schema.sql so the database is managed
-- entirely through Supabase migrations.
-- ============================================================================

create extension if not exists "pgcrypto";

create table if not exists public.profiles (
  id            uuid primary key references auth.users (id) on delete cascade,
  full_name     text not null default '',
  phone         text,
  avatar_url    text,
  timezone      text not null default 'Africa/Casablanca',
  family_code   text not null unique,
  created_at    timestamptz not null default now()
);

create or replace function public.generate_family_code()
returns text
language plpgsql
as $$
declare
  chars text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  code text := '';
  i int;
begin
  for i in 1..6 loop
    code := code || substr(chars, floor(random() * length(chars) + 1)::int, 1);
  end loop;
  return code;
end;
$$;

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
declare
  new_code text;
  attempts int := 0;
begin
  loop
    new_code := public.generate_family_code();
    exit when not exists (select 1 from public.profiles where family_code = new_code) or attempts > 10;
    attempts := attempts + 1;
  end loop;
  insert into public.profiles (id, full_name, family_code)
  values (new.id, coalesce(new.raw_user_meta_data ->> 'full_name', ''), new_code);
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

create table if not exists public.caregiver_patient (
  id            uuid primary key default gen_random_uuid(),
  caregiver_id  uuid not null references public.profiles (id) on delete cascade,
  patient_id    uuid not null references public.profiles (id) on delete cascade,
  role          text not null default 'CAREGIVER' check (role in ('PRIMARY_CAREGIVER', 'CAREGIVER', 'VIEWER')),
  created_at    timestamptz not null default now(),
  unique (caregiver_id, patient_id)
);

create or replace function public.is_caregiver_of(target_patient_id uuid)
returns boolean
language sql
security definer set search_path = public
stable
as $$
  select exists (
    select 1 from public.caregiver_patient
    where patient_id = target_patient_id and caregiver_id = auth.uid()
  );
$$;

create or replace function public.can_edit_patient(target_patient_id uuid)
returns boolean
language sql
security definer set search_path = public
stable
as $$
  select target_patient_id = auth.uid()
  or exists (
    select 1 from public.caregiver_patient
    where patient_id = target_patient_id
      and caregiver_id = auth.uid()
      and role in ('PRIMARY_CAREGIVER', 'CAREGIVER')
  );
$$;

create or replace function public.link_family_member(p_family_code text)
returns table (patient_id uuid, patient_name text)
language plpgsql
security definer set search_path = public
as $$
declare
  found_id uuid;
  found_name text;
begin
  select id, full_name into found_id, found_name
  from public.profiles
  where family_code = upper(trim(p_family_code));
  if found_id is null then raise exception 'FAMILY_CODE_NOT_FOUND'; end if;
  if found_id = auth.uid() then raise exception 'CANNOT_LINK_SELF'; end if;
  insert into public.caregiver_patient (caregiver_id, patient_id, role)
  values (auth.uid(), found_id, 'CAREGIVER')
  on conflict (caregiver_id, patient_id) do nothing;
  return query select found_id, found_name;
end;
$$;

grant execute on function public.link_family_member(text) to authenticated;

create table if not exists public.medications (
  id uuid primary key default gen_random_uuid(), patient_id uuid not null references public.profiles (id) on delete cascade,
  name text not null, generic_name text, strength text, dosage_form text, instructions text, image_url text,
  start_date date not null default current_date, end_date date, active boolean not null default true,
  created_by uuid not null references public.profiles (id), created_at timestamptz not null default now()
);

create table if not exists public.medication_schedules (
  id uuid primary key default gen_random_uuid(), medication_id uuid not null references public.medications (id) on delete cascade,
  type text not null check (type in ('DAILY', 'WEEKLY', 'SPECIFIC_DAYS', 'INTERVAL', 'ONCE', 'PRN')),
  time text not null default '08:00', days_of_week int[] not null default '{}', interval_days int,
  dose_amount text not null default '1', start_date date not null default current_date, end_date date,
  timezone text not null default 'Africa/Casablanca', created_at timestamptz not null default now()
);

create table if not exists public.dose_instances (
  id uuid primary key default gen_random_uuid(), medication_id uuid not null references public.medications (id) on delete cascade,
  schedule_id uuid not null references public.medication_schedules (id) on delete cascade,
  patient_id uuid not null references public.profiles (id) on delete cascade,
  scheduled_at timestamptz not null, dose_amount text not null default '1',
  status text not null default 'PENDING' check (status in ('PENDING', 'REMINDER_SENT', 'SNOOZED', 'TAKEN', 'MISSED', 'SKIPPED', 'CANCELLED')),
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(), unique (schedule_id, scheduled_at)
);
create index if not exists idx_dose_instances_patient_time on public.dose_instances (patient_id, scheduled_at);
create index if not exists idx_dose_instances_status on public.dose_instances (status);

create table if not exists public.dose_events (
  id uuid primary key default gen_random_uuid(), dose_id uuid not null references public.dose_instances (id) on delete cascade,
  patient_id uuid not null references public.profiles (id) on delete cascade, action text not null,
  source text not null default 'PATIENT' check (source in ('PATIENT', 'CAREGIVER', 'SYSTEM')),
  device_id text, created_at timestamptz not null default now()
);

create table if not exists public.reminder_policies (
  patient_id uuid primary key references public.profiles (id) on delete cascade,
  repeat_interval_min int not null default 15, max_repeats int not null default 2,
  grace_period_min int not null default 60, caregiver_escalation boolean not null default true,
  updated_at timestamptz not null default now()
);

create table if not exists public.devices (
  id uuid primary key default gen_random_uuid(), user_id uuid not null references public.profiles (id) on delete cascade,
  platform text not null default 'android', push_token text, app_version text, timezone text,
  last_seen timestamptz not null default now(), unique (user_id, push_token)
);

create table if not exists public.caregiver_alerts (
  id uuid primary key default gen_random_uuid(), caregiver_id uuid not null references public.profiles (id) on delete cascade,
  patient_id uuid not null references public.profiles (id) on delete cascade,
  dose_id uuid references public.dose_instances (id) on delete cascade, type text not null default 'MISSED_DOSE',
  message text not null, read boolean not null default false, created_at timestamptz not null default now()
);

create table if not exists public.audit_logs (
  id uuid primary key default gen_random_uuid(), actor_id uuid references public.profiles (id), entity_type text not null,
  entity_id uuid not null, action text not null, before jsonb, after jsonb, created_at timestamptz not null default now()
);

alter table public.profiles enable row level security;
alter table public.caregiver_patient enable row level security;
alter table public.medications enable row level security;
alter table public.medication_schedules enable row level security;
alter table public.dose_instances enable row level security;
alter table public.dose_events enable row level security;
alter table public.reminder_policies enable row level security;
alter table public.devices enable row level security;
alter table public.caregiver_alerts enable row level security;
alter table public.audit_logs enable row level security;

create policy "profiles_select_own_or_linked" on public.profiles for select using (id = auth.uid() or public.is_caregiver_of(id));
create policy "profiles_update_own" on public.profiles for update using (id = auth.uid());
create policy "caregiver_patient_select" on public.caregiver_patient for select using (caregiver_id = auth.uid() or patient_id = auth.uid());
create policy "caregiver_patient_insert" on public.caregiver_patient for insert with check (caregiver_id = auth.uid());
create policy "caregiver_patient_delete" on public.caregiver_patient for delete using (caregiver_id = auth.uid() or patient_id = auth.uid());
create policy "medications_select" on public.medications for select using (patient_id = auth.uid() or public.is_caregiver_of(patient_id));
create policy "medications_write" on public.medications for all using (public.can_edit_patient(patient_id)) with check (public.can_edit_patient(patient_id));
create policy "schedules_select" on public.medication_schedules for select using (exists (select 1 from public.medications m where m.id = medication_id and (m.patient_id = auth.uid() or public.is_caregiver_of(m.patient_id))));
create policy "schedules_write" on public.medication_schedules for all using (exists (select 1 from public.medications m where m.id = medication_id and public.can_edit_patient(m.patient_id))) with check (exists (select 1 from public.medications m where m.id = medication_id and public.can_edit_patient(m.patient_id)));
create policy "doses_select" on public.dose_instances for select using (patient_id = auth.uid() or public.is_caregiver_of(patient_id));
create policy "doses_write" on public.dose_instances for all using (public.can_edit_patient(patient_id)) with check (public.can_edit_patient(patient_id));
create policy "dose_events_select" on public.dose_events for select using (patient_id = auth.uid() or public.is_caregiver_of(patient_id));
create policy "dose_events_insert" on public.dose_events for insert with check (patient_id = auth.uid() or public.is_caregiver_of(patient_id));
create policy "reminder_policies_all" on public.reminder_policies for all using (patient_id = auth.uid() or public.is_caregiver_of(patient_id)) with check (patient_id = auth.uid() or public.can_edit_patient(patient_id));
create policy "devices_own" on public.devices for all using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "caregiver_alerts_select" on public.caregiver_alerts for select using (caregiver_id = auth.uid());
create policy "caregiver_alerts_update" on public.caregiver_alerts for update using (caregiver_id = auth.uid());
create policy "audit_logs_select" on public.audit_logs for select using (actor_id = auth.uid() or public.is_caregiver_of(entity_id));

alter publication supabase_realtime add table public.dose_instances;
alter publication supabase_realtime add table public.caregiver_alerts;
