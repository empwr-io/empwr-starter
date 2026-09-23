# The Supabase CLI

This is how database changes ship once you are set up: you write a migration file, one
command applies it, and the same command records that it was applied. No copying SQL
into a browser, and no guessing later about what is actually live.

---

## One terminal, and only one

**Everything in this document runs in the VS Code terminal.** In VS Code, menu
**Terminal, then New Terminal**.

That matters more than it sounds. The VS Code terminal opens *in your project folder*
already. If you open PowerShell from the Start menu instead it begins in
`C:\Windows\system32`, and `supabase link` will try to write its working files into a
Windows system folder and fail with something like:

```
FileSystem.makeDirectory (C:\Windows\System32\supabase\.temp)
```

Nothing is broken when that happens. You are just in the wrong folder. Close it, use the
VS Code terminal, and run it again.

Where this document says "the terminal", it always means that one. There is no separate
"normal terminal" step anywhere.

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

## 4. See what is applied and what is not

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
| filled | blank | The file is on your machine but **not applied** to the database |
| filled | filled | Applied, and the history matches. This is what you want |
| blank | filled | Applied to the database but the file is missing locally. Somebody applied SQL outside this workflow |

This command is read-only. Run it whenever you are unsure what state you are in, which
is the whole reason it exists.

---

## 5. Apply them

```
npx supabase db push
```

**Looks like it worked when:** it lists the migrations it is about to apply, asks you to
confirm, and then `Finished supabase db push.` Run `migration list` again and both
columns are now filled.

`db push` is on the **ask** list in `.claude/settings.json` deliberately, so Claude Code
will always check with you before running it even when everything else flows freely.

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
