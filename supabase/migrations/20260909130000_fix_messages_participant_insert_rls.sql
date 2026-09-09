-- Allow bidirectional patient/caregiver messaging and caregiver-to-caregiver messaging.
-- A caregiver relationship is anchored to the same patient_id.

drop policy if exists messages_insert_participants on public.messages;

create policy messages_insert_participants
on public.messages
as permissive
for insert
to authenticated
with check (
  (select auth.uid()) = sender_id
  and (
    -- Patient -> linked caregiver
    (
      sender_id = patient_id
      and exists (
        select 1
        from public.caregiver_patient cp
        where cp.patient_id = messages.patient_id
          and cp.caregiver_id = messages.recipient_id
      )
    )
    or
    -- Caregiver/Viewer -> patient
    (
      recipient_id = patient_id
      and exists (
        select 1
        from public.caregiver_patient cp
        where cp.patient_id = messages.patient_id
          and cp.caregiver_id = messages.sender_id
      )
    )
    or
    -- Caregiver/Viewer -> another caregiver/viewer linked to the same patient
    (
      sender_id <> patient_id
      and recipient_id <> patient_id
      and exists (
        select 1
        from public.caregiver_patient sender_link
        where sender_link.patient_id = messages.patient_id
          and sender_link.caregiver_id = messages.sender_id
      )
      and exists (
        select 1
        from public.caregiver_patient recipient_link
        where recipient_link.patient_id = messages.patient_id
          and recipient_link.caregiver_id = messages.recipient_id
      )
    )
  )
);
