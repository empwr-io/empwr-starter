# Gotchas

Every one of these cost somebody real time. You get them for free. Read it once before
you build, and again the moment something behaves strangely.

**Append to this file every time you solve a non-obvious problem.** Six months in it is
worth more than the code.

---

## Environment

**Never put a repository inside OneDrive, Dropbox or Google Drive.** The sync client
fights the tooling over the same files, locks them mid-write, and corrupts project
history. Everything under `~/dev` and nowhere else.

**Multi-line terminal blocks go in one line at a time.** Paste a whole block and the
shell runs the next line before the last one finished. It looks like it worked.

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

**`create or replace function` with a different argument list creates a SECOND
function.** It does not replace the first. Now you have two and calls resolve to
whichever matches. Drop the old one deliberately.

**Changing a function's return type needs a drop first.** Replace will refuse.

**A cron that pages with OFFSET and an unstable ORDER BY silently skips rows every
cycle.** Ties reorder between queries. Always include a tiebreaker column in the sort.

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
