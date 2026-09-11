-- Prevent duplicate caregiver alerts when cron retries or two workers race.
create unique index if not exists caregiver_alerts_dose_caregiver_type_uidx
  on public.caregiver_alerts (dose_id, caregiver_id, type);
