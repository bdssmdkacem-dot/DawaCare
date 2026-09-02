-- Restrict application RPCs/helpers to authenticated users.
-- SECURITY DEFINER does not mean anonymous callers should have EXECUTE.

revoke execute on function public.can_edit_patient(uuid) from public, anon;
revoke execute on function public.cancel_family_link_request(uuid) from public, anon;
revoke execute on function public.create_family_link_code() from public, anon;
revoke execute on function public.handle_new_user() from public, anon;
revoke execute on function public.is_caregiver_of(uuid) from public, anon;
revoke execute on function public.is_linked_or_pending_with(uuid) from public, anon;
revoke execute on function public.request_family_link(text, text) from public, anon;
revoke execute on function public.respond_family_link_request(uuid, boolean) from public, anon;

grant execute on function public.can_edit_patient(uuid) to authenticated;
grant execute on function public.cancel_family_link_request(uuid) to authenticated;
grant execute on function public.create_family_link_code() to authenticated;
grant execute on function public.handle_new_user() to authenticated;
grant execute on function public.is_caregiver_of(uuid) to authenticated;
grant execute on function public.is_linked_or_pending_with(uuid) to authenticated;
grant execute on function public.request_family_link(text, text) to authenticated;
grant execute on function public.respond_family_link_request(uuid, boolean) to authenticated;
