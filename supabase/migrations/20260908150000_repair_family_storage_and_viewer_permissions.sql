-- DawaCare — repair family-link RPC, restore required Storage buckets,
-- and make VIEWER read-only while still allowing family communication.

-- ---------------------------------------------------------------------------
-- Family-link RPC: the Flutter client sends a requested role. The previous
-- database function accepted only (code, relationship), causing RPC signature
-- mismatch whenever the client supplied p_role.
-- ---------------------------------------------------------------------------

drop function if exists public.request_family_link(text, text);

create or replace function public.request_family_link(
  p_code text,
  p_relationship_label text default null,
  p_role text default 'CAREGIVER'
)
returns table (request_id uuid, patient_id uuid, patient_name text)
language plpgsql
security definer set search_path = public
as $$
declare
  v_code_row public.family_link_codes%rowtype;
  v_patient_name text;
  v_request_id uuid;
  v_role text := upper(trim(coalesce(p_role, 'CAREGIVER')));
begin
  if v_role not in ('PRIMARY_CAREGIVER', 'CAREGIVER', 'VIEWER') then
    raise exception 'INVALID_FAMILY_ROLE';
  end if;

  select fc.* into v_code_row
  from public.family_link_codes fc
  where fc.code = upper(trim(p_code))
    and fc.used = false
    and fc.expires_at > now()
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
    where flr.patient_id = v_code_row.patient_id
      and flr.caregiver_id = auth.uid()
      and flr.status = 'PENDING'
  ) then raise exception 'REQUEST_ALREADY_PENDING'; end if;

  update public.family_link_codes fc
     set used = true, used_by = auth.uid()
   where fc.id = v_code_row.id;

  insert into public.family_link_requests
    (code_id, patient_id, caregiver_id, relationship_label, role, status)
  values
    (v_code_row.id, v_code_row.patient_id, auth.uid(),
     nullif(trim(p_relationship_label), ''), v_role, 'PENDING')
  returning id into v_request_id;

  select p.full_name into v_patient_name
    from public.profiles p
   where p.id = v_code_row.patient_id;

  return query
    select v_request_id, v_code_row.patient_id, coalesce(v_patient_name, 'مريض');
end;
$$;

grant execute on function public.request_family_link(text, text, text) to authenticated;

-- ---------------------------------------------------------------------------
-- Storage buckets may have been manually emptied/deleted during the test reset.
-- Recreate them idempotently so a future migration/run restores the runtime
-- contract instead of relying on dashboard state.
-- ---------------------------------------------------------------------------

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('profile-avatars', 'profile-avatars', true, 5242880,
        array['image/jpeg','image/png','image/webp']::text[])
on conflict (id) do update
set public = true,
    file_size_limit = 5242880,
    allowed_mime_types = excluded.allowed_mime_types;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('medication-images', 'medication-images', false, 5242880,
        array['image/jpeg','image/png','image/webp']::text[])
on conflict (id) do update
set public = false,
    file_size_limit = 5242880,
    allowed_mime_types = excluded.allowed_mime_types;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('voice-messages', 'voice-messages', false, 10485760,
        array['audio/mp4','audio/m4a','audio/aac','audio/mpeg','audio/wav','audio/x-m4a']::text[])
on conflict (id) do update
set public = false,
    file_size_limit = 10485760,
    allowed_mime_types = excluded.allowed_mime_types;

-- Recreate policies idempotently. Bucket existence alone is not sufficient for
-- authenticated uploads/downloads.

drop policy if exists "Profile avatars are publicly readable" on storage.objects;
drop policy if exists "Users can upload their own profile avatar" on storage.objects;
drop policy if exists "Users can update their own profile avatar" on storage.objects;
drop policy if exists "Users can delete their own profile avatar" on storage.objects;

create policy "Profile avatars are publicly readable"
on storage.objects for select
using (bucket_id = 'profile-avatars');

create policy "Users can upload their own profile avatar"
on storage.objects for insert to authenticated
with check (
  bucket_id = 'profile-avatars'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);

create policy "Users can update their own profile avatar"
on storage.objects for update to authenticated
using (
  bucket_id = 'profile-avatars'
  and (storage.foldername(name))[1] = (select auth.uid())::text
)
with check (
  bucket_id = 'profile-avatars'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);

create policy "Users can delete their own profile avatar"
on storage.objects for delete to authenticated
using (
  bucket_id = 'profile-avatars'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);

drop policy if exists "medication_images_select_linked" on storage.objects;
drop policy if exists "medication_images_insert_editors" on storage.objects;
drop policy if exists "medication_images_update_editors" on storage.objects;
drop policy if exists "medication_images_delete_editors" on storage.objects;

create policy "medication_images_select_linked"
on storage.objects for select to authenticated
using (
  bucket_id = 'medication-images'
  and split_part(name, '/', 1) ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
  and public.is_linked_or_pending_with(split_part(name, '/', 1)::uuid)
);

create policy "medication_images_insert_editors"
on storage.objects for insert to authenticated
with check (
  bucket_id = 'medication-images'
  and split_part(name, '/', 1) ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
  and split_part(name, '/', 2) ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
  and exists (
    select 1 from public.medications m
    where m.id = split_part(name, '/', 2)::uuid
      and m.patient_id = split_part(name, '/', 1)::uuid
      and public.can_edit_patient(m.patient_id)
  )
);

create policy "medication_images_update_editors"
on storage.objects for update to authenticated
using (
  bucket_id = 'medication-images'
  and exists (
    select 1 from public.medications m
    where m.id = split_part(name, '/', 2)::uuid
      and m.patient_id = split_part(name, '/', 1)::uuid
      and public.can_edit_patient(m.patient_id)
  )
)
with check (
  bucket_id = 'medication-images'
  and exists (
    select 1 from public.medications m
    where m.id = split_part(name, '/', 2)::uuid
      and m.patient_id = split_part(name, '/', 1)::uuid
      and public.can_edit_patient(m.patient_id)
  )
);

create policy "medication_images_delete_editors"
on storage.objects for delete to authenticated
using (
  bucket_id = 'medication-images'
  and exists (
    select 1 from public.medications m
    where m.id = split_part(name, '/', 2)::uuid
      and m.patient_id = split_part(name, '/', 1)::uuid
      and public.can_edit_patient(m.patient_id)
  )
);

-- ---------------------------------------------------------------------------
-- Viewer role: read-only for medication/dose state, but still a full family
-- participant for profiles and text/voice communication.
-- ---------------------------------------------------------------------------

drop policy if exists "dose_events_insert" on public.dose_events;
create policy "dose_events_insert" on public.dose_events
for insert to authenticated
with check (
  patient_id = auth.uid()
  or public.can_edit_patient(patient_id)
);

-- Voice messages are allowed for VIEWER as requested. They still cannot edit
-- medication or dose state because those policies use can_edit_patient().
drop policy if exists voice_messages_insert_caregiver on public.voice_messages;
create policy voice_messages_insert_caregiver on public.voice_messages
for insert to authenticated with check (
  auth.uid() = sender_id and exists (
    select 1 from public.caregiver_patient cp
    where cp.patient_id = public.voice_messages.patient_id
      and cp.caregiver_id = auth.uid()
      and cp.role in ('PRIMARY_CAREGIVER', 'CAREGIVER', 'VIEWER')
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
      and cp.role in ('PRIMARY_CAREGIVER', 'CAREGIVER', 'VIEWER')
  )
  and (storage.foldername(storage.objects.name))[2] = auth.uid()::text
);

-- Keep the FCM/local notification channel name consistent across functions and
-- Flutter so Android does not route pushes to a non-existent channel.
