# Prompt library

Run these in order. Prompts 1 to 3 and 5 go to **Lovable**. Prompt 4 goes to **Claude
Code**, because it touches the database and several files at once.

Before prompt 5, open `sketches/client-register.html` in a browser and argue with it.
Changing a static file is free. Changing a built screen is not.

---

## 1. The shell

> Build the application shell for an internal platform for an Australian accounting
> firm. Read `config/firm.config.ts` for the firm's name, wordmark, accent colour and
> terminology, and use those values rather than inventing any. This is a staff tool, not
> a public website: nobody sees anything without signing in.
>
> Layout: fixed left sidebar with the wordmark at the top, navigation grouped by
> section, and the signed-in user plus a sign out button at the bottom. Main area to the
> right with a slim page header showing the page title and space for page actions.
>
> Pages for now: Home, a dashboard of cards with one per tool, and a placeholder page
> for Clients and Reports.
>
> Design: clean and dense, built to be read all day. A calm neutral ground, not white.
> One accent used sparingly for primary actions and the active nav item only. Semantic
> colour for good, warning and critical is separate from the accent and means the same
> thing everywhere. Data in tables with tabular numbers, not in cards. Light and dark
> from CSS variables defined in one place, and never a hex code in a component.
>
> Australian conventions: DD/MM/YYYY, dollars with no cents on summary screens,
> financial years shown as FY2027 meaning the year ending 30 June 2027.
>
> No tool logic yet. Shell, navigation and empty pages only.

## 2. Sign in

> Add authentication using the connected Supabase project.
>
> - Email and password on its own page. No public sign up: accounts are created by an
>   administrator. Anyone reaching a sign up route goes to sign in.
> - Every route except sign in is protected, including on a hard refresh.
> - While the session loads, show a quiet loading state, not a flash of the sign in
>   screen.
> - Sign out clears the session and returns to sign in.
>
> Do not store any role or permission in the browser as the source of truth. The
> database decides what somebody can see and the front end only reflects it.

## 3. Permissions in the interface

> Wire the navigation to the permission functions already in the database.
>
> - On sign in call the `get_my_areas()` RPC once and hold the result for the session.
> - Each navigation item declares its area: Clients needs `clients`, Reports needs
>   `reports`. Hide any item whose area is not in my list, and hide its dashboard card.
> - Visiting a URL directly without the area shows a plain "You do not have access to
>   this tool" page. Hiding a menu item is presentation, not security.
> - Add an Admin section, visible only to admins, with a Team page: every user, their
>   role, and a tick box per area writing to `user_permissions`.

## 4. The import (Claude Code)

> Write a CSV import for the client register, into the tables created by
> `supabase/migrations/20260101000100_client_register.sql`.
>
> - It reads a clients export and a services export. Column names differ between source
>   systems, so map them explicitly and tell me what you mapped.
> - Upsert on `(source_system, source_id)` so running it twice does not duplicate
>   anything. I will run it twice on purpose.
> - Put the source system's group name in `source_group_name` and its manager email in
>   `source_manager_email`. Do NOT guess at `group_id` or create owner rows. Those are
>   assigned by a human in the tool, and the gap between the two columns is the point.
> - Page through anything over 1000 rows using `src/lib/fetchAllRows.ts`.
> - Write one row to `data_imports` for every run, including failures, with the counts.
> - If the source fails halfway, fail loudly with what worked and what did not. Never
>   report success on a partial load.
>
> Then tell me the exact command to run it once by hand.

## 5. The register screen

> Build the client register at `/clients`, using the existing shell, navigation and
> design system. The layout is defined by `sketches/client-register.html`: match it.
> Where the sketch and the design system disagree, the design system wins.
>
> Read from `v_client_register` and call `register_summary()` for the figures at the
> top. Real data only, no mock data in committed code.
>
> - Gate the page on the `clients` area the same way every other page is gated.
> - The two counts that matter on day one are clients without a group and clients
>   without an owner. Show them prominently and make them filters, because fixing them
>   is what this screen is for.
> - Assigning a group or an owner happens inline in the row, saves immediately, and
>   shows what the source system said next to it so the person can see what they are
>   correcting.
> - Genuine empty state for a firm with no data yet, and a loading state that is not a
>   blank screen.
> - Anything over 1000 rows pages through rather than silently stopping.
> - Show when the data was last imported, from `data_imports`.
> - Dates DD/MM/YYYY, money with no cents, numbers right aligned and tabular.
>
> Build only what is in the sketch. If something is missing that you think it needs,
> tell me rather than adding it.
