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

---

# Module two: the structure report

Structure advice is usually the work a principal cannot hand over, which makes it the
work that caps the firm. This module does not replace the judgement. It removes the
writing that happens before the judgement, and it makes the review step impossible to
skip rather than merely expected.

Run the migration `20260101000200_structure_report.sql` first.

Then open `sketches/structure-report.html` and argue with it before you build anything.
Note what is deliberately in that picture: three considerations with no decision, an
empty section, no named reviewer, and a dead Approve button. Those four are the design.

## 6. Conceptualise, before any code

> I want to build a structure report tool for my firm. Before you design or build
> anything, interrogate the idea.
>
> The workflow: when a client needs advice on how their entities should be structured,
> I open a screen, enter what I know about them, and get a draft report I review and
> then take to the client.
>
> Ask me every question you need in one batch, then wait. Ask about the actual work,
> not the technology: what I look at today, what I write by hand every time, what
> changes between a simple case and a hard one, where I get it wrong, what the client
> actually reads, and what I would never let software decide.
>
> Then produce a one page specification with these headings and nothing else: the
> problem in my own words; who uses it and when; the workflow end to end; the screens;
> every field it needs and where it comes from; what is explicitly out of scope for
> version one; and the measure, meaning the number that is true today and what it has
> to become.
>
> Three things are not negotiable and I want them in the specification. Every report is
> reviewed and signed off by a named person before a client sees it, and the tool has
> to make that impossible to skip. It must handle Australian rules properly: Division
> 7A, section 100A, CGT and rollovers, the small business concessions, state duty and
> land tax, asset protection, trust vesting and succession. And it must never present a
> recommendation as advice without a person's name against it.
>
> Be sceptical. If part of this should not be software, say so.

## 7. The screen

> Build the structure report tool at `/structure`, using the existing shell, navigation
> and design system. The layout is defined by `sketches/structure-report.html`: match
> it. Where the sketch and the design system disagree, the design system wins.
>
> The tables already exist from `20260101000200_structure_report.sql`. Do not create or
> alter them.
>
> - Gate the page on the `structure` area the same way every other page is gated.
> - A list screen of reports reading from `v_structure_reports`, and a detail screen.
> - **Drive the Approve button entirely from `structure_report_blockers(report_id)`.**
>   Do not reimplement those rules in the front end: call the function, show what it
>   returns at the top of the report, and disable Approve while anything is outstanding.
>   The database refuses the change anyway, so duplicated rules can only drift.
> - Considerations are a table where each row is set to addressed, flagged or not
>   applicable, with a note. Every change stamps who decided it and when.
> - Sections are editable text. A section drafted by AI keeps its badge until a person
>   edits it, and then it does not.
> - Current and proposed entities show side by side, as in the sketch.
> - Every state change writes a row to `structure_review_log`.
> - Dates DD/MM/YYYY, money with no cents, Australian spelling.

## 8. The drafting step

This is the one that needs care, because it is the step that touches client data and
produces something with your name on it.

> Add the AI drafting step to the structure report tool.
>
> - It runs from one button and drafts the narrative sections only: current structure,
>   recommended structure and reasoning, tax consequences. **It never sets a
>   consideration status and it never approves anything.** Those are decisions, not
>   drafting.
> - It runs in an edge function, never in the browser, and the first statement after
>   the CORS preflight is `requireStaffOrService` from `_shared/require-auth.ts`.
> - The API key comes from Supabase secrets. It never appears in front end code.
> - Anything that could take more than about 150 seconds returns immediately and writes
>   the result back when it finishes. Do not hold the request open.
> - Everything it writes is marked `is_ai_drafted` and a row goes into
>   `structure_review_log` recording that it ran, who triggered it and when.
> - It is given the entities, relationships and objectives for that report only. Do not
>   send it the client list or anything from another report.
> - The prompt must instruct it to state uncertainty rather than resolve it: where a
>   position depends on the deed, the state, or current law, it says so and leaves it
>   for the reviewer.
>
> Before you write it, tell me what you are going to send to the AI provider and what
> you are not. I want to read that list before any client data leaves the database.

### The consent question, which is not optional in Australia

Under the Tax Practitioners Board's guidance you need client consent before their data
reaches a third party AI provider, and a documented human review of every AI output
that informs advice. The review is handled: it is the gate. **Consent is not, and it is
yours to build.** Put the flag on the client record, check it in the edge function, and
fail closed when it is missing. A consent step you can evidence is worth more than a
policy in a folder.
