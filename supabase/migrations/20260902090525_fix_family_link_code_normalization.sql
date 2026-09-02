-- Normalize family-link codes at the RPC boundary.
-- Accept pasted formatting and Arabic-Indic / Extended Arabic-Indic digits.
-- Consume the code only after all validation succeeds.

create or replace function public.request_family_link(p_code text, p_relationship_label text default null)
returns table (request_id uuid, patient_id uuid, patient_name text)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_code_row public.family_link_codes%rowtype;
  v_patient_name text;
  v_request_id uuid;
  v_normalized_code text;
begin
  v_normalized_code := translate(
    regexp_replace(coalesce(p_code, ''), '[^0-9٠-٩۰-۹]', '', 'g'),
    '٠١٢٣٤٥٦٧٨٩۰۱۲۳۴۵۶۷۸۹',
    '01234567890123456789'
  );

  if length(v_normalized_code) <> 6 then
    raise exception 'CODE_INVALID_OR_EXPIRED';
  end if;

  select fc.* into v_code_row
  from public.family_link_codes fc
  where fc.code = v_normalized_code
    and fc.used = false
    and fc.expires_at > now()
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
    where flr.patient_id = v_code_row.patient_id
      and flr.caregiver_id = auth.uid()
      and flr.status = 'PENDING'
  ) then raise exception 'REQUEST_ALREADY_PENDING'; end if;

  update public.family_link_codes fc
     set used = true, used_by = auth.uid()
   where fc.id = v_code_row.id and fc.used = false;

  if not found then raise exception 'CODE_INVALID_OR_EXPIRED'; end if;

  insert into public.family_link_requests (
    code_id, patient_id, caregiver_id, relationship_label, role, status
  )
  values (
    v_code_row.id,
    v_code_row.patient_id,
    auth.uid(),
    nullif(trim(p_relationship_label), ''),
    'CAREGIVER',
    'PENDING'
  )
  returning id into v_request_id;

  select p.full_name into v_patient_name
  from public.profiles p
  where p.id = v_code_row.patient_id;

  return query
    select v_request_id, v_code_row.patient_id, coalesce(v_patient_name, 'مريض');
end;
$$;

revoke execute on function public.request_family_link(text, text) from public;
grant execute on function public.request_family_link(text, text) to authenticated;
