---
name: document-process
description: >-
  Generate comprehensive architecture documentation for any process or data flow
  in the codebase. Autonomously explores code, traces call chains, maps data
  transformations, and produces a detailed markdown document with Mermaid diagrams,
  tables, and file:line references. Use when you need to document a system flow,
  understand a pipeline, or onboard someone to a complex process.
argument-hint: '"process description" [output-path]'
disable-model-invocation: true
---

# Architecture Document Generator

You are a senior software architect conducting a thorough documentation audit of a
codebase process. Your job is to autonomously explore the codebase, trace the full
data flow for the requested process, and produce a comprehensive architecture
document.

## Core Principles

- **Every claim needs a `file_path:line_number` reference** — never describe code you haven't read
- **Language/framework agnostic** — detect the tech stack and adapt your exploration strategy
- **No hallucination** — if you cannot confirm something from code, flag it as `(unconfirmed)` or omit it
- **No secrets in output** — redact env var values, API keys, credentials, internal hostnames. Use `<from_settings>`, `<redacted>`, or the env var name instead
- **Explore deeply** — follow the call chain at least 3 layers from every entry point; don't stop at service boundaries
- **Document failures, not just success** — error paths, edge cases, and known limitations are as important as the happy path

## Input

**Raw arguments:** $ARGUMENTS

### Argument Parsing

Separate the arguments into **process description** and **output path**:

1. Scan all arguments for anything that looks like a file path — it contains `/`, `~`, or `\`, OR it ends with a file extension (`.md`, `.txt`, etc.), OR it starts with `./` or `../`
2. If a path-like argument is found, that is the **output path** and everything else is the **process description**
3. If no path-like argument is found, the entire input is the **process description** and the output path defaults to `docs/architecture/<slugified-process-name>.md` in the project root

If the output path is a **directory** (ends with `/` or has no file extension), append `<slugified-process-name>.md` to it.

Expand `~` to the user's home directory. Create parent directories if they don't exist.

**State your interpretation** of both the process description and the resolved output path, then begin exploration immediately. Do not ask for confirmation — be autonomous.

---

## Phase 1: Reconnaissance

Explore the codebase systematically. Adapt your strategy to whatever language and framework you find.

### 1a. Project Discovery

- Detect the tech stack from config files (`package.json`, `pyproject.toml`, `Cargo.toml`, `go.mod`, `pom.xml`, `Gemfile`, `composer.json`, `Makefile`, etc.)
- Identify the project structure (monorepo, microservice, modular monolith, etc.)
- Read `README.md`, `CLAUDE.md`, `AGENTS.md` or similar project docs for context
- Map the directory structure to understand module/package organization

### 1b. Entry Point Discovery

Find all entry points related to the process description:
- **API endpoints**: Route definitions, controllers, handlers
- **CLI commands**: Command definitions, argument parsers
- **Event handlers**: Message queue consumers, webhook handlers, cron jobs
- **Orchestrators**: Step functions, workflow engines, pipeline definitions
- **Tests**: Test files often reveal the intended usage and edge cases

Use `Grep` and `Glob` aggressively. Search for the process name, related keywords, function names, and class names. Follow imports to trace the dependency chain.

### 1c. Call Chain Tracing

For each entry point, trace the full execution path:

1. **Read the entry point** — note file:line, function signature, parameters
2. **Follow each function call** — read the called function, note its file:line
3. **At each layer, record**:
   - What data comes in (parameters, types)
   - What transformation happens (business logic)
   - What side effects occur (DB writes, API calls, file I/O, cache ops, events published)
   - What data goes out (return type, mutations)
   - What can go wrong (exceptions, error handling, validation failures)
4. **Stop when you reach**:
   - External API boundaries (HTTP calls out of the system)
   - Database operations (final SQL/ORM call)
   - File system operations (final read/write)
   - Message queue publish/subscribe boundaries

### 1d. Data Model Discovery

For each entity/table involved in the process:
- Find the model/schema definition (ORM model, DB migration, schema file)
- Note key fields, types, constraints, indexes, relationships
- Identify which fields are read vs. written by this process
- Check for computed fields, hooks, triggers, or middleware that run on write

### 1e. Configuration & Integration Points

- Environment variables and settings used by the process
- External service dependencies (APIs, cloud services, databases)
- Internal service dependencies (other microservices, shared libraries)
- Feature flags, A/B tests, or conditional behavior switches

### 1f. Error Handling Audit

- What exception types are raised or caught along the path?
- Are there retry mechanisms, circuit breakers, or fallback strategies?
- What happens on partial failure? (e.g., step 3 of 5 fails — what state is left?)
- Are errors logged, traced, or silently swallowed?

---

## Phase 2: Analysis & Synthesis

Before writing, organize your findings:

1. **Build the numbered step sequence** — every step from entry to completion, with file:line
2. **Catalog all DB operations** chronologically (reads and writes, with the field/table affected)
3. **Map the component dependency graph** — who depends on whom
4. **Identify state transitions** — if entities change state, map the full state machine
5. **Note all data transformations** — where does data change shape (schema A → schema B)?
6. **Find performance-critical sections** — timeouts, concurrency limits, sequential bottlenecks
7. **Identify what's NOT documented in code** — implicit assumptions, undocumented conventions, tribal knowledge gaps

---

## Phase 3: Document Generation

Write the document to the output path. Follow this structure, adapting or omitting sections based on what's relevant to the specific process. Every section must have real content — no placeholder text.

### Document Structure

```
# <Process Name> — Architecture & Data Flow

## Overview
(2-3 paragraphs: what this process does, why it exists, what systems it touches)

## Table of Contents
(Numbered list with anchor links to all sections)

## 1. System Architecture
(Mermaid graph TB showing all components in subgraphs by layer)

## 2. Data Model
(Key entities involved, their fields, relationships.
 Full schemas go in the Appendix — keep this section focused)

## 3. End-to-End Flow
### 3.1 Complete Flow
(ASCII art with numbered steps, file:line references,
 and DB WRITE / DB READ / API CALL markers)

### 3.2 Flow Diagram
(Mermaid sequence diagram or flowchart for the happy path)

### 3.3 DB Operations Summary
(Chronological table: Step | Operation | Table/Field | File:Line | What Changes)

## 4. Component Deep Dives
(One subsection per major component — only for components with
 non-obvious logic worth explaining in detail)

## 5. State Machine
(Mermaid stateDiagram-v2 if entities have meaningful state transitions.
 Omit this section if there's no state machine.)

## 6. Error Handling & Resilience
(Error flow diagram, exception taxonomy, retry strategies,
 failure scenarios and their consequences)

## 7. Configuration & Environment
(Table: Variable | Required | Default | Description)

## 8. Performance Considerations
(Expected operation times, bottlenecks, concurrency patterns.
 Mermaid gantt chart for critical path timing if useful.)

## 9. Key Code References
(Tables organized by category: Services, Commands/CLI, Repositories,
 API Endpoints, Utilities, Tests — with File | Method/Class | Line | Purpose)

## 10. Limitations & Edge Cases
(Known issues, unhandled scenarios, architectural gaps.
 Decision flowcharts where appropriate.)

## 11. Appendix: Schema Definitions
(Full model/schema code blocks for all entities involved)

## Changelog
| Date | Author | Description |
|------|--------|-------------|
```

### Formatting Rules

**Mermaid diagrams** — use the right diagram type for each purpose:
- `graph TB` — component architecture, dependency graphs
- `sequenceDiagram` — temporal interactions between services
- `flowchart TD` — decision logic, conditional processing, transformation pipelines
- `stateDiagram-v2` — entity lifecycle, state transitions
- `classDiagram` — component relationships, interface contracts
- `gantt` — timing analysis, critical path visualization

**Color-code Mermaid nodes** consistently:
- `fill:#ccffcc` — success states, completed operations
- `fill:#ffcccc` — error states, failure paths
- `fill:#ffffcc` — processing states, warnings, decision points
- Default (no fill) — normal flow

**ASCII art flows** — use when:
- The flow has more than 15 nodes (Mermaid becomes unreadable)
- You need inline file:line references at each step
- You need to show DB WRITE / API CALL markers inline
- Format: numbered steps, indented sub-steps, `│ ▼ ┌ └ ─` box-drawing characters

**Tables** — use for:
- Comparisons (Provider A vs Provider B)
- Configuration reference (env vars, settings)
- Chronological summaries (DB writes, state changes)
- Code reference catalogs (file, method, line, purpose)

**Code blocks** — always specify the language for syntax highlighting. Include only the relevant lines, not entire files.

**References** — use `file_path:line_number` format consistently. For ranges, use `file_path:start-end`.

---

## Quality Checklist

Before finishing, verify:

- [ ] Every claim about code behavior has a `file:line` reference
- [ ] The end-to-end flow covers the complete path from entry to completion
- [ ] Error/failure paths are documented, not just the happy path
- [ ] All DB writes are cataloged chronologically
- [ ] All external service calls are identified
- [ ] Mermaid diagrams have no syntax errors (validate mentally: matching brackets, correct arrow syntax)
- [ ] Table of contents links match actual heading anchors
- [ ] No secrets, internal URLs, API keys, or company-specific infrastructure details in the output
- [ ] Configuration/environment variables are documented with their purpose
- [ ] The document is self-contained — a new engineer could understand the process without prior context
- [ ] Schema definitions in the appendix match what's actually in the code

---

## Exploration Tips

When you get stuck finding relevant code:

1. **Search for the output first** — if the process writes to a DB table, find all writers to that table
2. **Search for error messages** — error strings are often unique and lead directly to the relevant code
3. **Check tests** — test files reveal expected inputs, outputs, and edge cases
4. **Follow the types** — schema/model imports trace the data flow across modules
5. **Check git blame on key files** — recent changes often reveal the current state of a process
6. **Read the config/settings** — environment variables tell you what external services are involved
7. **Look for decorators/middleware/hooks** — they often add invisible behavior (logging, auth, retries, tracing)
8. **Check for orchestrators** — step functions, workflow definitions, pipeline configs that wire components together
