create table if not exists public.medication_stock_transactions (
  id uuid primary key default gen_random_uuid(),
  medication_id uuid not null references public.medications(id) on delete cascade,
  patient_id uuid not null references public.profiles(id) on delete cascade,
  quantity numeric(12,3) not null,
  transaction_type text not null check (transaction_type in ('INITIAL','ADD','TAKEN','ADJUSTMENT')),
  dose_id uuid null references public.dose_instances(id) on delete set null,
  note text null,
  created_by uuid not null references auth.users(id) on delete restrict,
  created_at timestamptz not null default now()
);

alter table public.medications
  add column if not exists stock_quantity numeric(12,3) not null default 0,
  add column if not exists stock_unit text not null default 'unit',
  add column if not exists package_quantity numeric(12,3) null,
  add column if not exists low_stock_threshold numeric(12,3) not null default 5;

alter table public.medication_stock_transactions enable row level security;

create index if not exists idx_medication_stock_transactions_medication on public.medication_stock_transactions(medication_id, created_at desc);
create index if not exists idx_medication_stock_transactions_patient on public.medication_stock_transactions(patient_id, created_at desc);

create or replace function public.apply_medication_stock_transaction(p_medication_id uuid, p_patient_id uuid, p_quantity numeric, p_transaction_type text, p_dose_id uuid default null, p_note text default null)
returns numeric language plpgsql security invoker set search_path = public as $$
declare v_stock numeric(12,3);
begin
  if p_quantity = 0 then raise exception 'STOCK_QUANTITY_ZERO'; end if;
  if p_transaction_type not in ('INITIAL','ADD','TAKEN','ADJUSTMENT') then raise exception 'INVALID_STOCK_TRANSACTION'; end if;
  if not exists (select 1 from public.medications m where m.id = p_medication_id and m.patient_id = p_patient_id) then raise exception 'MEDICATION_NOT_FOUND'; end if;
  select stock_quantity into v_stock from public.medications where id = p_medication_id for update;
  if p_transaction_type = 'TAKEN' and p_quantity >= 0 then raise exception 'TAKEN_QUANTITY_MUST_BE_NEGATIVE'; end if;
  if p_transaction_type in ('INITIAL','ADD') and p_quantity <= 0 then raise exception 'ADD_QUANTITY_MUST_BE_POSITIVE'; end if;
  if v_stock + p_quantity < 0 then raise exception 'INSUFFICIENT_MEDICATION_STOCK'; end if;
  update public.medications set stock_quantity = v_stock + p_quantity where id = p_medication_id;
  insert into public.medication_stock_transactions(medication_id, patient_id, quantity, transaction_type, dose_id, note, created_by)
  values (p_medication_id, p_patient_id, p_quantity, p_transaction_type, p_dose_id, p_note, auth.uid());
  return v_stock + p_quantity;
end;
$$;

revoke all on function public.apply_medication_stock_transaction(uuid,uuid,numeric,text,uuid,text) from public;
grant execute on function public.apply_medication_stock_transaction(uuid,uuid,numeric,text,uuid,text) to authenticated;

create policy "Users can read own medication stock transactions" on public.medication_stock_transactions for select to authenticated using (patient_id = (select auth.uid()) or created_by = (select auth.uid()));
create policy "Users can insert own medication stock transactions" on public.medication_stock_transactions for insert to authenticated with check (created_by = (select auth.uid()) and patient_id = (select auth.uid()));
