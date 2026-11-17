-- Endurecimiento de seguridad en base de datos:
-- 1. Activación explícita de RLS en las 13 tablas del esquema public.
-- 2. Revocación total de privilegios por defecto (REVOKE ALL) y concesión mínima
--    estricta (principio de menor privilegio) para anon y authenticated.
-- 3. Rate limiting por usuario en creación de órdenes (máx. 5 pedidos cada 10 minutos).
-- 4. Límite de tamaño de JSON snapshot (máx. 64 KB) para evitar bombas de datos.
-- 5. Bloqueo de payloads XSS / inyección de scripts en nombres, referencias y snapshots.
-- 6. Protección de actualización de perfiles de clientes.

-- ============================================================================
-- A. ACTIVAR RLS EN TODAS LAS TABLAS DEL ESQUEMA PUBLIC
-- ============================================================================
alter table public.categories enable row level security;
alter table public.families enable row level security;
alter table public.variants enable row level security;
alter table public.family_price_tiers enable row level security;
alter table public.variant_price_tiers enable row level security;
alter table public.admins enable row level security;
alter table public.catalog_metadata enable row level security;
alter table public.availability enable row level security;
alter table public.site_settings enable row level security;
alter table public.product_popularity enable row level security;
alter table public.admin_audit_logs enable row level security;
alter table public.customer_profiles enable row level security;
alter table public.customer_orders enable row level security;

-- ============================================================================
-- B. REVOCAR PRIVILEGIOS POR DEFECTO Y APLICAR PERMISOS MÍNIMOS (LEAST PRIVILEGE)
-- ============================================================================
revoke all on table
  public.categories,
  public.families,
  public.variants,
  public.family_price_tiers,
  public.variant_price_tiers,
  public.admins,
  public.catalog_metadata,
  public.availability,
  public.site_settings,
  public.product_popularity,
  public.admin_audit_logs,
  public.customer_profiles,
  public.customer_orders
from public, anon, authenticated;

-- 1. Visitantes públicos (anon) y usuarios autenticados: SOLO LECTURA en tablas del escaparate
grant select on table
  public.categories,
  public.families,
  public.variants,
  public.family_price_tiers,
  public.variant_price_tiers,
  public.catalog_metadata,
  public.availability,
  public.site_settings,
  public.product_popularity
to anon, authenticated;

-- 2. Escritura de catálogo/disponibilidad solo para rol authenticated (filtrado por RLS can_admin_write() con 2FA AAL2)
grant insert, update, delete on table
  public.categories,
  public.families,
  public.variants,
  public.family_price_tiers,
  public.variant_price_tiers,
  public.availability
to authenticated;

grant insert, update on table public.site_settings to authenticated;

-- 3. Auditoría: solo lectura para authenticated (filtrado por RLS can_admin_write()); nadie puede borrar ni editar logs
grant select on table public.admin_audit_logs to authenticated;

-- 4. Cuentas y pedidos de clientes: anon queda 100% bloqueado a nivel de tabla (HTTP 401 inmediato).
--    authenticated solo puede leer/actualizar su propio perfil y leer/insertar sus propios pedidos (nunca borrar).
grant select, update on table public.customer_profiles to authenticated;
grant select, insert on table public.customer_orders to authenticated;

create or replace function public.enforce_customer_order_security()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  recent_order_count integer;
  snapshot_text text;
  v_item jsonb;
  v_product_slug text;
  v_variant_slug text;
  v_item_qty integer;
  v_unit_price numeric(12, 2);
  v_line_total numeric(12, 2);
  v_sum_qty integer := 0;
  v_sum_total numeric(12, 2) := 0;
  v_family_id uuid;
  v_family_base_price numeric(12, 2);
  v_variant_id uuid;
  v_variant_price numeric(12, 2);
  v_family_total_qty integer;
  v_expected_price numeric(12, 2);
  v_payment_amount numeric(12, 2);
begin
  -- 1. Validar longitud y formato de campos escalares
  if char_length(btrim(coalesce(new.customer_name, ''))) < 2
     or char_length(new.customer_name) > 120 then
    raise exception using
      errcode = '22023',
      message = 'Nombre de cliente fuera del rango permitido.';
  end if;

  if new.customer_phone !~ '^[0-9]{9}$' then
    raise exception using
      errcode = '22023',
      message = 'Teléfono de cliente inválido.';
  end if;

  if new.total <= 0 or new.total > 100000 then
    raise exception using
      errcode = '22023',
      message = 'Monto total fuera del límite permitido.';
  end if;

  if new.total_quantity <= 0 or new.total_quantity > 10000 then
    raise exception using
      errcode = '22023',
      message = 'Cantidad total fuera del límite permitido.';
  end if;

  -- 2. Límite de tamaño del JSONB snapshot (máx. 64 KB) contra ataques de denegación de servicio
  snapshot_text := new.snapshot::text;
  if octet_length(snapshot_text) > 65536 then
    raise exception using
      errcode = '22023',
      message = 'El detalle del pedido excede el tamaño máximo permitido (64 KB).';
  end if;

  -- 3. Bloqueo de inyección de scripts / etiquetas HTML maliciosas
  if new.customer_name ~* '(<\s*script|javascript\s*:|onerror\s*=|onload\s*=|<\s*iframe)'
     or new.payment_reference ~* '(<\s*script|javascript\s*:|[<>])'
     or snapshot_text ~* '(<\s*script|javascript\s*:|vbscript\s*:|onerror\s*=|onload\s*=|<\s*iframe)' then
    raise exception using
      errcode = '22023',
      message = 'Se detectó contenido o código no permitido en los datos del pedido.';
  end if;

  -- 4. Verificación en servidor de precios, cantidades y montos de pago
  if jsonb_typeof(new.snapshot -> 'items') = 'array' then
    if jsonb_array_length(new.snapshot -> 'items') < 1
       or jsonb_array_length(new.snapshot -> 'items') > 200 then
      raise exception using
        errcode = '22023',
        message = 'El pedido debe contener entre 1 y 200 líneas de productos.';
    end if;

    for v_item in select * from jsonb_array_elements(new.snapshot -> 'items') loop
      v_product_slug := btrim(coalesce(v_item ->> 'productId', ''));
      v_variant_slug := btrim(coalesce(v_item ->> 'variantId', ''));
      v_item_qty := coalesce((v_item ->> 'quantity')::integer, 0);
      v_unit_price := coalesce((v_item ->> 'unitPrice')::numeric(12, 2), 0);
      v_line_total := coalesce((v_item ->> 'lineTotal')::numeric(12, 2), 0);

      if v_item_qty < 1 or v_item_qty > 10000 or v_unit_price <= 0 then
        raise exception using
          errcode = '22023',
          message = 'Cantidad o precio unitario inválido en una línea del pedido.';
      end if;

      if abs(v_line_total - round(v_unit_price * v_item_qty, 2)) > 0.05 then
        raise exception using
          errcode = '22023',
          message = 'El subtotal de una línea no coincide con precio x cantidad.';
      end if;

      -- Si el producto existe activo en la base de datos, verificar que el precio
      -- no haya sido manipulado por debajo del catálogo oficial
      select f.id, f.base_price
        into v_family_id, v_family_base_price
        from public.families f
       where f.slug = v_product_slug
         and f.active = true;

      if v_family_id is not null then
        -- Cantidad agregada de la misma familia en todo el pedido (para tarifas por mayor)
        select coalesce(sum(coalesce((elem ->> 'quantity')::integer, 0)), v_item_qty)
          into v_family_total_qty
          from jsonb_array_elements(new.snapshot -> 'items') elem
         where btrim(coalesce(elem ->> 'productId', '')) = v_product_slug;

        v_expected_price := v_family_base_price;

        -- Verificar escala por mayor de la familia
        select coalesce(min(t.unit_price), v_expected_price)
          into v_expected_price
          from public.family_price_tiers t
         where t.family_id = v_family_id
           and t.min_qty <= v_family_total_qty;

        -- Si hay variante con precio/escala propia, considerar también su mínimo válido
        if v_variant_slug <> '' then
          select v.id, v.base_price
            into v_variant_id, v_variant_price
            from public.variants v
           where v.family_id = v_family_id
             and v.slug = v_variant_slug;

          if v_variant_id is not null then
            if v_variant_price is not null and v_variant_price < v_expected_price then
              v_expected_price := v_variant_price;
            end if;
            select coalesce(min(vt.unit_price), v_expected_price)
              into v_expected_price
              from public.variant_price_tiers vt
             where vt.variant_id = v_variant_id
               and vt.min_qty <= v_family_total_qty;
          end if;
        end if;

        if v_unit_price < (v_expected_price - 0.05) then
          raise exception using
            errcode = '22023',
            message = 'Precio rechazado por el servidor: no coincide con el catálogo oficial.';
        end if;
      end if;

      v_sum_qty := v_sum_qty + v_item_qty;
      v_sum_total := v_sum_total + v_line_total;
    end loop;

    if v_sum_qty <> new.total_quantity then
      raise exception using
        errcode = '22023',
        message = 'La suma de unidades no coincide con el total de unidades del pedido.';
    end if;

    if abs(v_sum_total - new.total) > 0.05 then
      raise exception using
        errcode = '22023',
        message = 'La suma de precios de los productos no coincide con el total del pedido.';
    end if;

    if jsonb_typeof(new.snapshot -> 'payment') = 'object'
       and (new.snapshot -> 'payment' ? 'amount') then
      v_payment_amount := coalesce((new.snapshot #>> '{payment,amount}')::numeric(12, 2), 0);
      if abs(v_payment_amount - new.total) > 0.05 then
        raise exception using
          errcode = '22023',
          message = 'El monto registrado en el pago no coincide con el total verificado.';
      end if;
    end if;
  end if;

  -- 5. Rate Limiting: máximo 5 órdenes por usuario cada 10 minutos
  select count(*)
    into recent_order_count
    from public.customer_orders
   where user_id = new.user_id
     and created_at >= (now() - interval '10 minutes');

  if recent_order_count >= 5 then
    raise exception using
      errcode = 'P0001',
      message = 'Límite de seguridad alcanzado: demasiados pedidos en pocos minutos. Intenta más tarde.';
  end if;

  return new;
end;
$$;

drop trigger if exists trg_enforce_customer_order_security on public.customer_orders;
create trigger trg_enforce_customer_order_security
  before insert on public.customer_orders
  for each row execute function public.enforce_customer_order_security();

revoke all on function public.enforce_customer_order_security() from public, anon, authenticated;

-- Protección de perfiles de clientes contra inyección HTML y abuso de actualizaciones
create or replace function public.enforce_customer_profile_security()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.full_name ~ '[<>]' or new.full_name ~* '(javascript\s*:|onerror\s*=|onload\s*=)' then
    raise exception using
      errcode = '22023',
      message = 'El nombre contiene caracteres no permitidos.';
  end if;

  if tg_op = 'UPDATE' and old.updated_at is not null then
    if now() - old.updated_at < interval '3 seconds' then
      raise exception using
        errcode = 'P0001',
        message = 'Espera unos segundos antes de volver a actualizar tu perfil.';
    end if;
    new.updated_at := now();
  end if;

  return new;
end;
$$;

drop trigger if exists trg_enforce_customer_profile_security on public.customer_profiles;
create trigger trg_enforce_customer_profile_security
  before insert or update on public.customer_profiles
  for each row execute function public.enforce_customer_profile_security();

revoke all on function public.enforce_customer_profile_security() from public, anon, authenticated;

-- ============================================================================
-- C. RESTRICCIÓN EN SERVIDOR DE TIPOS MIME Y TAMAÑO EN STORAGE BUCKET (8 MB)
-- ============================================================================
update storage.buckets
   set file_size_limit = 8388608,
       allowed_mime_types = array['image/jpeg', 'image/png', 'image/webp']
 where id = 'catalog';
