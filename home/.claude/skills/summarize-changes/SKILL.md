---
name: summarize-changes
description: >-
  Summarize recent repository changes into a polished, self-contained HTML report
  saved to a temporary file and opened in the browser. Reads git history and diffs,
  groups the work into human-readable themes, and renders an interactive report with
  expandable detail toggles — never a plain markdown dump. Accepts filters such as
  author(s), date range, branch, and path. Use when you want a visual recap of what
  changed recently in the repo.
argument-hint: '[--author=name] [--since=date] [--until=date] [--branch=ref] [--max=N] [path]'
disable-model-invocation: true
---

# Recent Changes Summary → Interactive HTML

You generate a **visual, interactive HTML report** summarizing recent changes in the
current git repository, save it to a temporary file, and open it in the user's browser.

This skill is **explicitly invoked only** — never auto-triggered. When invoked, proceed
autonomously: parse the filters, read git history, synthesize a summary, render the HTML,
and open it. Do not ask for confirmation unless the repository state is ambiguous
(e.g. not a git repo, or a filter matches zero commits).

## Core Principles

- **Not a markdown dump.** The output is a designed HTML page with cards, badges, stats,
  and collapsible detail toggles. Avoid anything that reads like rendered markdown
  (no bare `#` headings, no `-` bullet walls). Favor good UX and visual hierarchy.
- **Explicit, expandable detail.** Each change group shows a concise headline by default;
  the full per-commit detail (message, files, stats, key diffs) lives inside a toggle
  (`<details>`/`<summary>`) the reader opens on demand.
- **Human summary, not a git log reprint.** Read the actual commits and diffs, then explain
  *what changed and why it matters* in plain language, grouped by theme — not one row per commit.
- **Self-contained.** All CSS and JS inline in a single HTML file. No external requests,
  CDNs, fonts, or images. It must render offline from a `file://` path.
- **Truthful.** Every claim traces to a real commit or diff. Never invent changes. If a
  filter returns nothing, say so clearly in the report rather than padding it.

## Input

**Raw arguments:** $ARGUMENTS

### Argument Parsing

Parse flags loosely — accept `--flag=value`, `--flag value`, and natural language
("changes by Alice since last Monday", "what did the team ship this week"). Map to:

| Filter | Git mapping | Notes |
|--------|-------------|-------|
| `--author=NAME` (repeatable) | `--author=NAME` | Match one or more authors; combine with multiple `--author` |
| `--since=DATE` | `--since=DATE` | Accepts git-approxidate ("2 weeks ago", "last monday", ISO dates) |
| `--until=DATE` | `--until=DATE` | Upper time bound |
| `--branch=REF` / `--ref=REF` | revision range | Default: current branch |
| `--max=N` | `-n N` | Cap commit count; default 50 |
| `--grep=TEXT` | `--grep=TEXT` | Filter by commit message text |
| `PATH` (positional) | `-- PATH` | Limit to a subtree or file |

**Defaults when no filters are given:** last 7 days on the current branch, all authors,
capped at 50 commits. State the resolved filter set at the start of your reply, then proceed.

## Phase 1: Gather Data

1. **Confirm it's a git repo:** `git rev-parse --is-inside-work-tree`. If not, stop and tell the user.
2. **Resolve context:** current branch (`git branch --show-current`), repo name (basename of
   `git rev-parse --show-toplevel`), and the resolved date/author/path filters.
3. **List commits** with a machine-parseable format, e.g.:
   ```
   git log <range> <filters> --no-merges --date=short \
     --pretty=format:'%H%x1f%an%x1f%ae%x1f%ad%x1f%s%x1f%b%x1e'
   ```
   (`%x1f` = field separator, `%x1e` = record separator — robust against commas/newlines in messages.)
4. **Per-commit stats:** `git show --stat --oneline <hash>` or `git log --numstat` to get files
   changed and insertions/deletions.
5. **Read meaningful diffs:** for the most substantive commits, inspect the actual diff
   (`git show <hash>`) enough to describe *what* changed — not just filenames. Prioritize
   commits touching core logic over lockfile/formatting churn. Cap diff reading to stay efficient.
6. **Also capture uncommitted work** if present (`git status --short`, `git diff --stat`) and
   include it as a distinct "Working tree (uncommitted)" section so the recap reflects reality.

## Phase 2: Synthesize

- **Group commits into themes** (features, fixes, refactors, docs, tests, chore/infra…). Infer
  themes from commit messages + touched paths, not just conventional-commit prefixes.
- Write a **1–2 sentence executive summary** of the period: the headline of what happened.
- Compute **stats**: commit count, files changed, insertions/deletions, contributor count, date span.
- For each theme, write a short human explanation, then list its commits as expandable items.
- Note anything risk-worthy: large diffs, migrations, deleted files, config/secret-adjacent changes.

## Phase 3: Render HTML

Write a single self-contained `.html` file to a temp path:
`${TMPDIR:-/tmp}/changes-summary-<repo>-<UTCstamp>.html`
(slugify repo name; timestamp like `20260721-1530`). Then open it:
- macOS: `open <file>` · Linux: `xdg-open <file>` · WSL: `explorer.exe <file>`.

Finally, print the absolute file path in your reply so the user can reopen it.

### Design requirements (make it genuinely nice — not boring)

- **Theme-aware:** support light and dark via `prefers-color-scheme`, using CSS variables.
- **Layout:** a hero header (repo name, filter chips, date span) → a stat strip of KPI tiles
  (commits, files, +ins/−dels, contributors) → theme sections → contributor breakdown → footer.
- **Cards, not lists.** Each theme is a section; each commit is a card with an author avatar
  (colored initials circle), short hash badge, date, subject, and a `+/−` stat pill.
- **The toggle is mandatory (requirement 4):** each commit card's full detail — full message body,
  changed-file list, and any highlighted diff snippets — is hidden inside a `<details><summary>`
  that expands on click. Add one "Expand all / Collapse all" control at the top.
- **Diff snippets:** when you show diff lines, style added lines green-tinted and removed lines
  red-tinted inside a monospace block; keep snippets short and representative.
- **Polish:** subtle shadows, rounded corners, a small amount of tasteful motion (hover lift,
  smooth `<details>` open), a sticky header, and a text/hash search box that filters cards via a
  tiny inline JS. Color-code theme badges (feature/fix/refactor/docs/etc.).
- **Accessible & responsive:** readable contrast in both themes, `max-width` container, wraps on
  mobile, tables/diffs scroll inside their own container rather than overflowing the page.
- Escape all commit text before injecting into HTML (a commit message may contain `<`, `&`, quotes).

Use this skeleton as a starting point and expand it — do not ship it empty:

```html
<!doctype html>
<html lang="en" data-theme>
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Changes · {{repo}}</title>
<style>
  :root{
    --bg:#f7f8fa; --surface:#fff; --text:#1a1d24; --muted:#6b7280; --border:#e5e7eb;
    --accent:#4f46e5; --add:#16a34a; --del:#dc2626; --shadow:0 1px 3px rgba(0,0,0,.08),0 8px 24px rgba(0,0,0,.06);
    --feature:#4f46e5; --fix:#dc2626; --refactor:#d97706; --docs:#0891b2; --test:#7c3aed; --chore:#6b7280;
  }
  @media (prefers-color-scheme:dark){
    :root{--bg:#0d1117;--surface:#161b22;--text:#e6edf3;--muted:#8b949e;--border:#30363d;
          --accent:#7c8cff;--shadow:0 1px 3px rgba(0,0,0,.4),0 8px 24px rgba(0,0,0,.3);}
  }
  *{box-sizing:border-box} body{margin:0;background:var(--bg);color:var(--text);
    font:15px/1.55 -apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,Helvetica,Arial,sans-serif}
  .wrap{max-width:960px;margin:0 auto;padding:24px}
  header.hero{position:sticky;top:0;z-index:10;backdrop-filter:blur(8px)}
  .kpis{display:grid;grid-template-columns:repeat(auto-fit,minmax(140px,1fr));gap:12px}
  .kpi{background:var(--surface);border:1px solid var(--border);border-radius:14px;padding:16px;box-shadow:var(--shadow)}
  .kpi .n{font-size:26px;font-weight:700} .kpi .l{color:var(--muted);font-size:12px;text-transform:uppercase;letter-spacing:.04em}
  .chip{display:inline-flex;align-items:center;gap:6px;padding:4px 10px;border-radius:999px;background:var(--surface);
        border:1px solid var(--border);font-size:12px;color:var(--muted)}
  .card{background:var(--surface);border:1px solid var(--border);border-radius:14px;padding:14px 16px;margin:10px 0;
        box-shadow:var(--shadow);transition:transform .12s ease}
  .card:hover{transform:translateY(-1px)}
  .badge{padding:2px 8px;border-radius:6px;color:#fff;font-size:11px;font-weight:600}
  .avatar{width:28px;height:28px;border-radius:50%;display:grid;place-items:center;color:#fff;font-size:12px;font-weight:700}
  .stat-pill{font-family:ui-monospace,Menlo,monospace;font-size:12px}
  .add{color:var(--add)} .del{color:var(--del)}
  details{margin-top:10px;border-top:1px dashed var(--border);padding-top:10px}
  summary{cursor:pointer;color:var(--accent);font-size:13px;font-weight:600;list-style:none}
  summary::-webkit-details-marker{display:none}
  pre.diff{overflow-x:auto;background:rgba(127,127,127,.06);border-radius:8px;padding:10px;font-size:12px;
           font-family:ui-monospace,Menlo,monospace}
  pre.diff .l-add{color:var(--add)} pre.diff .l-del{color:var(--del)}
  input.search{width:100%;padding:10px 12px;border-radius:10px;border:1px solid var(--border);
               background:var(--surface);color:var(--text);margin:12px 0}
</style>
</head>
<body>
  <div class="wrap">
    <header class="hero"><!-- repo title, filter chips, date span, Expand/Collapse all, search --></header>
    <section class="kpis"><!-- KPI tiles --></section>
    <!-- one <section> per theme, each with commit .card items containing a <details> toggle -->
    <!-- contributor breakdown -->
    <footer><!-- generated timestamp, filter recap --></footer>
  </div>
  <script>
    // Expand/Collapse all toggles every <details>; search box hides non-matching cards.
  </script>
</body>
</html>
```

## Output

After opening the report, give the user a **brief** chat reply: the resolved filters, the
headline stats (commits / files / +/−/ contributors), a one-line executive summary, and the
absolute path to the HTML file. Keep the full detail in the HTML, not the chat.

## Guidelines

- If zero commits match, render a small "no changes in this window" report and say so — don't fabricate.
- Skip merge commits by default (`--no-merges`) unless the user asks for them.
- Don't read every diff on huge ranges; sample the most substantive commits and note the cap.
- Never include secrets or tokens that appear in diffs — redact them as `<redacted>` in the HTML.
- Keep the chat reply short; the HTML is the deliverable.
