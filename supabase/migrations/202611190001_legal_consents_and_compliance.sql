-- Cumplimiento Legal Perú (Ley N° 29733, D.S. N° 016-2024-JUS e INDECOPI Ley N° 29571):
-- Tabla inmutable de auditoría de consentimientos legales (Términos y Condiciones
-- y Política de Privacidad por separado).

create table if not exists public.legal_consents (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete set null,
  context text not null check (
    context in ('checkout_coordination', 'account_registration', 'cookie_notice')
  ),
  customer_name text not null default '',
  customer_phone text not null default '',
  terms_accepted boolean not null check (terms_accepted = true),
  privacy_accepted boolean not null check (privacy_accepted = true),
  policy_version text not null default '2026-11-PE'
    check (char_length(btrim(policy_version)) between 2 and 40),
  accepted_via text not null default 'two_separate_checkboxes'
    check (char_length(btrim(accepted_via)) between 2 and 80),
  accepted_at timestamptz not null default now()
);

create index if not exists legal_consents_accepted_at_idx
  on public.legal_consents (accepted_at desc);

create index if not exists legal_consents_user_id_idx
  on public.legal_consents (user_id, accepted_at desc);

alter table public.legal_consents enable row level security;

revoke all on table public.legal_consents from public, anon, authenticated;

-- Visitantes (checkout sin cuenta) y usuarios autenticados pueden registrar su consentimiento.
-- Nadie tiene permiso UPDATE ni DELETE: el registro probatorio es inmutable.
grant insert on table public.legal_consents to anon, authenticated;
grant select on table public.legal_consents to authenticated;

drop policy if exists legal_consents_insert_valid on public.legal_consents;
create policy legal_consents_insert_valid
  on public.legal_consents
  for insert
  to anon, authenticated
  with check (
    terms_accepted = true
    and privacy_accepted = true
    and (user_id is null or user_id = (select auth.uid()))
  );

drop policy if exists legal_consents_read_own_or_admin on public.legal_consents;
create policy legal_consents_read_own_or_admin
  on public.legal_consents
  for select
  to authenticated
  using (
    (user_id is not null and user_id = (select auth.uid()))
    or public.can_admin_write()
  );

create or replace function public.enforce_legal_consent_security()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if char_length(coalesce(new.customer_name, '')) > 120 then
    raise exception using
      errcode = '22023',
      message = 'Nombre en registro de consentimiento excede longitud permitida.';
  end if;

  if char_length(coalesce(new.customer_phone, '')) > 24 then
    raise exception using
      errcode = '22023',
      message = 'Teléfono en registro de consentimiento excede longitud permitida.';
  end if;

  if coalesce(new.customer_name, '') ~* '(<\s*script|javascript\s*:|onerror\s*=|onload\s*=|[<>])'
     or coalesce(new.customer_phone, '') ~* '[<>]'
     or coalesce(new.policy_version, '') ~* '[<>]'
     or coalesce(new.accepted_via, '') ~* '[<>]' then
    raise exception using
      errcode = '22023',
      message = 'Caracteres no permitidos en registro de consentimiento.';
  end if;

  new.accepted_at := now();
  return new;
end;
$$;

drop trigger if exists trg_enforce_legal_consent_security on public.legal_consents;
create trigger trg_enforce_legal_consent_security
  before insert on public.legal_consents
  for each row execute function public.enforce_legal_consent_security();

revoke all on function public.enforce_legal_consent_security() from public, anon, authenticated;
