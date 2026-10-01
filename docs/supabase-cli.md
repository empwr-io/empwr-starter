# The Supabase CLI

This is how database changes ship once you are set up: you write a migration file, one
command applies it, and the same command records that it was applied. No copying SQL
into a browser, and no guessing later about what is actually live.

---

## Which window

There are two places text goes, they look similar, and putting something in the wrong one
produces a confusing failure rather than an obvious one.

| | What it is | What goes in it |
|---|---|---|
| **The Claude Code panel** | The chat panel inside VS Code | Instructions in English. "Download this file into supabase/migrations" |
| **The VS Code terminal** | **Terminal, then New Terminal** | Commands. Anything starting `npm`, `npx`, `git`, `supabase` |

**Everything in this document is a command and runs in the VS Code terminal.** Where it
says "the terminal", it always means that one. There is no separate "normal terminal" step
anywhere in this document.

That matters more than it sounds. The VS Code terminal opens *in your project folder*
already. If you open PowerShell from the Start menu instead it begins in
`C:\Windows\system32`, and `supabase link` will try to write its working files into a
Windows system folder and fail with something like:

```
FileSystem.makeDirectory (C:\Windows\System32\supabase\.temp)
```

Nothing is broken when that happens. You are just in the wrong folder. Close it, use the
VS Code terminal, and run it again.

### Claude Code will interrupt you, and some of those interruptions matter

Two kinds of prompt appear and they are not the same thing.

**Approve this command?** This is the permission system doing its job. `supabase db push`
is on the **ask** list in `.claude/settings.json` deliberately, so it will always stop and
ask you even when everything else runs freely. Reading it before you say yes is the
correct response, not an over-cautious one. See [`docs/permissions.md`](permissions.md).

**Which of these would you like me to do?** Claude Code raises its own multiple-choice
questions when it finds something the instructions did not anticipate, and it is usually
right to have asked. If the choice is about how to apply a migration, or about changing a
file you were told to apply as given, **stop and send it to us before you pick.** Both of
those have happened on this programme and both times the question was better than the
instruction that produced it.

---

## 1. Install it into the project

```
npm install -D supabase
```

**Looks like it worked when:** it finishes with a line like `added 1 package` and
`supabase` appears under `devDependencies` in your `package.json`.

Installed into the project rather than globally, so the version travels with the repo and
a teammate gets the same one.

---

## 2. Log in

```
npx supabase login
```

**What happens:** it prints a verification code, then opens your browser. **Check the
code in the browser matches the one in the terminal**, approve it, and then come back:
depending on the version it either completes on its own or waits for you to paste the
code back into the terminal. Either way the terminal is where it finishes.

**Looks like it worked when:** `Finished supabase login.`

Run this one yourself. It needs a browser and your keyboard, so it cannot be done by
Claude Code in a background session.

---

## 3. Check the project is awake, then link

Before linking, open your Supabase dashboard and confirm the project shows **Active
Healthy**. A project that has been idle takes a minute or two to wake up, and linking
while it is still starting gives you:

```
Project status is COMING_UP instead of Active Healthy
```

That is a warning, not a failure, and it usually resolves by itself. If you see it, wait
a minute and run the link again rather than worrying about it.

```
npx supabase link --project-ref YOUR-PROJECT-REF
```

Your project ref is in Supabase under **Project Settings, General, Reference ID**. It is
also the subdomain of your project URL, and Lovable writes it into
`supabase/config.toml` as `project_id` when it connects your database.

**Looks like it worked when:** `Finished supabase link.` and a `supabase/.temp/project-ref`
file now exists.

---

## 4. See what the history says

```
npx supabase migration list
```

**What you get** is two columns, Local and Remote:

```
  Local            | Remote | Time (UTC)
  -----------------|--------|--------------------
  20260101000000   |        | 2026-01-01 00:00:00
  20260101000100   |        | 2026-01-01 00:01:00
```

Read it like this:

| Local | Remote | Means |
|---|---|---|
| filled | blank | This file has not been applied **through the CLI**. See the warning below |
| filled | filled | Applied, and the history matches. This is what you want |
| blank | filled | Applied to the database but the file is missing locally. Somebody applied SQL outside this workflow |

This command is read-only. Run it whenever you are unsure what state you are in, which
is the whole reason it exists.

---

## 5. Then check the schema, because the history can be wrong

**This is the step that is easy to skip and expensive to skip.**

`migration list` reads one small table that records which migration files the CLI has
applied. It does not look at your schema at all. So if any SQL was ever run in the
Supabase SQL editor by hand, which is how most people start, **the tables exist and the
history has no idea.** You get Local filled and Remote blank on everything, and your
database is in fact already built.

Read that as "nothing has been applied" and push, and you re-run every file over live
objects. Our migrations are all safe to run twice, so nothing breaks. But anything you
changed by hand since is quietly reverted to what the file says, and you will not be told.

So before your first push, in the Supabase SQL editor:

```sql
select tablename from pg_tables where schemaname = 'public' order by tablename;
```

**Nothing listed, or only `firm_settings` and friends missing:** the database really is
bare. Go to step 6 and push.

**The tables are already there:** do not push. Go to step 7 and repair the history first.

---

## 6. Apply them

```
npx supabase db push
```

**Looks like it worked when:** it lists the migrations it is about to apply, asks you to
confirm, and then `Finished supabase db push.` Run `migration list` again and both
columns are now filled.

---

## 7. When the tables exist but the history does not know

This is the common case for anyone who started in the SQL editor. You are not fixing the
database, which is already correct. You are telling the history what is already true, so
that the next push only applies what is genuinely new.

Mark each already-applied migration as applied, oldest first:

```
npx supabase migration repair --status applied 20260101000000
npx supabase migration repair --status applied 20260101000100
```

**Looks like it worked when:** `Repaired migration history: [20260101000000] => applied`,
and `migration list` now shows Remote filled on those rows and blank only on the ones that
genuinely have not run.

Then push, and only the new file actually executes:

```
npx supabase db push
```

The opposite case exists too. If the history claims a migration was applied and the
objects are not there, `--status reverted` removes the record so a push will run it again:

```
npx supabase migration repair --status reverted 20260101000200
```

Use that one carefully. It is the right tool when a push failed halfway and left the
history ahead of the schema, and the wrong tool for almost everything else.

---

## Adding a migration from somewhere else

If you are given a migration file, for example a new module from the starter, there are
two separate steps and it is worth being precise about which is which:

1. **Put the file in `supabase/migrations/`.** That only puts it on your machine. The
   database has not changed. `migration list` will show it with Local filled and Remote
   blank.
2. **Apply it with `npx supabase db push`.** Now the database has changed and the history
   records it.

Doing the first without the second is the most common way to end up wondering why a
table does not exist.

Then commit and push the file to GitHub in the same sitting, so the repository and the
database never disagree about what exists.

---

## When a migration we gave you turns out to be wrong

Two things have to happen and only one of them is obvious.

**The original file gets corrected**, so that a firm starting tomorrow gets the right
version on a fresh database and never meets the fault.

**A new numbered migration ships the correction**, because a migration is recorded as
applied by its *filename*. Once `20260101000200` is in your history, editing that file
changes nothing on your database and nothing warns you. Only a new file runs.

So if you have already applied a module and we fix it, expect a small extra migration
whose entire job is to bring an existing database into line. Apply it the normal way. You
can also overwrite your local copy of the original with the corrected one, which is safe
and keeps your repo honest, because an applied migration is never re-run.

**If you have amended a file locally yourself, tell us before you apply our correction.**
The correction replaces functions and triggers outright, so whichever of us is right, the
database ends up matching the repo rather than matching whoever ran last.
