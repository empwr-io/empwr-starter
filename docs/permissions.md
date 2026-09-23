# Permissions

Claude Code asks before it acts. This is where you decide what it stops asking about.

Two things live in two different files, and putting one in the wrong place means it
silently does nothing. That is not a criticism of you: we shipped that exact mistake in
this template and cohort zero caught it.

---

## The rules go in the project. The mode goes in your user file.

**`.claude/settings.json` in this repo** holds the allow, deny and ask lists. These work
from project settings, they travel with the repo, and they are doing the real work.

**`~/.claude/settings.json`, your own user file**, is the only place `defaultMode` works.
From Claude Code 2.1.257 the documentation is explicit:

> `permissions.defaultMode` values `auto` and `bypassPermissions` don't take effect from
> project or local settings; set them in user or managed settings instead, or pass
> `--permission-mode` for one session. Before v2.1.257, `bypassPermissions` took effect
> from any file.

So a `defaultMode` key in this repo's settings file is inert. It is left out on purpose,
with a comment saying why, because an inert key that looks like it is working is worse
than no key at all.

### Precedence, highest wins

1. Managed settings, set by an organisation
2. Command line, `claude --settings`
3. Project local, `.claude/settings.local.json`
4. Shared project, `.claude/settings.json` (this repo)
5. User, `~/.claude/settings.json`

Counter-intuitively your user file is the *lowest* precedence, and it is still the only
one that can set the mode.

---

## How a command is decided

Rules are evaluated **deny, then ask, then allow. First match wins**, and being more
specific does not move you up the order.

**Runs without asking.** Anything beginning `git`, `bun`, `npm`, `npx`, `ls`, `cat`,
`grep`, `supabase`. These are prefix matches, so `git commit` and `npm run build` are
covered. One caveat: allow rules in a project file only apply once you have accepted the
workspace trust prompt for that folder, because they grant capability.

**Still asks you.** `rm`, `mv`, `chmod`, and `supabase db push`.

Worth seeing the overlap, because it shows the ordering. `supabase *` is allowed and
`supabase db push*` is on the ask list. Ask is evaluated first, so a push prompts and the
broader allow does not rescue it. Every other `supabase` subcommand runs freely.

**Blocked outright.** `sudo`, `rm -rf /*`, `rm -rf ~/*`, `git push --force`,
`supabase db reset`, `supabase projects delete`. Deny runs before everything, so the
`supabase *` allow cannot reach the last two, and no other settings file can switch them
back on: if a tool is denied at any level, no level can allow it.

**Everything else.** A command matching none of the three lists does not come to you
either. It goes to the auto mode classifier, which decides on its own. So the honest
summary is: eight command families run freely, four ask, six are hard blocked, and the
remainder are judged by a classifier rather than by you.

---

## Claude Code will not write this file for you

Asking it to create or edit `.claude/settings.json` is refused by the classifier as
self-modification, and no instruction from you lifts that. It is the correct behaviour:
an assistant that can widen its own permissions does not really have any.

So create it by hand. In VS Code, make a `.claude` folder at the project root, add
`settings.json` inside it, and paste the contents of
[`docs/claude-settings.json`](claude-settings.json) unchanged.

### Then check it actually loaded

A settings file that is saved but not picked up looks exactly like one that is working,
right up until it does not.

1. **Save the file.** VS Code does not always autosave a new file.
2. **Restart Claude Code.** Settings are read at startup, so an open session is still
   running on the old rules. Close the panel and reopen it, or restart VS Code.
3. **Run `/permissions`** in Claude Code. It lists the rules actually in force. If your
   allow, deny and ask entries are not in that list, the file has not loaded: check it is
   at `.claude/settings.json` in the project root, and that it is valid JSON.
4. **Accept the workspace trust prompt** if VS Code asks. Allow rules grant capability,
   so they only take effect in a folder you have trusted.

---

## If you do want bypass mode

It goes in `~/.claude/settings.json`, your own user file, and it applies to every project
on the machine rather than just this one.

```json
{
  "permissions": {
    "defaultMode": "bypassPermissions"
  }
}
```

Think about it before you do. That machine holds live credentials to a database with
client records in it, and bypass mode means an assistant acting on them without checking
with you. The deny and ask lists in this repo still hold, because deny outranks
everything and ask still prompts even in bypass mode. But the classifier stops being a
second opinion.

For one session only, and much easier to reason about:

```
claude --permission-mode bypassPermissions
```

Our own recommendation for a firm holding client data: leave the mode alone, keep the
rules, and accept the occasional prompt. The lists remove almost all of the friction and
none of the safety.
