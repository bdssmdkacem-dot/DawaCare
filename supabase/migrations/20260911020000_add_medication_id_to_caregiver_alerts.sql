-- Keep caregiver alerts directly addressable to the medication that caused them.
-- Existing alerts remain valid because the column is nullable.
alter table public.caregiver_alerts
  add column if not exists medication_id uuid references public.medications (id) on delete cascade;

create index if not exists idx_caregiver_alerts_medication_id
  on public.caregiver_alerts (medication_id);
