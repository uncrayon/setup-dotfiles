---
name: investigate-bug
description: Investigate a production bug systematically — trace error logs to root cause, gather evidence from code/DB/traces, and produce a comprehensive bug report. Use when a production error needs diagnosis.
disable-model-invocation: true
argument-hint: "[error description, log snippet, or trace ID]"
---

# Production Bug Investigation

You are investigating a production bug. Follow this process methodically, gathering evidence at each step before moving to the next. The goal is a comprehensive bug report with full evidence chain.

## Input

The user will provide one or more of: error logs, trace ID (Datadog, OpenTelemetry, etc.), stack trace, error message, or a description of the symptom.

Arguments: $ARGUMENTS

## Phase 1: Understand the Error

1. **Parse the error**: Identify the exception type, error message, exit codes, and any file/line references
2. **Extract identifiers**: Trace IDs, entity IDs, request IDs, timestamps, service names — anything that helps correlate logs
3. **Identify the service**: Which service/command produced the error (check trace metadata, CLI command, API endpoint)
4. **Establish timeline**: Note all timestamps to understand the sequence of events

## Phase 2: Trace the Code Path

1. **Find the crash site**: Read the file and line from the stack trace
2. **Trace upstream**: Follow the call chain backwards — what called this function, with what arguments?
3. **Check data types**: Look for type mismatches between function signatures and actual callers (type hints vs runtime values)
4. **Map the full path**: Document the complete call chain from entry point (CLI/API) to crash site with file:line references

## Phase 3: Identify the Root Cause

1. **Analyze the failing calculation or operation**: What exact values caused the failure?
2. **Check edge cases**: What input ranges are unhandled? What assumptions does the code make?
3. **Look for contributing factors**: Type coercion, integer division, missing validation, race conditions
4. **Determine if it's deterministic or intermittent**: Can every invocation trigger it, or only under specific conditions?

## Phase 4: Gather Evidence

Collect evidence from multiple sources to build a complete picture:

1. **Code references**: Exact file paths, line numbers, and code snippets for every relevant location
2. **Database queries**: If the error involves data, suggest SQL queries the user can run to inspect the actual data involved (use object IDs from logs)
3. **Log correlation**: Guide the user to find related logs in their observability platform using trace ID, service name, and time range
4. **Reproduction attempts**: If possible, suggest how to reproduce locally. If reproduction fails, document what was tried and what it ruled out

## Phase 5: Write the Bug Report

Create a comprehensive report with this structure:

```markdown
# Bug Report: <Clear title describing the crash>

## Incident Summary
| Field | Value |
|-------|-------|
| **Date** | <UTC timestamp> |
| **Service** | <service name> |
| **Trace ID** | <if available> |
| **Identifiers** | <entity IDs, request IDs, etc.> |
| **Command / Endpoint** | <what was invoked> |
| **Severity** | <High/Medium/Low — explain impact> |

## Error
<The exact error message and stack trace>

## Root Cause Analysis
<Detailed explanation with code references>

## Evidence Chain
<Numbered evidence items: logs, SQL results, code analysis, reproduction results>

## Code Path
<Full call chain from entry point to crash, with file:line>

## Impact
<What breaks, blast radius, frequency>

## Recommended Fix
<Specific code changes with file:line references>

## Files Referenced
<Table of all files involved>
```

## Guidelines

- **Never guess**: If you don't have evidence for a claim, say so and suggest how to get it
- **Show your work**: Include the actual log lines, SQL queries, code snippets — not just conclusions
- **Quantify the edge case**: If the bug is triggered by specific value ranges, show the math (e.g., `int(3/4.713) = 0`)
- **Check type mismatches**: Python doesn't enforce type hints at runtime — a function declaring `int` can receive `float`
- **Consider the happy path**: Explain why the bug doesn't always trigger (what conditions make it work vs fail)
- **Two-layer analysis**: Identify both the immediate cause (what crashed) and the deeper cause (why the bad value was produced)
- **Ask the user for data you can't access**: Database results, observability screenshots, environment details — guide them with exact queries/filters to use
