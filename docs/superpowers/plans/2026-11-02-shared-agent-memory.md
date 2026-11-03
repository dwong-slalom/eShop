# Shared Agent Memory Implementation Plan

> **For agentic workers:** Use the executing-plans workflow for this documentation-only setup.

**Goal:** Add one portable, repo-local memory store shared by development agents.

**Architecture:** Root entry points route agents to a small Markdown index and topic notes. Git provides versioning; there is no runtime service or synchronization process.

**Tech Stack:** Markdown, Git, and Node.js for a one-off static link check.

**Spec:** [Approved design](../specs/2026-11-02-shared-agent-memory-design.md).

## Global Constraints

Documentation only. No secrets, duplicate memory stores, application changes, commits, or branch changes. Preserve existing work.

## Review Focus

Broken relative links, divergent tool instructions, unsupported automatic-sync claims, stale evidence, and unsafe concurrent-edit guidance.

## Task 1: Shared Memory And Discovery

- [x] Create root `AGENTS.md` and `CLAUDE.md`, plus `.agents/memory/README.md`, `facts.md`, `decisions.md`, and `handoffs.md`.
- [x] Seed only source-verified knowledge and the approved memory decision; provide an empty handoff template.
- [x] Run a static check resolving Markdown links and the Claude import, checking required safety guidance, and confirming files are not ignored by Git.
- [x] Check whitespace and review the resulting documentation; report that live cross-client discovery was not tested.

Validation on 2026-11-03: one-off Node.js assertions passed for eight files and 15 relative links, entry-point routing, safety guidance, ASCII/whitespace, and Git visibility. Live cross-client discovery and application tests were not run. No commits were created.
