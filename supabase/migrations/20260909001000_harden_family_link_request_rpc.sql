-- DawaCare: harden the 3-argument family-link request RPC.
--
-- The live database already exposes request_family_link(text,text,text), but the
-- function was left STABLE by CREATE OR REPLACE even though it performs UPDATE
-- and INSERT. It also retained PostgreSQL's default PUBLIC EXECUTE privilege.
-- This migration makes the mutating RPC VOLATILE and explicitly limits EXECUTE
-- to authenticated callers.

alter function public.request_family_link(text, text, text)
  volatile;

revoke all on function public.request_family_link(text, text, text) from public;
revoke all on function public.request_family_link(text, text, text) from anon;
grant execute on function public.request_family_link(text, text, text) to authenticated;

-- Keep the function's authorization boundary explicit. The RPC is SECURITY
-- DEFINER because it atomically consumes a family-link code and creates the
-- pending request, but it must only operate for an authenticated caller.
create or replace function public.request_family_link(
  p_code text,
  p_relationship_label text default null,
  p_role text default 'CAREGIVER'
)
returns table (request_id uuid, patient_id uuid, patient_name text)
language plpgsql
volatile
security definer
set search_path = public
as $$
declare
  v_code_row public.family_link_codes%rowtype;
  v_patient_name text;
  v_request_id uuid;
  v_role text := upper(trim(coalesce(p_role, 'CAREGIVER')));
begin
  if auth.uid() is null then
    raise exception 'AUTH_REQUIRED';
  end if;

  if v_role not in ('PRIMARY_CAREGIVER', 'CAREGIVER', 'VIEWER') then
    raise exception 'INVALID_FAMILY_ROLE';
  end if;

  select fc.*
    into v_code_row
    from public.family_link_codes fc
   where fc.code = upper(trim(p_code))
     and fc.used = false
     and fc.expires_at > now()
   order by fc.created_at desc
   limit 1;

  if v_code_row.id is null then
    raise exception 'CODE_INVALID_OR_EXPIRED';
  end if;

  if v_code_row.patient_id = auth.uid() then
    raise exception 'CANNOT_LINK_SELF';
  end if;

  if exists (
    select 1
      from public.caregiver_patient cp
     where cp.patient_id = v_code_row.patient_id
       and cp.caregiver_id = auth.uid()
  ) then
    raise exception 'ALREADY_LINKED';
  end if;

  if exists (
    select 1
      from public.family_link_requests flr
     where flr.patient_id = v_code_row.patient_id
       and flr.caregiver_id = auth.uid()
       and flr.status = 'PENDING'
  ) then
    raise exception 'REQUEST_ALREADY_PENDING';
  end if;

  update public.family_link_codes
     set used = true,
         used_by = auth.uid()
   where id = v_code_row.id
     and used = false;

  if not found then
    raise exception 'CODE_ALREADY_USED';
  end if;

  insert into public.family_link_requests
    (code_id, patient_id, caregiver_id, relationship_label, role, status)
  values
    (v_code_row.id,
     v_code_row.patient_id,
     auth.uid(),
     nullif(trim(p_relationship_label), ''),
     v_role,
     'PENDING')
  returning id into v_request_id;

  select p.full_name
    into v_patient_name
    from public.profiles p
   where p.id = v_code_row.patient_id;

  return query
    select v_request_id,
           v_code_row.patient_id,
           coalesce(v_patient_name, 'مريض');
end;
$$;

revoke all on function public.request_family_link(text, text, text) from public;
revoke all on function public.request_family_link(text, text, text) from anon;
grant execute on function public.request_family_link(text, text, text) to authenticated;
