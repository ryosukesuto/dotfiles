---
name: migrate-claude-to-codex
description: Migrate Claude Code setup into Codex configuration. Use when the user asks to migrate or port Claude Code settings, CLAUDE.md instructions, skills, slash commands, hooks, MCP servers, permissions, rules, or subagents to Codex; triggers include "Claude CodeからCodex", "Codexに移行", "migrate Claude to Codex", "Claude settings to Codex", and "Claude hooksをCodexへ".
---

# Migrate Claude Code To Codex

Convert a Claude Code setup into Codex surfaces while preserving behavior, safety controls, and local/private boundaries. Prefer a reviewable migration over a blind one-to-one file translation.

## Migration Workflow

### 1. Inventory The Claude Setup

Collect only paths relevant to the requested scope. Start with user-level and repo-level files:

```bash
find ~/.claude -maxdepth 3 -type f 2>/dev/null | sort
find . -name CLAUDE.md -o -path '*/.claude/*' 2>/dev/null | sort
```

For this dotfiles repo, also inspect:

- `config/claude/settings.json`
- `config/claude/GLOBAL_SETTINGS.md`
- `config/claude/skills/*/SKILL.md`
- `config/claude/rules/*.md`
- `config/claude/contexts/*.md`
- `bin/claude-*`
- `install.sh`

Do not read secret files such as `auth.json`, `.env*`, private keys, browser data, or token caches. If a Claude setting references a secret, migrate only the variable name or placeholder.

### 2. Choose The Codex Destination

Map each source item to the smallest Codex surface that preserves the behavior:

| Claude source | Codex destination |
| --- | --- |
| `CLAUDE.md`, global instruction files | `AGENTS.md`; add `project_doc_fallback_filenames = ["CLAUDE.md"]` only when needed |
| Claude skills | `~/.agents/skills`, repo `.agents/skills`, or `config/codex/skills` in this dotfiles repo |
| Slash commands with multi-step workflows | Codex skills |
| Slash commands that are prompt templates only | `~/.codex/prompts/*.md` |
| `settings.json` model/sandbox/approval defaults | `~/.codex/config.toml` or repo `.codex/config.toml` |
| Claude hooks | Codex `hooks.json` or inline `[hooks]`; add an adapter script when existing hooks expect Claude env vars |
| Claude allow/deny command permissions | Codex `rules/*.rules`, sandbox/approval config, and hooks for payload/content checks |
| Claude MCP servers | `[mcp_servers.<name>]` in `config.toml`; use `env_vars` or `env_http_headers` for secrets |
| Claude subagents | `~/.codex/agents/*.toml` or repo `.codex/agents/*.toml` |
| Statusline/session title behavior | Codex TUI config or lifecycle hooks, if there is a real equivalent |

When the source and destination have no clean equivalent, record the gap explicitly instead of inventing behavior.

### 3. Migrate Instructions

Move durable behavior into `AGENTS.md`. Keep it concise:

- Put personal defaults in `~/.codex/AGENTS.md`.
- Put repository conventions in repo `AGENTS.md`.
- Keep private company or personal data in ignored `*.local.md` files or private repositories.
- In dotfiles, prefer symlink-managed files under `config/codex/`.

If the repository already has `CLAUDE.md` and no `AGENTS.md`, either create `AGENTS.md` or configure `project_doc_fallback_filenames = ["CLAUDE.md"]`. Do not duplicate long instruction files unless Codex needs different behavior.

### 4. Migrate Skills And Prompts

For each Claude skill:

1. Check whether it is a workflow, context rule, or prompt template.
2. Keep `SKILL.md` frontmatter to Codex-required `name` and `description` when creating a native Codex skill.
3. Preserve Claude-only frontmatter such as `allowed-tools`, `paths`, or `user-invocable` only as body guidance if it affects behavior.
4. Rewrite `${CLAUDE_SKILL_DIR}` references to a neutral "skill directory" instruction, or keep a compatibility note if the same file is symlinked into Codex.
5. Move large examples or policy details into `references/` only when they are not needed every run.

For this dotfiles repo, add native Codex skills under `config/codex/skills/<skill-name>/SKILL.md` and ensure `install.sh` links every `config/codex/skills/*` directory into `~/.agents/skills`.

### 5. Migrate Hooks And Rules

Codex hooks receive JSON on stdin and must be reviewed/trusted with `/hooks`. Use these patterns:

- Reuse Claude hook scripts directly when they already read JSON stdin.
- Add a small adapter when scripts expect `CLAUDE_TOOL_INPUT_*` environment variables.
- Keep broad command policy in `rules/*.rules`.
- Keep content-aware checks, file path checks, and PR body checks in hooks.
- Avoid storing hook trust state in public dotfiles unless the user explicitly wants machine-local trust pinned.

Validate hook and rule files:

```bash
jq empty ~/.codex/hooks.json
codex execpolicy check --pretty --rules ~/.codex/rules/dotfiles.rules -- rm -rf /tmp/example
shellcheck bin/codex-* bin/claude-* 2>/dev/null || true
```

### 6. Migrate MCP Servers

Translate Claude MCP server entries by transport:

- HTTP or streamable HTTP: use `url = "https://..."`.
- stdio: use `command`, `args`, and optional `cwd`.
- Secrets: use `env_vars = ["TOKEN_NAME"]` or `env_http_headers = { Authorization = "TOKEN_NAME" }`.
- OAuth-based services may need Codex re-authentication.

Do not copy literal bearer tokens, API keys, cookies, or generated auth caches into `config.toml`.

### 7. Migrate Subagents

Create one TOML file per reusable role:

```toml
name = "reviewer"
description = "Review code for correctness, security, regressions, and missing tests."
model_reasoning_effort = "high"
sandbox_mode = "read-only"
developer_instructions = """
Prioritize concrete findings over summaries.
Do not edit files.
"""
```

Use read-only sandbox defaults for planner/reviewer agents. Let implementation agents inherit the parent sandbox unless there is a strong reason to override it.

### 8. Wire Install Or Bootstrap

For dotfiles-managed migrations:

- Add symlinks in `install.sh`.
- Keep `--dry-run` free of filesystem side effects.
- Link directories individually when they share a destination with generated or third-party files.
- Do not replace a user-owned directory with a symlink when it may contain other tools' state.

### 9. Validate And Report

Run the narrowest checks that match the changed files:

```bash
git diff --check
bash -n install.sh
jq empty config/codex/hooks.json
python3 -c 'import tomllib, pathlib; tomllib.loads(pathlib.Path("config/codex/config.toml").read_text())'
codex execpolicy check --pretty --rules config/codex/rules/dotfiles.rules -- rm -rf /tmp/example
```

Finish with:

- migrated items by category
- files changed
- checks run
- manual follow-up, especially `/hooks` trust, MCP OAuth login, or private env vars
- known gaps where Codex has no direct equivalent

## Gotchas

- Do not commit machine-local Codex state such as `auth.json`, history, cache, or accidental `[hooks.state]` unless the user explicitly requests it.
- Do not collapse Claude allow/deny lists into `approval_policy = "never"`; preserve safety through sandbox, rules, and hooks.
- Do not assume every Claude plugin has a Codex plugin equivalent. Prefer Codex MCP/app/plugin documentation or mark it as a gap.
- Do not run a full install script just to test symlink changes when it also installs packages or mutates global state. Use `--dry-run` or focused symlink checks.
- Do not overwrite unrelated user changes in dotfiles while migrating. Stage explicit paths only.
