# Security model

Four layers. Each one assumes the others might fail.

## 1. Nobody sees anything without signing in

Every route except sign-in is protected, including on a hard refresh. There is no public
sign-up: accounts are created by an administrator.

## 2. The database decides what you can see, not the interface

Roles live in `user_roles`, never as a column on a profile a user can edit. Permissions
are per **area**, where an area is one tool. `has_area(user_id, area)` is the single
gate, and it is `SECURITY DEFINER` so a policy can call it without recursing.

Hiding a menu item is presentation. The policy on the table is the security.

## 3. The anon key is not a secret and is not a permission

It ships inside the browser bundle, so treat it as public. It grants nothing on its own,
because every table has a policy. **This is why a table without a policy is a breach**:
anyone who views your page source can then read that table.

Check weekly: Supabase dashboard, Database, Tables. Nothing should show RLS disabled.

## 4. Edge functions identify their own caller

`verify_jwt = true` only proves the caller holds a JWT signed by your project, and the
anon key is exactly that. So `_shared/require-auth.ts` compares the presented token
against the service role key using a constant-time comparison, or validates a real user
session. Never trust a `role` claim inside a token: a claim is forgeable the moment
someone turns `verify_jwt` off in a hurry.

## Australian obligations

- **Data residency.** Supabase project in `ap-southeast-2` (Sydney). Chosen at creation
  and unchangeable afterwards.
- **AI and client data.** Under the Tax Practitioners Board's guidance you need client
  consent before their data reaches a third party AI provider, and a documented human
  review of every AI output that informs advice. Build the consent flag into the client
  record and the review step into the tool. A control you can evidence beats a policy
  nobody follows.
- **Notifiable data breaches.** Assume you are a covered entity. Know who makes the call
  and what the 30 day clock means before you need to.

## Reporting

Security concerns go to the firm's nominated owner of this platform, not into a public
issue tracker.
