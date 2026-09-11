-- Atomically applies a dose lifecycle transition and records its event.
-- Returning applied=false with the current status lets offline replay
-- distinguish an already-applied intent from a permanent lifecycle conflict.
create or replace function public.apply_dose_status_transition(
  p_dose_id uuid,
  p_patient_id uuid,
  p_to_status text,
  p_source text default 'PATIENT'
)
returns table(applied boolean, current_status text)
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_current text;
  v_allowed boolean := false;
begin
  if p_source not in ('PATIENT', 'CAREGIVER', 'SYSTEM') then
    raise exception 'INVALID_DOSE_EVENT_SOURCE';
  end if;

  if p_to_status not in ('PENDING','REMINDER_SENT','SNOOZED','TAKEN','MISSED','SKIPPED','CANCELLED') then
    raise exception 'INVALID_DOSE_STATUS';
  end if;

  select d.status
    into v_current
    from public.dose_instances d
   where d.id = p_dose_id
     and d.patient_id = p_patient_id
   for update;

  if v_current is null then
    raise exception 'DOSE_NOT_FOUND';
  end if;

  if v_current = p_to_status then
    return query select false, v_current;
    return;
  end if;

  v_allowed := case v_current
    when 'PENDING' then p_to_status in ('REMINDER_SENT','SNOOZED','TAKEN','SKIPPED','CANCELLED','MISSED')
    when 'REMINDER_SENT' then p_to_status in ('SNOOZED','TAKEN','SKIPPED','CANCELLED','MISSED')
    when 'SNOOZED' then p_to_status in ('REMINDER_SENT','TAKEN','SKIPPED','CANCELLED','MISSED')
    when 'MISSED' then p_to_status = 'TAKEN'
    else false
  end;

  if not v_allowed then
    return query select false, v_current;
    return;
  end if;

  update public.dose_instances
     set status = p_to_status,
         updated_at = now()
   where id = p_dose_id
     and patient_id = p_patient_id;

  insert into public.dose_events (dose_id, patient_id, action, source)
  values (p_dose_id, p_patient_id, p_to_status, p_source);

  return query select true, p_to_status;
end;
$$;

revoke execute on function public.apply_dose_status_transition(uuid, uuid, text, text) from public, anon;
grant execute on function public.apply_dose_status_transition(uuid, uuid, text, text) to authenticated;
