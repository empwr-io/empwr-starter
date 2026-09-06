-- =============================================================================
-- FOUNDATION: who you are, what you may see, and the things every table needs.
-- Run this first. Clear the SQL editor before running the next file.
-- =============================================================================

-- ---------- roles ------------------------------------------------------------
-- Roles live in their own table, never as a column on a profile. A role stored
-- next to the user is a role the user can edit.
create type public.app_role as enum ('admin', 'staff');

create table public.user_roles (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references auth.users(id) on delete cascade,
  role       public.app_role not null,
  created_at timestamptz not null default now(),
  unique (user_id, role)
);
alter table public.user_roles enable row level security;

-- SECURITY DEFINER so a policy can call it without recursing into the policy on
-- the same table. This is not optional.
create or replace function public.has_role(p_user_id uuid, p_role public.app_role)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.user_roles where user_id = p_user_id and role = p_role);
$$;

create or replace function public.is_admin()
returns boolean language sql stable security definer set search_path = public as $$
  select public.has_role(auth.uid(), 'admin'::public.app_role);
$$;

grant execute on function public.has_role(uuid, public.app_role) to authenticated;
grant execute on function public.is_admin() to authenticated;

create policy read_own_roles on public.user_roles
  for select to authenticated using (user_id = auth.uid() or public.is_admin());
create policy admin_manages_roles on public.user_roles
  for all to authenticated using (public.is_admin()) with check (public.is_admin());
create policy service_roles on public.user_roles
  for all to service_role using (true) with check (true);

-- ---------- permission areas -------------------------------------------------
-- One value per tool. Add to this list every time you build a new one and access
-- becomes a tick box rather than a code change.
--   alter type public.app_area add value 'your_new_tool';
create type public.app_area as enum ('clients', 'reports', 'admin');

create table public.user_permissions (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references auth.users(id) on delete cascade,
  area       public.app_area not null,
  created_at timestamptz not null default now(),
  unique (user_id, area)
);
alter table public.user_permissions enable row level security;

-- Admins pass everything. Everyone else needs an explicit row.
create or replace function public.has_area(p_user_id uuid, p_area public.app_area)
returns boolean language sql stable security definer set search_path = public as $$
  select public.has_role(p_user_id, 'admin'::public.app_role)
      or exists (select 1 from public.user_permissions where user_id = p_user_id and area = p_area);
$$;

-- Text overload so an edge function can call it without knowing the enum type.
create or replace function public.has_area(p_user_id uuid, p_area text)
returns boolean language sql stable security definer set search_path = public as $$
  select public.has_area(p_user_id, p_area::public.app_area);
$$;

-- The front end calls this once to decide which menu items exist.
create or replace function public.get_my_areas()
returns text[] language sql stable security definer set search_path = public as $$
  select case
    when auth.uid() is null then array[]::text[]
    when public.has_role(auth.uid(), 'admin'::public.app_role) then (
      select array_agg(e.enumlabel::text order by e.enumsortorder)
      from pg_type t join pg_enum e on t.oid = e.enumtypid
      where t.typname = 'app_area'
    )
    else coalesce(
      (select array_agg(area::text) from public.user_permissions where user_id = auth.uid()),
      array[]::text[]
    )
  end;
$$;

grant execute on function public.has_area(uuid, public.app_area) to authenticated;
grant execute on function public.has_area(uuid, text) to authenticated;
grant execute on function public.get_my_areas() to authenticated;

create policy read_own_permissions on public.user_permissions
  for select to authenticated using (user_id = auth.uid() or public.is_admin());
create policy admin_manages_permissions on public.user_permissions
  for all to authenticated using (public.is_admin()) with check (public.is_admin());
create policy service_permissions on public.user_permissions
  for all to service_role using (true) with check (true);

-- ---------- things every table wants ----------------------------------------
create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- ---------- firm settings ----------------------------------------------------
-- One row. For anything a non-technical person should be able to change without a
-- deployment. Build-time things (colours, fonts) belong in config/firm.config.ts.
create table public.firm_settings (
  id                       boolean primary key default true,
  firm_name                text not null default 'Your Firm',
  financial_year_end_month smallint not null default 6,
  updated_at               timestamptz not null default now(),
  constraint firm_settings_one_row check (id)
);
alter table public.firm_settings enable row level security;
insert into public.firm_settings (id) values (true) on conflict do nothing;

create policy read_firm_settings on public.firm_settings
  for select to authenticated using (true);
create policy admin_writes_firm_settings on public.firm_settings
  for all to authenticated using (public.is_admin()) with check (public.is_admin());
create policy service_firm_settings on public.firm_settings
  for all to service_role using (true) with check (true);

create trigger firm_settings_updated before update on public.firm_settings
  for each row execute function public.set_updated_at();
