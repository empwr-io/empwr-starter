-- =============================================================================
-- MODULE ONE: the client and revenue register.
-- Every client, the group they belong to, who owns them, and what they pay.
-- Run after the foundation. Clear the SQL editor first.
--
-- DESIGN NOTE, and it is the important one.
-- Most practice management and proposal systems turn out to be missing the very
-- things you want to report on: no client groups, no owner against the client, no
-- category against the service. So every one of those has TWO columns: what the
-- source system said, and what you decided. The register is where the second one
-- gets filled in, as a by-product of using it.
-- =============================================================================

-- ---------- the team ---------------------------------------------------------
-- ONE canonical row per person, referenced everywhere by id. Never join people on
-- a name string: the day someone appears as "Sam" in one place and "Samantha Rowe"
-- in another, half your numbers quietly disappear.
create table public.staff (
  id           uuid primary key default gen_random_uuid(),
  full_name    text not null,
  email        text unique,
  role_title   text,
  is_active    boolean not null default true,
  auth_user_id uuid references auth.users(id) on delete set null,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

-- ---------- groups -----------------------------------------------------------
create table public.client_groups (
  id         uuid primary key default gen_random_uuid(),
  name       text not null,
  notes      text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create unique index client_groups_name_uniq on public.client_groups (lower(name));

-- ---------- clients ----------------------------------------------------------
create table public.clients (
  id                   uuid primary key default gen_random_uuid(),
  name                 text not null,
  entity_type          text,           -- individual | sole_trader | company | trust | partnership | smsf
  abn                  text,
  gst_registered       boolean,
  status               text not null default 'active',   -- active | prospect | archived
  onboarded_on         date,
  notes                text,

  -- what the source system said, kept so you can see what you started with
  source_system        text,           -- ignition | karbon | xpm | csv | manual
  source_id            text,
  source_group_name    text,
  source_manager_email text,

  -- what you decided, filled in from inside the tool
  group_id             uuid references public.client_groups(id) on delete set null,

  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now()
);
create unique index clients_source_uniq on public.clients (source_system, source_id)
  where source_id is not null;
create index clients_group_idx on public.clients (group_id);
create index clients_status_idx on public.clients (status);
create index clients_name_idx on public.clients (lower(name));

-- ---------- ownership --------------------------------------------------------
create type public.owner_role as enum ('partner', 'manager', 'bookkeeper');

create table public.client_owners (
  id         uuid primary key default gen_random_uuid(),
  client_id  uuid not null references public.clients(id) on delete cascade,
  staff_id   uuid not null references public.staff(id) on delete cascade,
  owner_role public.owner_role not null default 'manager',
  created_at timestamptz not null default now(),
  unique (client_id, owner_role)
);
create index client_owners_staff_idx on public.client_owners (staff_id);

-- ---------- services ---------------------------------------------------------
create table public.service_catalogue (
  id            uuid primary key default gen_random_uuid(),
  name          text not null,
  category      text,           -- yours to assign; source systems rarely carry one
  default_price numeric(12,2),
  price_type    text,           -- fixed | hourly | unit | minimum | included
  billing_mode  text,           -- automatic | manual
  is_active     boolean not null default true,
  source_system text,
  source_id     text,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);
create unique index service_catalogue_source_uniq on public.service_catalogue (source_system, source_id)
  where source_id is not null;
create index service_catalogue_category_idx on public.service_catalogue (category);

create table public.client_services (
  id               uuid primary key default gen_random_uuid(),
  client_id        uuid not null references public.clients(id) on delete cascade,
  service_id       uuid not null references public.service_catalogue(id) on delete restrict,
  annual_value     numeric(12,2) not null default 0,
  billing_mode     text,
  effective_from   date,
  effective_to     date,
  is_active        boolean not null default true,
  source_system    text,
  source_reference text,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);
create index client_services_client_idx on public.client_services (client_id) where is_active;
create index client_services_service_idx on public.client_services (service_id) where is_active;

-- ---------- import audit -----------------------------------------------------
-- A sync that writes half the rows and reports success produces a report that is
-- confidently wrong. Every load writes a row here, including the failures.
create table public.data_imports (
  id             uuid primary key default gen_random_uuid(),
  source_system  text not null,
  file_name      text,
  row_count      integer not null default 0,
  inserted_count integer not null default 0,
  updated_count  integer not null default 0,
  skipped_count  integer not null default 0,
  succeeded      boolean not null default false,
  notes          text,
  imported_by    uuid references auth.users(id),
  imported_at    timestamptz not null default now()
);
create index data_imports_at_idx on public.data_imports (imported_at desc);

-- ---------- updated_at triggers ---------------------------------------------
create trigger staff_updated before update on public.staff
  for each row execute function public.set_updated_at();
create trigger client_groups_updated before update on public.client_groups
  for each row execute function public.set_updated_at();
create trigger clients_updated before update on public.clients
  for each row execute function public.set_updated_at();
create trigger service_catalogue_updated before update on public.service_catalogue
  for each row execute function public.set_updated_at();
create trigger client_services_updated before update on public.client_services
  for each row execute function public.set_updated_at();

-- =============================================================================
-- ROW LEVEL SECURITY
-- The pattern, spelled out once on `clients` so you can see it, then applied to
-- the rest. Three statements that always travel together: lock it, let the right
-- staff in, let your own server functions in.
-- =============================================================================

-- 1. Lock it.
alter table public.clients enable row level security;

-- 2. Let the right staff in.
create policy area_access on public.clients
  for all to authenticated
  using      (public.has_area(auth.uid(), 'clients'::public.app_area))
  with check (public.has_area(auth.uid(), 'clients'::public.app_area));

-- 3. Let your own server functions in.
create policy service_access on public.clients
  for all to service_role using (true) with check (true);

-- The same three statements for the rest of the module.
do $$
declare t text;
begin
  foreach t in array array[
    'staff', 'client_groups', 'client_owners',
    'service_catalogue', 'client_services', 'data_imports'
  ] loop
    execute format('alter table public.%I enable row level security', t);
    execute format(
      'create policy area_access on public.%I for all to authenticated '
      'using (public.has_area(auth.uid(), %L::public.app_area)) '
      'with check (public.has_area(auth.uid(), %L::public.app_area))',
      t, 'clients', 'clients');
    execute format(
      'create policy service_access on public.%I for all to service_role '
      'using (true) with check (true)', t);
  end loop;
end $$;

-- =============================================================================
-- THE REGISTER
-- =============================================================================

-- security_invoker means the caller's permissions apply, not the view owner's.
-- Without it a view is a hole straight through your row level security.
create or replace view public.v_client_register
with (security_invoker = on) as
select
  c.id,
  c.name,
  c.entity_type,
  c.status,
  c.group_id,
  g.name                        as group_name,
  c.source_group_name,
  o.staff_id                    as manager_staff_id,
  s.full_name                   as manager_name,
  c.source_manager_email,
  coalesce(v.annual_value, 0)   as annual_value,
  coalesce(v.service_count, 0)  as service_count,
  c.updated_at
from public.clients c
left join public.client_groups g on g.id = c.group_id
left join public.client_owners o on o.client_id = c.id and o.owner_role = 'manager'
left join public.staff s on s.id = o.staff_id
left join lateral (
  select sum(cs.annual_value) as annual_value, count(*) as service_count
  from public.client_services cs
  where cs.client_id = c.id and cs.is_active
) v on true;

-- Headline numbers for the top of the screen. Deliberately includes the two counts
-- that tell you how much of your own data is still missing, because on day one that
-- is the most useful thing on the page.
create or replace function public.register_summary()
returns jsonb language sql stable security invoker set search_path = public as $$
  with base as (
    select * from public.v_client_register where status = 'active'
  ), total as (
    select coalesce(sum(annual_value), 0) as value from base
  )
  select jsonb_build_object(
    'clients',           (select count(*) from base),
    'groups',            (select count(distinct group_id) from base where group_id is not null),
    'without_group',     (select count(*) from base where group_id is null),
    'without_owner',     (select count(*) from base where manager_staff_id is null),
    'annual_value',      (select value from total),
    'average_value',     (select case when count(*) > 0
                                 then round((select value from total) / count(*), 2)
                                 else 0 end from base),
    'top5_share_pct',    (select case when (select value from total) > 0
                                 then round(100.0 * (
                                   select coalesce(sum(annual_value), 0)
                                   from (select annual_value from base order by annual_value desc limit 5) t
                                 ) / (select value from total), 1)
                                 else 0 end)
  );
$$;
grant execute on function public.register_summary() to authenticated;

comment on function public.register_summary() is
  'Headline figures for the client register. SECURITY INVOKER on purpose: the caller must hold the clients area.';
