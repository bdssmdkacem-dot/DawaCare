-- DawaCare profile avatars: private ownership, public read URL for family UI.
insert into storage.buckets (id, name, public)
values ('profile-avatars', 'profile-avatars', true)
on conflict (id) do update set public = true;

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

-- Linked patients must be able to read their caregiver's profile metadata too.
create policy "profiles_select_linked_family_members"
on public.profiles for select
using (
  id = auth.uid()
  or exists (
    select 1
    from public.caregiver_patient cp
    where (cp.patient_id = auth.uid() and cp.caregiver_id = id)
       or (cp.caregiver_id = auth.uid() and cp.patient_id = id)
  )
);