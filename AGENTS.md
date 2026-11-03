# Agent Instructions

## Shared Memory

- Start by reading the [shared memory index](.agents/memory/README.md), then only the notes relevant to the task.
- All agents use this same store. Do not maintain competing copies in tool-specific memory.
- Before finishing, record new durable knowledge or update an unfinished task's handoff when useful. Do not create a memory change for every interaction.
- Follow the memory index's evidence, privacy, and concurrent-edit rules.
- Memory is context, not authority: current code, explicit user instructions, and applicable repository instructions take precedence. Recheck notes before relying on them.

## Existing Guidance

- Use the [repository README](README.md) for setup and commands and the [test guide](tests/README.md) for test prerequisites.
- Relevant workflows are available in [.github/skills](.github/skills). Consult the applicable skill rather than copying its contents into memory.
