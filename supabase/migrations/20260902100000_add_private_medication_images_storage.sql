insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'medication-images',
  'medication-images',
  false,
  5242880,
  array['image/jpeg','image/png','image/webp']::text[]
)
on conflict (id) do update
set public = false,
    file_size_limit = 5242880,
    allowed_mime_types = array['image/jpeg','image/png','image/webp']::text[];

create policy "medication_images_select_linked"
on storage.objects
for select
to authenticated
using (
  bucket_id = 'medication-images'
  and split_part(name, '/', 1) ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
  and is_linked_or_pending_with(split_part(name, '/', 1)::uuid)
);

create policy "medication_images_insert_editors"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'medication-images'
  and split_part(name, '/', 1) ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{3}$'
  and split_part(name, '/', 2) ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
  and exists (
    select 1 from public.medications m
    where m.id = split_part(name, '/', 2)::uuid
      and m.patient_id = split_part(name, '/', 1)::uuid
      and can_edit_patient(m.patient_id)
  )
);

create policy "medication_images_update_editors"
on storage.objects
for update
to authenticated
using (
  bucket_id = 'medication-images'
  and exists (
    select 1 from public.medications m
    where m.id = split_part(name, '/', 2)::uuid
      and m.patient_id = split_part(name, '/', 1)::uuid
      and can_edit_patient(m.patient_id)
  )
)
with check (
  bucket_id = 'medication-images'
  and exists (
    select 1 from public.medications m
    where m.id = split_part(name, '/', 2)::uuid
      and m.patient_id = split_part(name, '/', 1)::uuid
      and can_edit_patient(m.patient_id)
  )
);

create policy "medication_images_delete_editors"
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'medication-images'
  and exists (
    select 1 from public.medications m
    where m.id = split_part(name, '/', 2)::uuid
      and m.patient_id = split_part(name, '/', 1)::uuid
      and can_edit_patient(m.patient_id)
  )
);
