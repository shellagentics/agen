# Prompt Versioning

This directory contains versioned prompts used to build and guide the `agent` CLI.

## Why Version Prompts?

Prompts are code. They deserve the same rigor as application code:

- **Reproducibility** — Debug issues by knowing exactly which prompt produced an output
- **Collaboration** — Track who changed what, when, and why
- **Rollback** — Revert to previous versions when changes cause regressions
- **Auditability** — Maintain history for compliance and learning

## Versioning Scheme

We use **Semantic Versioning (SemVer)** for prompts:

```
MAJOR.MINOR.PATCH (e.g., 1.2.3)
```

| Change Type | Version Bump | Example |
|-------------|--------------|---------|
| Breaking changes to prompt structure/intent | MAJOR | 1.0.0 → 2.0.0 |
| New sections, features, or context | MINOR | 1.0.0 → 1.1.0 |
| Typo fixes, clarifications, formatting | PATCH | 1.0.0 → 1.0.1 |

## File Format

Each prompt file uses YAML frontmatter for metadata:

```yaml
---
prompt_id: unique-identifier
version: 1.0.0
created_at: 2026-01-23
updated_at: 2026-01-23
author: human|ai|team-member-name
status: active|deprecated|experimental
model_target: claude-sonnet-4-20250514
tags: [category, purpose, feature]
---

# Prompt Title

[Prompt content here]

---

## Changelog

### v1.0.0 (YYYY-MM-DD)
- Initial version
```

## Metadata Fields

| Field | Required | Description |
|-------|----------|-------------|
| `prompt_id` | Yes | Unique identifier, kebab-case |
| `version` | Yes | SemVer version string |
| `created_at` | Yes | ISO date of creation |
| `updated_at` | Yes | ISO date of last modification |
| `author` | Yes | Who created/modified the prompt |
| `status` | Yes | `active`, `deprecated`, or `experimental` |
| `model_target` | No | Intended model (may work with others) |
| `tags` | No | Categorization for discovery |

## Directory Structure

```
prompts/
├── README.md           # This file
├── BUILD_PROMPT.md     # Main build specification prompt
├── SYSTEM_PROMPT.md    # System prompts for agent (future)
└── archive/            # Deprecated prompts (future)
```

## Naming Conventions

- Use `SCREAMING_SNAKE_CASE.md` for prompt files
- Use descriptive names: `BUILD_PROMPT.md`, `SYSTEM_PROMPT.md`, `DEBUG_PROMPT.md`
- Prefix experimental prompts: `EXPERIMENTAL_feature.md`

## Best Practices

### 1. Document Changes

Every version bump must include a changelog entry:

```markdown
### v1.1.0 (2026-01-24)
- Added section on error handling patterns
- Clarified exit code semantics
```

### 2. One Purpose Per Prompt

Each prompt file should have a single, clear purpose. Split complex prompts into composable pieces.

### 3. Include Context

Prompts should be self-contained. Include:
- Why this prompt exists
- What it's trying to achieve
- Any constraints or assumptions

### 4. Test Before Versioning

Before bumping a version, verify the prompt produces expected results with the target model.

### 5. Never Delete, Deprecate

Instead of deleting prompts, mark them as `status: deprecated` and move to `archive/` directory.

## Current Prompts

| File | Version | Status | Description |
|------|---------|--------|-------------|
| `BUILD_PROMPT.md` | 1.0.0 | active | Main specification for building the agent CLI |

## References

- [Prompt Versioning Best Practices (Maxim AI)](https://www.getmaxim.ai/articles/prompt-versioning-and-its-best-practices-2025/)
- [Mastering Prompt Versioning (DEV Community)](https://dev.to/kuldeep_paul/mastering-prompt-versioning-best-practices-for-scalable-llm-development-2mgm)
- [Prompt Management Guide (LaunchDarkly)](https://launchdarkly.com/blog/prompt-versioning-and-management/)
