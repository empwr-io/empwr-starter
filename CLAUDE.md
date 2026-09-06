# CLAUDE.md

Read this before you write anything in this repository.

> Replace every YOUR FIRM placeholder below with your own details, then delete this line.

## Who we are

**YOUR FIRM** is an Australian public practice. Our clients are Australian individuals
and small to medium businesses. Everything is AUD, Australian financial years run
1 July to 30 June, GST is 10%, and we use Australian spelling throughout.

## The stack

- **Lovable** builds the front end. React, TypeScript, Tailwind.
- **Supabase** in the **Sydney region** is the database, authentication, file storage
  and edge functions.
- **GitHub** is the single source of truth. Lovable and Claude Code both push to it.

## House rules

1. **Every new table ships with row level security ON and an area policy.** Never create
   a table without one. The pattern is in `supabase/migrations` and it is three
   statements that always travel together.
2. **Every edge function calls `requireStaffOrService` as its first statement** after the
   CORS preflight. `verify_jwt` is not an authorisation check.
3. **Never commit secrets.** Keys live in Supabase edge function secrets. The service
   role key never appears in front end code, in this repository, or in a chat window.
4. **Client data never leaves Australian infrastructure** without written approval.
5. **Any query that could return more than 1000 rows pages through with `fetchAllRows`.**
   PostgREST truncates silently at 1000 and a truncated result looks complete.
6. **Australian spelling in all user-facing text. No em dashes.**
7. **Before writing code, tell me the plan in five lines and wait for me to agree.**

## Terminology

Read `config/firm.config.ts`. It holds what this firm calls things, and user-facing text
should use those words rather than whatever the source system calls them.

## Gotchas

`docs/gotchas.md` holds every trap this platform has already hit. **Append to it every
time we solve a non-obvious problem**, before closing the branch. That file compounds;
the code does not.
