-- =============================================================================
-- MODULE TWO: the structure report.
--
-- Capture a client's current entity structure and objectives, draft a
-- recommendation, and require a named human to sign it off before it can be
-- issued. SAFE TO RUN TWICE. Run after module one.
--
-- THE POINT OF THIS MODULE, in one paragraph.
-- Structure advice is usually the work a principal cannot delegate, which makes
-- it the work that caps the firm. A tool cannot replace the judgement. It can
-- remove the two hours of writing that happen before the judgement is applied,
-- and it can make the review step impossible to skip rather than merely
-- expected. That second part is the bit that matters to your registration.
-- =============================================================================

-- ---------- the new area ----------------------------------------------------
-- Note the deliberate absence of an enum cast in the policies further down.
-- Postgres will not let you USE a new enum value in the same transaction that
-- added it, so the policies call the text overload of has_area() instead. Cast
-- in the policy definition and this whole file fails on a fresh database.
alter type public.app_area add value if not exists 'structure';

-- ---------- the report ------------------------------------------------------
create table if not exists public.structure_reports (
  id              uuid primary key default gen_random_uuid(),
  client_id       uuid references public.clients(id) on delete set null,
  client_name     text not null,          -- kept even if the client row goes
  title           text not null default 'Structure review',
  status          text not null default 'draft',   -- draft|in_review|approved|issued
  prepared_by     uuid references public.staff(id) on delete set null,
  reviewed_by     uuid references public.staff(id) on delete set null,
  reviewed_at     timestamptz,
  issued_at       timestamptz,
  version         integer not null default 1,
  engagement_note text,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  constraint structure_reports_status_ck
    check (status in ('draft','in_review','approved','issued'))
);
create index if not exists structure_reports_client_idx on public.structure_reports (client_id);
create index if not exists structure_reports_status_idx on public.structure_reports (status);

-- ---------- the entities in the structure -----------------------------------
-- `is_proposed` is what makes one table serve both the current picture and the
-- recommendation, so a report can show them side by side.
create table if not exists public.structure_entities (
  id          uuid primary key default gen_random_uuid(),
  report_id   uuid not null references public.structure_reports(id) on delete cascade,
  name        text not null,
  entity_type text not null,              -- individual|sole_trader|company|trust|unit_trust|partnership|smsf
  entity_role text,                       -- operating|holding|trustee|beneficiary|shareholder|asset_owner
  acn         text,
  abn         text,
  is_proposed boolean not null default false,
  notes       text,
  created_at  timestamptz not null default now()
);
create index if not exists structure_entities_report_idx on public.structure_entities (report_id);

-- Never store a TFN here. It is not needed to describe a structure, and a
-- column that exists will eventually be filled in.

-- ---------- how they connect -------------------------------------------------
create table if not exists public.structure_relationships (
  id                uuid primary key default gen_random_uuid(),
  report_id         uuid not null references public.structure_reports(id) on delete cascade,
  from_entity_id    uuid not null references public.structure_entities(id) on delete cascade,
  to_entity_id      uuid not null references public.structure_entities(id) on delete cascade,
  relationship_type text not null,        -- shareholder|unitholder|beneficiary|trustee|director|loan|lease
  percentage        numeric(5,2),
  is_proposed       boolean not null default false,
  notes             text,
  created_at        timestamptz not null default now(),
  constraint structure_relationships_not_self check (from_entity_id <> to_entity_id)
);
create index if not exists structure_relationships_report_idx on public.structure_relationships (report_id);

-- ---------- what the client is trying to achieve ----------------------------
create table if not exists public.structure_objectives (
  id         uuid primary key default gen_random_uuid(),
  report_id  uuid not null references public.structure_reports(id) on delete cascade,
  objective  text not null,               -- asset_protection|tax_efficiency|succession|borrowing|new_partner|sale_readiness|simplification
  priority   integer not null default 3,  -- 1 highest
  notes      text,
  created_at timestamptz not null default now()
);
create index if not exists structure_objectives_report_idx on public.structure_objectives (report_id);

-- ---------- the Australian considerations, as a gate ------------------------
-- Every report gets one row per consideration, seeded automatically. None of
-- them may be left blank before approval. "Not applicable" is a valid and
-- common answer; silence is not.
create table if not exists public.structure_considerations (
  id                uuid primary key default gen_random_uuid(),
  report_id         uuid not null references public.structure_reports(id) on delete cascade,
  consideration_key text not null,
  status            text,                 -- null until someone decides
  note              text,
  decided_by        uuid references public.staff(id) on delete set null,
  decided_at        timestamptz,
  unique (report_id, consideration_key),
  constraint structure_considerations_status_ck
    check (status is null or status in ('not_applicable','addressed','flagged'))
);
create index if not exists structure_considerations_report_idx on public.structure_considerations (report_id);

create table if not exists public.structure_consideration_types (
  key         text primary key,
  label       text not null,
  guidance    text,
  sort_order  integer not null default 100,
  is_active   boolean not null default true
);

insert into public.structure_consideration_types (key, label, guidance, sort_order) values
  ('div7a',            'Division 7A',                  'Loans, payments or debt forgiveness from a private company to a shareholder or associate. Consider complying loan agreements and minimum yearly repayments.', 10),
  ('upe',              'Unpaid present entitlements',  'A trust distribution left unpaid to a corporate beneficiary. Position has moved: get current law before writing anything.', 20),
  ('s100a',            'Section 100A',                 'Reimbursement agreements and distributions that are not for the beneficiary''s benefit. Live issue, not historical.', 30),
  ('cgt_event',        'CGT on restructure',           'Moving an asset between entities is usually a disposal. Identify the event before recommending the move.', 40),
  ('cgt_rollover',     'Rollover relief',              'Small business restructure rollover and other available rollovers, and whether the conditions are actually met.', 50),
  ('sb_cgt',           'Small business CGT concessions','Whether the restructure preserves or destroys access to the concessions later.', 60),
  ('stamp_duty',       'Stamp duty',                   'State based, and frequently the thing that makes a good structure uneconomic. Check the relevant state.', 70),
  ('land_tax',         'Land tax',                     'Thresholds, trust surcharges and grouping vary by state.', 80),
  ('payroll_tax',      'Payroll tax',                  'Grouping provisions can pull separate entities together.', 90),
  ('asset_protection', 'Asset protection',             'What the structure actually protects, from whom, and what it does not.', 100),
  ('trust_vesting',    'Trust vesting date',           'How long the trust has left and what happens when it vests.', 110),
  ('succession',       'Succession and control',       'Who controls it on death or incapacity, and whether the deed permits the plan.', 120),
  ('gst',              'GST',                          'Going concern, grouping, and whether transfers are taxable supplies.', 130),
  ('fbt',              'FBT',                          'Benefits provided through the new structure.', 140),
  ('licensing',        'Licensing and registration',   'Whether the structure breaks a licence, registration or professional requirement.', 150)
on conflict (key) do nothing;

-- ---------- the drafted narrative -------------------------------------------
-- `is_ai_drafted` is not decoration. You need to be able to see, months later,
-- which words a person wrote and which were generated and then accepted.
create table if not exists public.structure_report_sections (
  id            uuid primary key default gen_random_uuid(),
  report_id     uuid not null references public.structure_reports(id) on delete cascade,
  section_key   text not null,            -- current|objectives|recommended|reasoning|tax|implementation|risks
  heading       text not null,
  body          text,
  is_ai_drafted boolean not null default false,
  edited_by     uuid references public.staff(id) on delete set null,
  updated_at    timestamptz not null default now(),
  unique (report_id, section_key)
);
create index if not exists structure_sections_report_idx on public.structure_report_sections (report_id);

-- ---------- the audit trail -------------------------------------------------
create table if not exists public.structure_review_log (
  id         uuid primary key default gen_random_uuid(),
  report_id  uuid not null references public.structure_reports(id) on delete cascade,
  action     text not null,               -- created|ai_drafted|edited|submitted|changes_requested|approved|issued
  by_staff   uuid references public.staff(id) on delete set null,
  by_user    uuid references auth.users(id) on delete set null,
  note       text,
  at         timestamptz not null default now()
);
create index if not exists structure_review_log_report_idx on public.structure_review_log (report_id, at desc);

-- ---------- seed the considerations on every new report ---------------------
create or replace function public.seed_structure_considerations()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.structure_considerations (report_id, consideration_key)
  select new.id, t.key
  from public.structure_consideration_types t
  where t.is_active
  on conflict (report_id, consideration_key) do nothing;
  return new;
end;
$$;

drop trigger if exists structure_reports_seed on public.structure_reports;
create trigger structure_reports_seed after insert on public.structure_reports
  for each row execute function public.seed_structure_considerations();

-- ---------- what is stopping this report being approved ---------------------
create or replace function public.structure_report_blockers(p_report_id uuid)
returns jsonb language sql stable security invoker set search_path = public as $$
  select jsonb_build_object(
    'unaddressed_considerations', (
      select coalesce(jsonb_agg(t.label order by t.sort_order), '[]'::jsonb)
      from public.structure_considerations c
      join public.structure_consideration_types t on t.key = c.consideration_key
      where c.report_id = p_report_id and c.status is null
    ),
    'missing_sections', (
      select coalesce(jsonb_agg(k), '[]'::jsonb)
      from (
        select k from unnest(array['current','objectives','recommended','reasoning','tax','implementation','risks']) k
        except
        select section_key from public.structure_report_sections
        where report_id = p_report_id and coalesce(btrim(body), '') <> ''
      ) missing
    ),
    -- Flagged means "there is a problem here". Flagged with nothing written
    -- against it means "there is a problem here and I am not going to say what",
    -- which is the same silence the whole module exists to prevent.
    'flagged_without_note', (
      select coalesce(jsonb_agg(t.label order by t.sort_order), '[]'::jsonb)
      from public.structure_considerations c
      join public.structure_consideration_types t on t.key = c.consideration_key
      where c.report_id = p_report_id
        and c.status = 'flagged'
        and coalesce(btrim(c.note), '') = ''
    ),
    'reviewer_named', (
      select reviewed_by is not null from public.structure_reports where id = p_report_id
    ),
    'no_proposed_entities', (
      select not exists (
        select 1 from public.structure_entities
        where report_id = p_report_id and is_proposed
      )
    )
  );
$$;
grant execute on function public.structure_report_blockers(uuid) to authenticated;

-- ---------- the gate --------------------------------------------------------
-- A report cannot become approved or issued while anything above is outstanding.
-- Enforced in the database, because a rule that lives only in the interface is a
-- rule that survives until someone is in a hurry.
--
-- ONE function holds the rules, and everything that needs them calls it. The
-- first version of this file inlined the checks in the trigger and then checked
-- only three of the four blockers it had just calculated, which is what happens
-- when the list of rules and the enforcement of them live in the same block of
-- code. Cohort zero caught it.
--
-- Note it is SECURITY DEFINER while structure_report_blockers() is SECURITY
-- INVOKER. That is deliberate: run from here, the blockers query executes as the
-- table owner and so sees every row regardless of row level security. A gate
-- that can be satisfied by not being allowed to see the problem is not a gate.
create or replace function public.structure_report_assert_ready(
  p_report_id   uuid,
  p_reviewed_by uuid
) returns void language plpgsql security definer set search_path = public as $$
declare
  b jsonb;
begin
  b := public.structure_report_blockers(p_report_id);

  if jsonb_array_length(b -> 'unaddressed_considerations') > 0 then
    raise exception
      'Cannot approve: % consideration(s) have no decision recorded. Mark each as addressed, flagged or not applicable.',
      jsonb_array_length(b -> 'unaddressed_considerations');
  end if;

  if jsonb_array_length(b -> 'missing_sections') > 0 then
    raise exception 'Cannot approve: the report still has empty sections (%).',
      b -> 'missing_sections';
  end if;

  -- The sketch promised this one and the code never enforced it, which is its
  -- own kind of defect: a specification the implementation quietly ignores.
  if jsonb_array_length(b -> 'flagged_without_note') > 0 then
    raise exception
      'Cannot approve: % consideration(s) are flagged with no written position recorded (%). Flagging a problem without saying what it is does not discharge anything.',
      jsonb_array_length(b -> 'flagged_without_note'),
      b -> 'flagged_without_note';
  end if;

  -- The one the first version calculated and then ignored.
  if coalesce((b ->> 'no_proposed_entities')::boolean, true) then
    raise exception
      'Cannot approve: the report recommends nothing. Add at least one entity marked as proposed. If the recommendation is to leave the structure alone, say so as a proposed entity so the advice is explicit rather than absent.';
  end if;

  if p_reviewed_by is null then
    raise exception 'Cannot approve: no reviewer is named against this report.';
  end if;
end;
$$;

create or replace function public.enforce_structure_approval()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'INSERT' then
    -- Approval is an event, not an initial state. Without this you can insert a
    -- row straight in as approved and never pass the gate at all, because the
    -- gate used to be a BEFORE UPDATE trigger only.
    if new.status in ('approved','issued') then
      raise exception
        'A report cannot be created as %. Create it as draft and approve it through the workflow, so the approval has a reviewer and a timestamp against it.',
        new.status;
    end if;
    return new;
  end if;

  -- UPDATE. Deliberately NOT conditional on the status changing. The old version
  -- only fired on a transition, which meant an already-approved report could be
  -- edited into a state that would never have passed. Every write to an approved
  -- or issued report is re-checked.
  if new.status in ('approved','issued') then
    perform public.structure_report_assert_ready(new.id, new.reviewed_by);

    new.reviewed_at := coalesce(new.reviewed_at, now());
    if new.status = 'issued' then
      new.issued_at := coalesce(new.issued_at, now());
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists structure_reports_gate on public.structure_reports;
create trigger structure_reports_gate
  before insert or update on public.structure_reports
  for each row execute function public.enforce_structure_approval();

-- ---------- and the contents are frozen once it is signed -------------------
-- Re-checking the report row is not enough on its own: the sections, the
-- considerations and the entities live in their own tables, so emptying a
-- section never touches structure_reports and never fires the trigger above.
-- To change signed advice you move the report back to in_review first, which is
-- a visible act rather than a silent edit.
create or replace function public.structure_report_locked(p_report_id uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.structure_reports
    where id = p_report_id and status in ('approved','issued')
  );
$$;

create or replace function public.enforce_structure_report_frozen()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  rid uuid;
begin
  -- NEW is unassigned on DELETE, so branch rather than coalesce.
  if tg_op = 'DELETE' then rid := old.report_id; else rid := new.report_id; end if;

  if public.structure_report_locked(rid) then
    raise exception
      'This report is % and its contents are frozen. Move it back to in_review before changing anything.',
      (select status from public.structure_reports where id = rid);
  end if;

  if tg_op = 'DELETE' then return old; end if;
  return new;
end;
$$;

-- structure_review_log is deliberately absent: the audit trail has to keep
-- accepting rows after approval, since approving and issuing are themselves
-- entries in it.
do $$
declare t text;
begin
  foreach t in array array[
    'structure_entities', 'structure_relationships', 'structure_objectives',
    'structure_considerations', 'structure_report_sections'
  ] loop
    execute format('drop trigger if exists %I on public.%I', t || '_frozen', t);
    execute format(
      'create trigger %I before insert or update or delete on public.%I '
      'for each row execute function public.enforce_structure_report_frozen()',
      t || '_frozen', t);
  end loop;
end $$;

-- A locked report cannot be deleted either. This is not belt and braces: the
-- cascade from structure_reports would otherwise run straight into the freeze
-- triggers above and fail halfway through with a confusing error. Issued advice
-- gets superseded by a new version, it does not get removed.
create or replace function public.enforce_structure_report_delete()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if old.status in ('approved','issued') then
    raise exception
      'An % report cannot be deleted. Move it back to in_review first, or supersede it with a new version.',
      old.status;
  end if;
  return old;
end;
$$;

drop trigger if exists structure_reports_no_delete on public.structure_reports;
create trigger structure_reports_no_delete before delete on public.structure_reports
  for each row execute function public.enforce_structure_report_delete();

-- ---------- take back what Postgres gave away -------------------------------
-- Every CREATE FUNCTION grants EXECUTE to PUBLIC. You did not ask for that and
-- you will not see it unless you go looking. PUBLIC includes `anon`, the role
-- behind your project's publishable key, which anybody who opens your front end
-- in a browser already has. On a SECURITY DEFINER function, which runs as the
-- table owner and therefore straight past row level security, that is the whole
-- ball game.
--
-- So revoke, then grant back deliberately to the roles that need it. The two
-- helpers authenticated staff genuinely call are granted above. The trigger
-- functions are called by nothing but their triggers.
do $$
declare f text;
begin
  foreach f in array array[
    'public.seed_structure_considerations()',
    'public.structure_report_assert_ready(uuid, uuid)',
    'public.structure_report_locked(uuid)',
    'public.enforce_structure_approval()',
    'public.enforce_structure_report_frozen()',
    'public.enforce_structure_report_delete()'
  ] loop
    execute format('revoke all on function %s from public', f);
    execute format('revoke all on function %s from anon', f);
  end loop;
end $$;

grant execute on function public.structure_report_assert_ready(uuid, uuid) to authenticated;
grant execute on function public.structure_report_locked(uuid) to authenticated;
grant execute on function public.structure_report_blockers(uuid) to authenticated;

-- ---------- updated_at ------------------------------------------------------
drop trigger if exists structure_reports_updated on public.structure_reports;
create trigger structure_reports_updated before update on public.structure_reports
  for each row execute function public.set_updated_at();

-- =============================================================================
-- ROW LEVEL SECURITY
-- The policies call has_area(uuid, text), NOT the enum version. See the note at
-- the top of this file: casting to a newly added enum value in the same
-- transaction that added it is an error.
-- =============================================================================
do $$
declare t text;
begin
  foreach t in array array[
    'structure_reports', 'structure_entities', 'structure_relationships',
    'structure_objectives', 'structure_considerations',
    'structure_report_sections', 'structure_review_log'
  ] loop
    execute format('alter table public.%I enable row level security', t);

    execute format('drop policy if exists area_access on public.%I', t);
    execute format(
      'create policy area_access on public.%I for all to authenticated '
      'using (public.has_area(auth.uid(), %L)) '
      'with check (public.has_area(auth.uid(), %L))',
      t, 'structure', 'structure');

    execute format('drop policy if exists service_access on public.%I', t);
    execute format(
      'create policy service_access on public.%I for all to service_role '
      'using (true) with check (true)', t);
  end loop;
end $$;

-- The consideration list is reference data: readable by any signed-in staff
-- member, writable only by an admin.
alter table public.structure_consideration_types enable row level security;
drop policy if exists read_consideration_types on public.structure_consideration_types;
create policy read_consideration_types on public.structure_consideration_types
  for select to authenticated using (true);
drop policy if exists admin_writes_consideration_types on public.structure_consideration_types;
create policy admin_writes_consideration_types on public.structure_consideration_types
  for all to authenticated using (public.is_admin()) with check (public.is_admin());
drop policy if exists service_consideration_types on public.structure_consideration_types;
create policy service_consideration_types on public.structure_consideration_types
  for all to service_role using (true) with check (true);

-- ---------- the list view ---------------------------------------------------
drop view if exists public.v_structure_reports;
create view public.v_structure_reports
with (security_invoker = on) as
select
  r.id,
  r.client_name,
  r.client_id,
  r.title,
  r.status,
  p.full_name as prepared_by_name,
  v.full_name as reviewed_by_name,
  r.reviewed_at,
  r.issued_at,
  r.version,
  (select count(*) from public.structure_entities e
    where e.report_id = r.id and e.is_proposed)                     as proposed_entities,
  (select count(*) from public.structure_considerations c
    where c.report_id = r.id and c.status is null)                  as open_considerations,
  (select count(*) from public.structure_considerations c
    where c.report_id = r.id and c.status = 'flagged')              as flagged_considerations,
  r.updated_at
from public.structure_reports r
left join public.staff p on p.id = r.prepared_by
left join public.staff v on v.id = r.reviewed_by;

comment on function public.structure_report_blockers(uuid) is
  'Everything standing between this report and approval. Drive the UI from this rather than duplicating the rules in the front end.';

-- ---------- did it work? ----------------------------------------------------
--   select count(*) from public.structure_consideration_types;   -- expect 15
--   select tablename, rowsecurity from pg_tables
--   where schemaname = 'public' and tablename like 'structure%';
