# Decisions

## eshop-shared-memory-location

- Scope: eShop. Date: 2026-11-02. Status: accepted.
- Decision: keep a single Git-versioned Markdown memory store in `.agents/memory/`, with thin agent entry points instead of tool-specific copies.
- Rationale: share reviewable knowledge across Copilot, Claude Code, and Codex without a service, credentials, or runtime dependencies.
- Evidence: the user selected repo-local memory and approved the design in the setup conversation on 2026-11-02; the recorded [design](../../docs/superpowers/specs/2026-11-02-shared-agent-memory-design.md) captures that agreement.
- Limits: instructions guide agents but do not enforce reads, synchronization, or locking. Separate clones exchange memory through Git.
- Migration: retain this format if moving to a meta repo; see the [memory index](README.md) for the path and evidence-link implications.
