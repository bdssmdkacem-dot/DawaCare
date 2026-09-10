-- DawaCare — make dose/stock reconciliation repeatable and consistent.
--
-- A dose may legitimately move TAKEN -> SKIPPED -> TAKEN (for example when a
-- caregiver corrects a status). A partial unique index on TAKEN transactions
-- cannot represent that history, so the old index is removed. The dose status
-- transition itself is the idempotency boundary: PostgreSQL fires this trigger
-- only when the status actually changes.

drop index if exists public.ux_medication_stock_taken_dose;

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
  v_unit_pos integer;
  v_before_unit text;
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

  -- Prefer the number immediately before the configured inventory unit.
  -- This avoids confusing medication strength with consumed inventory.
  v_unit_pos := strpos(lower(v_dose_text), lower(trim(v_stock_unit)));
  if v_unit_pos > 0 then
    v_before_unit := trim(substr(v_dose_text, 1, v_unit_pos - 1));
    v_amount := replace(
      substring(v_before_unit from '([0-9]+(?:[.,][0-9]+)?)\\s*$'),
      ',',
      '.'
    )::numeric;
  end if;

  -- Backward-compatible fallback for simple values such as `1`.
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

  -- Only real status transitions affect inventory. Repeating the same status
  -- update is therefore harmless and creates no duplicate stock movement.
  if (old.status is distinct from 'TAKEN') and new.status = 'TAKEN' then
    v_delta := -v_amount;
  elsif old.status = 'TAKEN' and new.status is distinct from 'TAKEN' then
    v_delta := v_amount;
  else
    return new;
  end if;

  -- Lock/update the medication row atomically and never allow negative stock.
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
    case
      when v_delta < 0 then 'Automatic stock deduction from taken dose'
      else 'Automatic stock reversal from dose status change'
    end,
    auth.uid()
  );

  return new;
end;
$$;

revoke all on function public.sync_medication_stock_from_dose() from public;
