# Shared Agent Memory Design

Approved by the user on 2026-11-02.

## Intent And Scope

Provide repo-local, Git-versioned Markdown memory for Copilot, Claude Code, and Codex: a short index, verified facts, durable decisions, and actionable handoffs. Thin entry points route agents to one store. This is documentation only, with no external service or application changes.

## Approaches

The user selected repo-local memory over an external memory service or isolated tool-native memory. It is portable and reviewable without infrastructure, but discovery remains tool-dependent and separate clones require Git synchronization. The user also asked about future promotion into a meta repo; keep the format self-contained to support that migration.

## Constraints

Record dated evidence, distinguish assumptions and unrun checks, avoid secrets and transcripts, link rather than duplicate documentation, and recheck stale notes. Memory is context, not higher-priority instructions. Handoffs are not locks; preserve concurrent edits and coordinate overlaps. Do not commit or change branches as part of setup.

## Implementation Choices

Use `.agents/memory/` for the index and three note files. Use root `AGENTS.md` for Copilot/Codex discovery and `CLAUDE.md` to import it for Claude Code, avoiding duplicate Copilot instructions. Verify local links, entry-point routing, Git visibility, and whitespace. Live behavior across all three clients is outside the static checks.
