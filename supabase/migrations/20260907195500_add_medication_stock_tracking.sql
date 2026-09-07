alter table public.medications add column if not exists stock_enabled boolean not null default false;

create or replace function public.sync_medication_stock_from_dose()
returns trigger language plpgsql security invoker set search_path = public as $$
declare v_amount numeric; v_delta numeric;
begin
  if not exists (select 1 from public.medications m where m.id = new.medication_id and m.stock_enabled) then return new; end if;
  v_amount := substring(coalesce(new.dose_amount, '') from '([0-9]+(?:\.[0-9]+)?)')::numeric;
  if v_amount is null or v_amount <= 0 then return new; end if;
  if (old.status is distinct from 'TAKEN') and new.status = 'TAKEN' then
    v_delta := -v_amount;
  elsif old.status = 'TAKEN' and new.status is distinct from 'TAKEN' then
    v_delta := v_amount;
  else return new;
  end if;
  update public.medications set stock_quantity = stock_quantity + v_delta where id = new.medication_id and stock_quantity + v_delta >= 0;
  if not found then raise exception 'INSUFFICIENT_MEDICATION_STOCK'; end if;
  insert into public.medication_stock_transactions(medication_id, patient_id, quantity, transaction_type, dose_id, note, created_by)
  values (new.medication_id, new.patient_id, v_delta, case when v_delta < 0 then 'TAKEN' else 'ADJUSTMENT' end, new.id, 'Automatic stock sync from dose status', auth.uid());
  return new;
end;
$$;

drop trigger if exists trg_sync_medication_stock_from_dose on public.dose_instances;
create trigger trg_sync_medication_stock_from_dose after update of status on public.dose_instances for each row execute function public.sync_medication_stock_from_dose();
revoke all on function public.sync_medication_stock_from_dose() from public;
