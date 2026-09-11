-- Prevent duplicate caregiver escalation alerts for the same dose/caregiver/type.
-- This is the database-level idempotency guard for scheduled escalation runs.
create unique index if not exists caregiver_alerts_dose_caregiver_type_uidx
  on public.caregiver_alerts (dose_id, caregiver_id, type)
  where dose_id is not null;
