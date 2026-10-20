-- Supabase grants newly exposed functions to API roles by default. Keep the
-- two SECURITY DEFINER mutation RPCs callable only after authentication; both
-- also enforce the admin allowlist and MFA AAL2 inside their bodies.
revoke all on function public.admin_save_catalog_family(jsonb)
  from public, anon, authenticated;
revoke all on function public.admin_delete_catalog_family(text)
  from public, anon, authenticated;
grant execute on function public.admin_save_catalog_family(jsonb) to authenticated;
grant execute on function public.admin_delete_catalog_family(text) to authenticated;

-- This function exists only as a catalog-table trigger target and must never
-- be an API endpoint.
revoke all on function public.bump_catalog_version()
  from public, anon, authenticated;
