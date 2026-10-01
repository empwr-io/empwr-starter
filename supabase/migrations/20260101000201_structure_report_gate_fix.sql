-- =============================================================================
-- MODULE TWO, CORRECTION ONE: the approval gate, properly closed.
-- SAFE TO RUN TWICE. Safe to run on a database that never had the fault.
--
-- WHY THIS EXISTS AS ITS OWN FILE.
-- Module two shipped with two holes in the gate, both found by cohort zero
-- reading the file before running it. The upstream 20260101000200 is now
-- corrected, so a fresh database gets the right version first time and never
-- needs this file. But a database that has already applied 20260101000200 will
-- never re-apply it, because the migration history records a file as applied by
-- NAME. Editing an applied migration changes nothing on any database that has
-- already run it. So the correction ships as a new numbered migration, which is
-- the only mechanism that actually converges an existing database.
--
-- Running both files in order on a fresh database is harmless: this one replaces
-- the same functions and triggers with identical definitions.
--
-- WHAT WAS WRONG.
--  1. structure_report_blockers() calculated four blockers. The trigger checked
--     three. A report could be approved and issued with no proposed entities at
--     all, which is a structure report recommending nothing.
--  2. The trigger was BEFORE UPDATE and fired only when the status itself
--     changed. Two consequences: a row could be INSERTed directly as approved
--     and never meet the gate, and an already-approved report could be edited
--     into a state that would never have passed.
--  3. Re-checking the report row was not sufficient anyway. The sections,
--     considerations and entities live in their own tables, so emptying a
--     section never touches structure_reports and never fires the trigger.
--
-- Found while fixing those three:
--  4. sketches/structure-report.html listed four blockers. The code enforced
--     three. A consideration marked `flagged` with nothing written against it
--     passed the gate, because flagged counts as decided. "There is a problem
--     here and I am not going to say what" is the same silence the module
--     exists to prevent, and our own sketch had already said so.
--  5. Every one of these functions is SECURITY DEFINER, and Postgres grants
--     EXECUTE on a new function to PUBLIC by default. PUBLIC includes `anon`,
--     the role behind your publishable key. Revoked, then granted back to
--     `authenticated` deliberately.
--
-- WHAT IS DIFFERENT NOW.
-- One function holds the rules and everything calls it. The trigger runs on
-- INSERT and on UPDATE, unconditionally for any report that is approved or
-- issued. The child tables are frozen while the report is signed, so changing
-- signed advice means moving it back to in_review first, which is a visible act.
-- =============================================================================

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

-- ---------- did it work? ----------------------------------------------------
-- Four triggers on the report, five freeze triggers on the children:
--   select tgname, tgrelid::regclass as on_table
--   from pg_trigger
--   where not tgisinternal
--     and tgrelid::regclass::text like 'structure%'
--   order by on_table, tgname;
--
-- Expect: structure_reports_gate, structure_reports_no_delete,
-- structure_reports_seed, structure_reports_updated, and one <table>_frozen on
-- each of entities, relationships, objectives, considerations and sections.
-- Nothing on structure_review_log, by design.
--
-- And the blockers now report five things rather than four:
--   select jsonb_object_keys(public.structure_report_blockers(gen_random_uuid()));
-- Expect unaddressed_considerations, missing_sections, flagged_without_note,
-- reviewer_named, no_proposed_entities.
--
-- Then confirm anon cannot reach the definer functions:
--   select p.proname, coalesce(array_to_string(p.proacl, ', '), 'owner only') as grants
--   from pg_proc p join pg_namespace n on n.oid = p.pronamespace
--   where n.nspname = 'public'
--     and p.proname in ('structure_report_assert_ready','structure_report_locked',
--                       'structure_report_blockers','seed_structure_considerations')
--   order by p.proname;
-- No row should contain "anon=X" or a bare "=X" (that bare one IS public).
