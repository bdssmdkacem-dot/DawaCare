create table if not exists public.voice_messages (
  id uuid primary key default gen_random_uuid(),
  sender_id uuid not null references public.profiles(id) on delete cascade,
  patient_id uuid not null references public.profiles(id) on delete cascade,
  dose_id uuid null references public.dose_instances(id) on delete set null,
  storage_path text not null,
  duration_ms integer null,
  created_at timestamptz not null default now(),
  read_at timestamptz null
);

create index if not exists voice_messages_patient_created_idx on public.voice_messages(patient_id, created_at desc);
create index if not exists voice_messages_sender_created_idx on public.voice_messages(sender_id, created_at desc);

alter table public.voice_messages enable row level security;
grant select, insert, update on public.voice_messages to authenticated;

drop policy if exists voice_messages_select_participants on public.voice_messages;
create policy voice_messages_select_participants on public.voice_messages
for select to authenticated using (
  auth.uid() = patient_id or auth.uid() = sender_id or exists (
    select 1 from public.caregiver_patient cp
    where cp.patient_id = voice_messages.patient_id and cp.caregiver_id = auth.uid()
  )
);

drop policy if exists voice_messages_insert_caregiver on public.voice_messages;
create policy voice_messages_insert_caregiver on public.voice_messages
for insert to authenticated with check (
  auth.uid() = sender_id and exists (
    select 1 from public.caregiver_patient cp
    where cp.patient_id = voice_messages.patient_id
      and cp.caregiver_id = auth.uid()
      and cp.role in ('PRIMARY_CAREGIVER', 'CAREGIVER')
  )
);

drop policy if exists voice_messages_update_patient_read on public.voice_messages;
create policy voice_messages_update_patient_read on public.voice_messages
for update to authenticated using (auth.uid() = patient_id) with check (auth.uid() = patient_id);

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('voice-messages', 'voice-messages', false, 10485760,
        array['audio/mp4','audio/m4a','audio/aac','audio/mpeg','audio/wav','audio/x-m4a'])
on conflict (id) do update set public=false, file_size_limit=10485760, allowed_mime_types=excluded.allowed_mime_types;

drop policy if exists voice_messages_storage_select on storage.objects;
create policy voice_messages_storage_select on storage.objects
for select to authenticated using (
  bucket_id = 'voice-messages' and (
    exists (select 1 from public.voice_messages vm where vm.storage_path = storage.objects.name and (vm.patient_id = auth.uid() or vm.sender_id = auth.uid()))
    or exists (
      select 1 from public.voice_messages vm join public.caregiver_patient cp on cp.patient_id = vm.patient_id
      where vm.storage_path = storage.objects.name and cp.caregiver_id = auth.uid()
    )
  )
);

drop policy if exists voice_messages_storage_insert on storage.objects;
create policy voice_messages_storage_insert on storage.objects
for insert to authenticated with check (
  bucket_id = 'voice-messages'
  and exists (
    select 1 from public.caregiver_patient cp
    where cp.patient_id = (storage.foldername(storage.objects.name))[1]::uuid
      and cp.caregiver_id = auth.uid()
      and cp.role in ('PRIMARY_CAREGIVER', 'CAREGIVER')
  )
  and (storage.foldername(storage.objects.name))[2] = auth.uid()::text
);

drop policy if exists voice_messages_storage_delete on storage.objects;
create policy voice_messages_storage_delete on storage.objects
for delete to authenticated using (
  bucket_id = 'voice-messages' and exists (
    select 1 from public.voice_messages vm
    where vm.storage_path = storage.objects.name and vm.sender_id = auth.uid()
  )
);

alter table public.voice_messages replica identity full;
do $$ begin
  alter publication supabase_realtime add table public.voice_messages;
exception when duplicate_object then null;
end $$;
