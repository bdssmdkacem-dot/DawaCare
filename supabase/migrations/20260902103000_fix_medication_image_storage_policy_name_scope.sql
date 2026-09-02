-- Fix Storage policy name scoping.
-- In policies on storage.objects, explicitly qualify storage.objects.name
-- so PostgreSQL cannot resolve `name` against public.medications.

drop policy if exists "medication_images_insert_editors" on storage.objects;
drop policy if exists "medication_images_update_editors" on storage.objects;
drop policy if exists "medication_images_delete_editors" on storage.objects;

create policy "medication_images_insert_editors"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'medication-images'
  and split_part(storage.objects.name, '/', 1) ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
  and split_part(storage.objects.name, '/', 2) ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
  and exists (
    select 1
    from public.medications m
    where m.id = split_part(storage.objects.name, '/', 2)::uuid
      and m.patient_id = split_part(storage.objects.name, '/', 1)::uuid
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
    select 1
    from public.medications m
    where m.id = split_part(storage.objects.name, '/', 2)::uuid
      and m.patient_id = split_part(storage.objects.name, '/', 1)::uuid
      and can_edit_patient(m.patient_id)
  )
)
with check (
  bucket_id = 'medication-images'
  and exists (
    select 1
    from public.medications m
    where m.id = split_part(storage.objects.name, '/', 2)::uuid
      and m.patient_id = split_part(storage.objects.name, '/', 1)::uuid
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
    select 1
    from public.medications m
    where m.id = split_part(storage.objects.name, '/', 2)::uuid
      and m.patient_id = split_part(storage.objects.name, '/', 1)::uuid
      and can_edit_patient(m.patient_id)
  )
);
