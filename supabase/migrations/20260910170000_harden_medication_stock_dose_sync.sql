-- DawaCare — harden automatic stock deduction from taken doses.
--
-- Goals:
--  * support decimal doses written with either `2.5` or `2,5`;
--  * prefer the quantity immediately associated with the medication stock unit
--    (for example `2.5 ml`) instead of accidentally treating strength such as
--    `500 mg` as the consumed inventory quantity;
--  * keep stock changes idempotent per dose;
--  * preserve the existing Taken -> stock deduction / reversal behavior.

create unique index if not exists ux_medication_stock_taken_dose
  on public.medication_stock_transactions(dose_id)
  where transaction_type = 'TAKEN' and dose_id is not null;

create or replace function public.sync_medication_stock_from_dose()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_amount numeric;
  v_delta numeric;
  v_stock_unit text;
  v_dose_text text;
begin
  select m.stock_unit
    into v_stock_unit
  from public.medications m
  where m.id = new.medication_id
    and m.stock_enabled;

  if v_stock_unit is null then
    return new;
  end if;

  v_dose_text := trim(coalesce(new.dose_amount, ''));

  -- Prefer a number directly associated with the configured stock unit.
  -- This avoids interpreting `500 mg` as 500 tablets when stock_unit=tablet.
  if v_stock_unit <> '' then
    v_amount := replace(
      substring(
        v_dose_text
        from '([0-9]+(?:[.,][0-9]+)?)\s*' || regexp_replace(lower(v_stock_unit), '([\\.\\+\\*\\?\\[\\]\\(\\)\\{\\}\\|\\^\\$\\\\])', '\\\\1', 'g') || '\\b'
      ),
      ',',
      '.'
    )::numeric;
  end if;

  -- If the configured unit is not present in the dose text, keep the legacy
  -- behavior as a fallback. Decimal comma is normalized here as well.
  if v_amount is null then
    v_amount := replace(
      substring(v_dose_text from '([0-9]+(?:[.,][0-9]+)?)'),
      ',',
      '.'
    )::numeric;
  end if;

  if v_amount is null or v_amount <= 0 then
    return new;
  end if;

  if (old.status is distinct from 'TAKEN') and new.status = 'TAKEN' then
    v_delta := -v_amount;
  elsif old.status = 'TAKEN' and new.status is distinct from 'TAKEN' then
    v_delta := v_amount;
  else
    return new;
  end if;

  update public.medications
     set stock_quantity = stock_quantity + v_delta
   where id = new.medication_id
     and stock_quantity + v_delta >= 0;

  if not found then
    raise exception 'INSUFFICIENT_MEDICATION_STOCK';
  end if;

  insert into public.medication_stock_transactions(
    medication_id,
    patient_id,
    quantity,
    transaction_type,
    dose_id,
    note,
    created_by
  )
  values (
    new.medication_id,
    new.patient_id,
    v_delta,
    case when v_delta < 0 then 'TAKEN' else 'ADJUSTMENT' end,
    new.id,
    'Automatic stock sync from dose status',
    auth.uid()
  )
  on conflict (dose_id) where transaction_type = 'TAKEN' and dose_id is not null
  do nothing;

  return new;
end;
$$;

revoke all on function public.sync_medication_stock_from_dose() from public;
