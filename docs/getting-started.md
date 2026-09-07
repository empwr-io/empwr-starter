# Getting started

About an hour, most of it waiting. Do the stages in order.

Assumes you have already done the foundations install: VS Code, Git, Claude Code,
Supabase in Sydney, and a Lovable account.

---

## 0. Already started? Read this first

If you have already created a Lovable project and a Supabase database from the
foundations install, **do not start again**. You do not want a second repository.

Bring this into the project you already have instead. Open Claude Code in your project
folder and give it this:

> Clone https://github.com/empwr-io/empwr-starter into a temporary folder outside this
> project, then copy its `supabase/`, `src/lib/`, `config/`, `docs/` and `sketches/`
> folders into this project. Do not overwrite anything Lovable generated, and do not
> copy its README, .git folder or .gitignore over mine. Then tell me what you copied and
> delete the temporary folder.

Both migrations are **safe to run twice**, so if you already ran the foundation SQL from
the install document, run the foundation migration anyway. It adds the few pieces the
install document did not have and changes nothing that already exists.

Then skip to stage 4.

---

## 1. Take your own copy

This is a template, not a dependency. You want your own repository with your own
history, not a fork that tracks ours.

On GitHub, open https://github.com/empwr-io/empwr-starter and click **Use this
template**. That gives you your own repository with a clean history, rather than a fork
that stays tied to ours. Name it after your firm, then:

```
cd ~/dev
git clone https://github.com/YOUR-USERNAME/yourfirm-platform.git
cd yourfirm-platform
```

> **Windows note.** Run these in PowerShell, one line at a time, pressing enter after
> each. Not inside VS Code, not in a browser.

## 2. Make it yours

Open `config/firm.config.ts` and change every value. It is the only file you must edit
by hand. Name, short name, wordmark, domain, accent colour, and what your firm calls
things.

Then open `CLAUDE.md` and replace the YOUR FIRM placeholders. That file is what Claude
reads at the start of every session, so it is worth five minutes.

## 3. Create the database

In the Supabase SQL editor, run the files in `supabase/migrations/` **in filename
order**, one at a time.

> **Clear the editor completely between files.** It does not separate them for you:
> paste the second underneath the first and it runs as one statement and fails.

When both have run, check Database, Tables. Every table should show row level security
enabled. If any does not, stop and fix it before going further.

## 4. Make yourself the administrator

Sign in to the app once so a user record exists, then run this with your own email:

```sql
insert into public.user_roles (user_id, role)
select id, 'admin'::public.app_role
from auth.users
where email = 'you@yourfirm.com.au'
on conflict (user_id, role) do nothing;
```

## 5. Build the front end

Open `docs/prompt-library.md` and run the prompts in order. Prompts 1 to 3 go to
Lovable, prompt 4 goes to Claude Code.

Before prompt 4, open `sketches/client-register.html` in a browser. That is the picture
of the screen you are about to build. Argue with it first: it is far cheaper to change a
static file than a built screen.

## 6. Load your data

Export your clients and services from your practice management or proposal system as
CSV. Put the files in a `data/` folder, which is git-ignored so real client data never
reaches GitHub.

Then ask Claude Code to import them. The register is built to expect that your source
system is missing things: it keeps what the source said in `source_group_name` and
`source_manager_email`, and lets you assign the real group and owner in the tool. That
is deliberate. Most firms discover their source system has no groups and no owners at
all, and the register is how that gets fixed.

## You are finished when

- Your published URL loads a sign-in screen and nothing else.
- You can sign in and sign out.
- You are the admin and see every tool.
- A second test account sees nothing until you tick a box for it.
- No table shows row level security disabled.
- The register lists your real clients, and you can assign a group and an owner.
