-- Fix ambiguous PL/pgSQL OUT-parameter names by qualifying every table
-- reference. This is the live-tested correction for the family-link RPCs.

create or replace function public.create_family_link_code()
returns table (code text, expires_at timestamptz)
language plpgsql
security definer set search_path = public
as $$
declare
  new_code text;
  new_expiry timestamptz := now() + interval '15 minutes';
  attempts int := 0;
begin
  update public.family_link_codes fc
     set used = true
   where fc.patient_id = auth.uid() and fc.used = false and fc.expires_at > now();

  loop
    new_code := lpad(floor(random() * 1000000)::text, 6, '0');
    exit when not exists (
      select 1 from public.family_link_codes fc where fc.code = new_code and fc.used = false
    ) or attempts > 20;
    attempts := attempts + 1;
  end loop;

  insert into public.family_link_codes (patient_id, code, expires_at)
  values (auth.uid(), new_code, new_expiry);

  return query select new_code, new_expiry;
end;
$$;

create or replace function public.request_family_link(p_code text, p_relationship_label text default null)
returns table (request_id uuid, patient_id uuid, patient_name text)
language plpgsql
security definer set search_path = public
as $$
declare
  v_code_row public.family_link_codes%rowtype;
  v_patient_name text;
  v_request_id uuid;
begin
  select fc.* into v_code_row
  from public.family_link_codes fc
  where fc.code = upper(trim(p_code)) and fc.used = false and fc.expires_at > now()
  order by fc.created_at desc
  limit 1;

  if v_code_row.id is null then raise exception 'CODE_INVALID_OR_EXPIRED'; end if;
  if v_code_row.patient_id = auth.uid() then raise exception 'CANNOT_LINK_SELF'; end if;

  if exists (
    select 1 from public.caregiver_patient cp
    where cp.patient_id = v_code_row.patient_id and cp.caregiver_id = auth.uid()
  ) then raise exception 'ALREADY_LINKED'; end if;

  if exists (
    select 1 from public.family_link_requests flr
    where flr.patient_id = v_code_row.patient_id and flr.caregiver_id = auth.uid() and flr.status = 'PENDING'
  ) then raise exception 'REQUEST_ALREADY_PENDING'; end if;

  update public.family_link_codes fc set used = true, used_by = auth.uid() where fc.id = v_code_row.id;

  insert into public.family_link_requests (code_id, patient_id, caregiver_id, relationship_label, role, status)
  values (v_code_row.id, v_code_row.patient_id, auth.uid(), nullif(trim(p_relationship_label), ''), 'CAREGIVER', 'PENDING')
  returning id into v_request_id;

  select p.full_name into v_patient_name from public.profiles p where p.id = v_code_row.patient_id;
  return query select v_request_id, v_code_row.patient_id, coalesce(v_patient_name, 'مريض');
end;
$$;

create or replace function public.respond_family_link_request(p_request_id uuid, p_approve boolean)
returns table (status text)
language plpgsql
security definer set search_path = public
as $$
declare
  v_req public.family_link_requests%rowtype;
  v_new_status text;
begin
  select flr.* into v_req
  from public.family_link_requests flr
  where flr.id = p_request_id and flr.patient_id = auth.uid() and flr.status = 'PENDING';

  if v_req.id is null then raise exception 'REQUEST_NOT_FOUND'; end if;

  v_new_status := case when p_approve then 'APPROVED' else 'REJECTED' end;

  update public.family_link_requests flr
     set status = v_new_status, responded_at = now()
   where flr.id = p_request_id;

  if p_approve then
    insert into public.caregiver_patient (caregiver_id, patient_id, role, relationship_label)
    values (v_req.caregiver_id, v_req.patient_id, v_req.role, v_req.relationship_label)
    on conflict (caregiver_id, patient_id) do nothing;
  end if;

  return query select v_new_status;
end;
$$;

create or replace function public.cancel_family_link_request(p_request_id uuid)
returns void
language plpgsql
security definer set search_path = public
as $$
begin
  update public.family_link_requests flr
     set status = 'CANCELLED', responded_at = now()
   where flr.id = p_request_id and flr.caregiver_id = auth.uid() and flr.status = 'PENDING';

  if not found then raise exception 'REQUEST_NOT_FOUND'; end if;
end;
$$;

-- SECURITY DEFINER functions default to EXECUTE for PUBLIC in PostgreSQL.
-- Restrict these access-control RPCs to signed-in users only.
revoke execute on function public.create_family_link_code() from public;
revoke execute on function public.request_family_link(text, text) from public;
revoke execute on function public.respond_family_link_request(uuid, boolean) from public;
revoke execute on function public.cancel_family_link_request(uuid) from public;
revoke execute on function public.is_linked_or_pending_with(uuid) from public;

grant execute on function public.create_family_link_code() to authenticated;
grant execute on function public.request_family_link(text, text) to authenticated;
grant execute on function public.respond_family_link_request(uuid, boolean) to authenticated;
grant execute on function public.cancel_family_link_request(uuid) to authenticated;
