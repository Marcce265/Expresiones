-- Additional performance indexes for common query patterns and relational joins.
-- All statements are idempotent (IF NOT EXISTS).

-- Speed up category-filtered active catalog family queries
create index if not exists families_category_active_idx
  on public.families (category_id, active);

-- Speed up active variant lookups across all families
create index if not exists variants_active_idx
  on public.variants (active);

-- Speed up administrative audit log filtering by resource
create index if not exists admin_audit_logs_resource_idx
  on public.admin_audit_logs (resource_type, resource_id, created_at desc);

-- Speed up customer orders status dashboard filtering
create index if not exists customer_orders_status_idx
  on public.customer_orders (status, created_at desc);
