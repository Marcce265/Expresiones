-- Endurecimiento de seguridad en base de datos:
-- 1. Rate limiting por usuario en creación de órdenes (máx. 5 pedidos cada 10 minutos).
-- 2. Límite de tamaño de JSON snapshot (máx. 64 KB) para evitar bombas de datos.
-- 3. Bloqueo de payloads XSS / inyección de scripts en nombres, referencias y snapshots.
-- 4. Protección de actualización de perfiles de clientes y tope estricto en popularidad.

create or replace function public.enforce_customer_order_security()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  recent_order_count integer;
  snapshot_text text;
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

  -- 4. Rate Limiting: máximo 5 órdenes por usuario cada 10 minutos
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
