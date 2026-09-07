create table if not exists public.push_notification_events (
  id uuid primary key default gen_random_uuid(),
  event_key text not null unique,
  event_type text not null,
  request_id uuid null references public.family_link_requests(id) on delete cascade,
  sender_id uuid not null,
  recipient_id uuid not null,
  created_at timestamptz not null default now(),
  sent_at timestamptz null,
  sent_count integer not null default 0
);

alter table public.push_notification_events enable row level security;

create index if not exists push_notification_events_recipient_idx on public.push_notification_events(recipient_id, created_at desc);

create policy "users can read own push notification events"
on public.push_notification_events
for select to authenticated
using (sender_id = auth.uid() or recipient_id = auth.uid());

create or replace function public.family_link_push_event(p_request_id uuid, p_event_type text)
returns table(event_key text, sender_id uuid, recipient_id uuid, status text)
language plpgsql
security definer
set search_path = public
as $$
declare
  r family_link_requests%rowtype;
  k text;
  s uuid;
  recipient uuid;
begin
  select * into r from family_link_requests where id = p_request_id;
  if r.id is null then raise exception 'REQUEST_NOT_FOUND'; end if;
  if p_event_type = 'REQUESTED' then
    if r.caregiver_id <> auth.uid() then raise exception 'FORBIDDEN'; end if;
    s := r.caregiver_id; recipient := r.patient_id;
  elsif p_event_type in ('APPROVED', 'REJECTED') then
    if r.patient_id <> auth.uid() then raise exception 'FORBIDDEN'; end if;
    s := r.patient_id; recipient := r.caregiver_id;
  else
    raise exception 'INVALID_EVENT_TYPE';
  end if;
  k := 'family-link:' || p_event_type || ':' || r.id::text;
  insert into push_notification_events(event_key, event_type, request_id, sender_id, recipient_id)
  values(k, p_event_type, r.id, s, recipient)
  on conflict(event_key) do nothing;
  return query select k, s, recipient, 'READY';
end;
$$;
