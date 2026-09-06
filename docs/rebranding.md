# Making it yours

Three surfaces. Nothing else should need touching.

## 1. `config/firm.config.ts`

Name, short name, wordmark, domain, support email, accent colour, and the words your
firm uses. If your firm says "family group" rather than "client group", change it here
and it changes everywhere, because user-facing text reads from this file rather than
hardcoding a label.

## 2. The design tokens

Colours live as CSS variables in one place, and components read the variables. Never put
a hex code in a component. That single rule is what lets a firm rebrand in ten minutes
instead of a fortnight.

Pick one accent and use it sparingly, for primary actions and the active navigation item
only. A dense internal tool that people read all day wants a calm neutral ground and one
colour that means "this is the thing to click".

Semantic colour is separate from your brand accent. Good, warning and critical each mean
one thing, everywhere, forever. Do not use your accent for a status.

## 3. `firm_settings` in the database

One row, editable by an administrator from inside the app. Use it for anything a
non-technical person might want to change without a deployment: the firm name shown in
the header, the current financial year, the default page.

## What not to change

The migration filenames and their order. The `has_area` gate. The three-statement table
pattern. `require-auth.ts`. Those are the parts that keep client data safe, and they are
generic already.
