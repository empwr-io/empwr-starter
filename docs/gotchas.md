# Gotchas

Every one of these cost somebody real time. You get them for free. Read it once before
you build, and again the moment something behaves strangely.

**Append to this file every time you solve a non-obvious problem.** Six months in it is
worth more than the code.

---

## Permissions

**`defaultMode` does nothing in a project settings file.** From Claude Code 2.1.257,
`permissions.defaultMode` values `auto` and `bypassPermissions` only take effect from
your user file or managed settings. Put `bypassPermissions` in `.claude/settings.json`
and it is inert, while looking exactly like it is working. We shipped that mistake in
this template. See `docs/permissions.md`.

**Claude Code will not write its own settings file.** The classifier refuses it as
self-modification and no instruction lifts that, which is correct: an assistant that can
widen its own permissions does not have any. Create `.claude/settings.json` by hand.

**Ask rules still prompt in bypass mode**, and deny still blocks. An explicit ask rule is
listed first among the actions no mode auto-approves. So the lists are worth more than
the mode.

**Order is deny, then ask, then allow, first match wins.** Specificity does not change
the order, which is why `supabase db push*` on the ask list still prompts even though
`supabase *` is allowed.

**The three lists do not cover everything.** Anything matching none of them goes to the
auto mode classifier rather than to you. Eight families run freely here, four ask, six
are blocked, and the rest are somebody else's judgement.

**Schema changes come from Claude Code only.** Never ask Lovable to create a table. Both
can write migrations, and if both do, the history stops describing the database.

## Environment

**Never put a repository inside OneDrive, Dropbox or Google Drive.** The sync client
fights the tooling over the same files, locks them mid-write, and corrupts project
history. Everything under `~/dev` and nowhere else.

**Use the VS Code terminal, not PowerShell from the Start menu.** The VS Code terminal
(Terminal, New Terminal) opens in your project folder. PowerShell opened from the Start
menu begins in `C:\Windows\system32`, and `supabase link` then tries to create
`C:\Windows\System32\supabase\.temp` and fails. Nothing is broken, you are in the wrong
folder. Pick one term for it in your own documentation and use that term everywhere:
"PowerShell" and "a normal terminal" read as two different tools to somebody learning.

**Every instruction needs an expected output.** "Run this" without "you should see
`Finished supabase link.`" leaves the reader unable to tell success from silence, and
silence is what they get most of the time. Show what working looks like.

**"Run it the same way" is ambiguous for a migration.** Putting the file in
`supabase/migrations/` and applying it to the database are two separate actions. Say
which one you mean, every time.

**Multi-line terminal blocks go in one line at a time.** Paste a whole block and the
shell runs the next line before the last one finished. It looks like it worked.

**A file path is not a SQL command.** Pasting
`supabase/migrations/0001_foundation.sql` into the Supabase SQL editor gives you
`syntax error at or near "supabase"`. The editor speaks SQL and nothing else: open the
file, copy the contents, paste those. Obvious once you know, and it has stopped more
than one person for a day.

**A cloned folder is not always named what you expected.** Builder platforms append a
random suffix to the repository they create, so `cd project-name` fails with a path
error. Force the name at clone time: `git clone <url> project-name`.

---

## Row level security

**A table without a policy is readable by the public internet.** The anon key ships in
your browser bundle. Table, RLS on, policy: three statements, always together. Check the
Supabase Tables list weekly and it should never show RLS disabled.

**A view is a hole straight through RLS unless you say otherwise.** Create it
`with (security_invoker = on)` so the caller's permissions apply rather than the view
owner's.

**A `SECURITY INVOKER` function over gated tables returns empty rather than failing.**
The administrator testing it sees data because administrators pass every gate, and
everyone else silently sees nothing. If a screen works for you and is blank for the
team, this is why.

**`auth.uid()` is NULL in the SQL editor.** Anything you test there that depends on the
current user will behave differently from the app. Test as a real signed-in user.

**`revoke ... from public` does not cover `anon`.** Supabase grants `anon` execute
explicitly, and `anon` has a NULL `auth.uid()` exactly like `service_role`, so never
gate anything on "there is no session".

**Roles never live on a profile row.** A role stored next to the user is a role the user
can edit. Separate table, `SECURITY DEFINER` function, policy calls the function.

---

## Edge functions

**`verify_jwt` is not an authorisation check.** It proves the caller holds a JWT signed
by your project, and the anon key is one, and it is public. Every function identifies
its own caller. See `supabase/functions/_shared/require-auth.ts`.

**Editing `_shared/` does nothing until you redeploy every function that imports it.**
Shared modules are bundled per function. Local green and production red is the
signature. Keep a list of importers.

**Anything over about 150 seconds returns a gateway error even though the work
finished.** Streaming does not save you. Return 202 immediately, do the work in the
background, write the result to a status column, and poll it.

**Scheduled jobs call your function with the anon key.** A guard that unconditionally
demands a staff session will 403 every scheduled run, invisibly. Handle the scheduled
path explicitly.

---

## Postgres

**Every `create function` grants EXECUTE to PUBLIC, and PUBLIC includes `anon`.**
Postgres does this silently and you will never see it unless you look. `anon` is the role
behind your publishable key, which anybody who opens your front end already holds. On a
`security definer` function, which runs as the table owner and therefore past row level
security, that is a hole with your whole database behind it. Revoke, then grant back to
the roles that need it.

**`revoke all on function f from public` does not revoke a direct grant to `anon`.**
PUBLIC and `anon` are separate grants. Revoke both, every time.

**A gate that only fires when the status changes is not a gate.** Our own approval
trigger was `before update ... when old.status is distinct from new.status`, which left
two ways through: insert a row straight in as `approved`, or edit an already-approved row
into a state that would never have passed. Enforce the condition, not the transition, and
put the trigger on insert as well. Cohort zero caught this one in our file.

**If the rules live in one function, call that function.** The same trigger calculated
four blockers and then checked three of them, because the list and the enforcement were
the same block of code. One function returns the blockers, one function asserts them, and
the trigger calls the assert.

**Child rows are not covered by a trigger on the parent.** Freezing a signed report by
re-checking `structure_reports` does nothing about someone emptying a row in
`structure_report_sections`, which never touches the parent table. If the contents matter,
the trigger goes on the tables holding the contents.

**`NEW` is unassigned in a `before delete` trigger.** Branch on `tg_op` and read `old`.
`coalesce(new.x, old.x)` looks tidy and raises "record new is not assigned yet".

**`create or replace function` with a different argument list creates a SECOND
function.** It does not replace the first. Now you have two and calls resolve to
whichever matches. Drop the old one deliberately.

**Changing a function's return type needs a drop first.** Replace will refuse.

**You cannot use a new enum value in the same transaction that added it.**
`alter type app_area add value 'structure'` followed by a policy that casts
`'structure'::app_area` fails with "unsafe use of new value of enum type", and a pasted
migration file often runs as one transaction. This is why `has_area()` has a `text`
overload: the policies pass a plain string and the cast happens inside the function at
call time instead.

**A cron that pages with OFFSET and an unstable ORDER BY silently skips rows every
cycle.** Ties reorder between queries. Always include a tiebreaker column in the sort.

---

## Migrations

**A blank Remote column in `migration list` tells you about the history table, not about
your schema.** The two can disagree. If any SQL was ever run in the browser, the tables
exist and the history has no record of them, so `migration list` shows Local filled and
Remote blank while the database is in fact already built. Reading that as "nothing has
been applied" and running `db push` re-runs the whole file over live objects. Our
migrations are idempotent so nothing breaks, but anything changed by hand since is
quietly overwritten. **Check the schema, not just the history, before your first push:**

```sql
select tablename from pg_tables where schemaname = 'public' order by tablename;
```

If the tables are already there, use `migration repair` rather than `db push`. The route
is in [`docs/supabase-cli.md`](supabase-cli.md).

**Migrations are recorded as applied by filename, not by content.** Editing a migration
that has already been applied changes nothing on any database that has already run it,
and no warning is printed. A correction to an applied migration has to ship as a new
numbered file. Fix the original too, so a fresh database gets it right first time, but do
not expect the fix to reach an existing one.

**Never apply SQL by hand once the CLI is linked.** This is the same gotcha as the first
one, stated as a rule. One writer, one path, one history.

---

## Data

**PostgREST truncates every response at 1000 rows, silently.** `.limit(50000)` returns
1000 with no error. Use `fetchAllRows` from `src/lib`. This one produces reports that are
confidently wrong, which is worse than reports that are obviously broken.

**Never join people on a name string.** The day somebody is "Sam" in one table and
"Samantha Rowe" in another, half your numbers vanish with no error. One canonical staff
row, referenced by id, everywhere.

**Your source system is missing more than you think.** Expect no client groups, no owner
against most clients, and no category on any service. Keep what the source said in one
column and what you decided in another, and let people fix it from inside the tool.

**A partial sync that reports success is worse than one that fails.** Write the row
count and the outcome to an import log, and show the last-updated time on the screen.
"Updated 6:04am today" in the corner is the cheapest feature in the tool and it decides
whether anyone trusts it.

---

## Front end

**A missing React import passes every check and kills the page.** TypeScript, the build
and the linter can all be green while the browser shows nothing. Check imports by hand
when a page goes blank for no reason.

**Never hardcode a hex code in a component.** Colours are CSS variables in one file.
That single rule is what makes rebranding a ten minute job.

**Semantic colour is not your brand colour.** Good, warning and critical mean one thing
everywhere. Do not use your accent for a status.

---

## Working with Lovable and Claude Code

**Never edit in both at the same moment.** Finish in one, let it push, then start in the
other. If they disagree, GitHub is the truth: pull and carry on.

**Migrations do not apply themselves when you push.** Run the SQL yourself.

**Builder platforms rename things.** Expect it to pick its own project name no matter how
specific you are. It does not matter. What matters is that it points at the right
repository and the right database.

**When it changes more than you asked:** "That changed things I did not ask you to
change. Revert to the previous version and make only this one change: ..."

---

## Australian obligations

**Client consent before their data reaches any AI provider**, and a documented human
review of every AI output that informs advice. Build the consent flag into the client
record and the review step into the tool.

**Data residency is chosen once.** Supabase region `ap-southeast-2` (Sydney), set at
creation, unchangeable afterwards.

**Never let a builder platform create your database.** A database owned by the platform
is a migration project the day you want to leave.
