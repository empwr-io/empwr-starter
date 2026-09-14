# Prompt library

Run these in order. Prompts 1 to 3 and 5 go to **Lovable**. Prompt 4 goes to **Claude
Code**, because it touches the database and several files at once.

Before prompt 5, open `sketches/client-register.html` in a browser and argue with it.
Changing a static file is free. Changing a built screen is not.

---

## 1. The shell

**Front end only, and that is deliberate.** Asking for sign-in here is enough to make
Lovable provision its own database before you have connected yours. Say nothing about
accounts until your own Supabase is attached.

> Build the front end shell for an internal staff platform called the [FIRM] Hub, for
> [FIRM], an Australian accounting firm. Read `config/firm.config.ts` for the name,
> wordmark, accent colour and terminology, and use those rather than inventing any.
>
> **Important: do not set up a backend, a database, authentication or sign-in in this
> step. No Lovable Cloud, no Supabase, no storage, no user accounts.** Front end only,
> with placeholder content. I am connecting my own database after this step and I do not
> want one created for me.
>
> Layout: a fixed left sidebar with the wordmark at the top, navigation grouped by
> section, and a placeholder for the signed-in user's name at the bottom. Main content
> area to the right with a slim page header showing the page title and space for page
> actions on the right. Navigation: Home, Clients, Reports, and an Admin section
> containing Team.
>
> Pages: Home as a dashboard of cards, one per tool, each linking through. Then an empty
> placeholder page for Clients, Reports and Team, each with its page header and one line
> saying what will live there.
>
> Design: dense and calm, built to be read all day, not a marketing page. A warm neutral
> background, not white, with near-black text. One accent colour used only for primary
> buttons and the active navigation item, never for status. Define every colour as a CSS
> variable in one place and never put a hex code in a component. System sans typeface,
> generous line height, a clear type scale. Data belongs in tables with tabular numbers
> aligned right, not in cards. Support light and dark mode from those variables.
>
> Australian conventions throughout: DD/MM/YYYY dates, dollar amounts with no cents on
> summary screens, financial years written as FY2027 meaning the year ending 30 June
> 2027, and Australian spelling.
>
> Do not build any tool logic, any form that saves, or any data fetching. Shell,
> navigation and empty pages only.

### Connect your database before prompt 2

Prompt 2 is authentication, which needs somewhere to store users. **Attach your own
Supabase project now**, before you run it: Lovable, More > Cloud, "Already have a
Supabase project? Connect it here". If you skip this, Lovable creates and owns the
database your clients' records will live in.

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
