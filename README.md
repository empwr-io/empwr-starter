# empwr. firms starter

A working foundation for an accounting firm's own internal platform. Sign-in, roles,
per-tool permissions, row level security, and a first module: the **client and revenue
register**.

It is deliberately empty of anyone else's data. You clone it, rename it, point it at
your own Australian-hosted database, and it becomes your firm's platform.

---

## What you get

| | |
|---|---|
| **The security model** | Roles and per-tool permission areas, enforced in the database rather than in the interface. Ship a new table and it is locked by default. |
| **Module one** | Client and revenue register: every client, the group they belong to, who owns them, what they pay, and what they are on. |
| **The guard** | An edge function auth module that checks who is calling, because Supabase's `verify_jwt` does not. |
| **The prompts** | The exact prompts that build the front end, in order. |
| **The gotchas** | Every trap we already paid for, written down so you do not pay for them again. |

## What you do not get, on purpose

No React application. The front end is generated from `docs/prompt-library.md` in
Lovable, because that is the part AI builds well and the part you will want to change.
What is in this repository is the part AI builds badly and you cannot afford to get
wrong: the data model and the security.

---

## Two ways in

**Starting fresh:** click **Use this template** on GitHub. You get your own repository
with a clean history rather than a fork tied to ours.

**Already have a Lovable project and a Supabase database?** Do not start again. See
stage 0 of `docs/getting-started.md`, which copies this into the project you already
have. Both migrations are safe to run twice.

## Start here

1. `docs/getting-started.md` - clone, rename, and get it running. About an hour.
2. `config/firm.config.ts` - your firm's name, colours and language. One file.
3. `docs/prompt-library.md` - build the screens.
4. `docs/gotchas.md` - read once before you build, again when something breaks.

## Layout

```
config/            your firm's identity, the only file you must edit
docs/              getting started, prompts, gotchas
sketches/          static HTML pictures of each screen, argue with these first
src/lib/           small helpers the generated front end imports
supabase/
  migrations/      the database, in order
  functions/       server-side code, including the auth guard
```

## Rules that are not negotiable

1. **This repository never lives inside OneDrive, Dropbox or Google Drive.** Sync
   clients lock files mid-write and corrupt project history. Put it under `~/dev`.
2. **Every table ships with row level security on and a policy.** Three statements,
   always together. A table without a policy is readable by the public internet.
3. **Client data stays on Australian infrastructure.** Create your Supabase project in
   the Sydney region. That choice cannot be changed afterwards.
4. **Consent before client data reaches any AI provider**, and a documented human review
   of every AI output that informs advice.

---

Built for the empwr. firms programme. Rebrand it, change it, make it yours.
