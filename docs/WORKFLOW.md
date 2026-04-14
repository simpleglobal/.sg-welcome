# Workflow Documentation

Full design rationale and implementation details for the SimpleGlobal executive onboarding bootstrap.

## Overview

A single `curl | bash` command bootstraps a fresh Mac with everything needed to work in the SimpleGlobal Claude Code environment:

```bash
curl -fsSL https://get.simplemotion.global/welcome.sh | bash
```

## Design Decisions

### Email-only identity

The script asks for one thing: the user's `@simplemotion.global` email. Everything else is inferred:

- **Full name**: title-case the email prefix, split on `.` (e.g. `joy.yeoh` → `Joy Yeoh`)
- **GitHub username**: title-case, hyphenated, `-SG` suffix (e.g. `Joy-Yeoh-SG`)
- **Employee repo**: discovered via `gh repo list` against the Employees org

This minimises user input and enforces naming consistency.

### Disabled MCP servers

The `.mcp.json` template has `sg-mcp-xero` and `sg-mcp-m365` set to `disabled: true` with empty command paths. On a fresh machine, the MCP Rust binaries don't exist yet. They are compiled and configured later via `/sg-mcp --init` once the user is working in Claude Code.

All 11 official Claude AI connectors (`claude_ai_Asana`, etc.) are also explicitly disabled per enterprise policy — SimpleGlobal uses custom MCP servers only.

### gh config: copied, not symlinked

The `~/.config/gh/` files are **copied** from `.userconfig/` rather than symlinked. This is because `gh auth login` writes OAuth tokens directly into `hosts.yml`. If it were a symlink to a git-tracked file, those tokens would appear as uncommitted changes (or worse, get committed).

### .zshenv Cargo guard

The original `.zshenv` does a bare `. "$CARGO_HOME/env"` which fails on a fresh system before Rust is installed. The template wraps this in `if [ -f "$CARGO_HOME/env" ]` so the shell starts cleanly even without Rust.

### Rust in ~/SimpleGlobal/.cargo/

Rust is installed with `CARGO_HOME=~/SimpleGlobal/.cargo` and `RUSTUP_HOME=~/SimpleGlobal/.rustup`, keeping all tooling inside the project tree. The `--no-modify-path` flag prevents rustup from editing shell configs (`.zshenv` already handles PATH).

### gh CLI in ~/.local/bin/

The gh CLI binary is downloaded as a zip and extracted to `~/.local/bin/` (no `sudo` required, no Homebrew). This path is already on `$PATH` via `.zshrc`.

## init.sh Step-by-Step

| Step | Action | Detail |
|------|--------|--------|
| 1 | Preflight | Verify macOS, git, not root, detect arch |
| 2 | Collect email | Single prompt, infer name + GitHub username, confirm |
| 3 | Clone config repo | `git clone .sg-welcome` to `/tmp/` for template files |
| 4 | Install Claude Code | `curl -fsSL https://claude.ai/install.sh \| sh` |
| 5 | Install gh CLI | Download latest release zip, extract to `~/.local/bin/` |
| 6 | GitHub auth | `gh auth login --web` (browser OAuth flow) |
| 7 | Clone employee repo | Search Employees org, clone to `~/SimpleGlobal` (or mkdir fallback) |
| 8 | Install Rust | rustup with custom CARGO_HOME/RUSTUP_HOME, `--no-modify-path` |
| 9 | Deploy config | Copy templates to `~/SimpleGlobal/.userconfig/`, sed placeholders |
| 10 | Create symlinks | Home-level + Claude-level symlinks, gh config copied |
| 11 | Welcome email | `gh workflow run welcome.yml` triggers M365 email |
| 12 | Cleanup | Remove `/tmp` clone, print summary and next steps |

## Symlink Conventions

Two categories with different relative-path patterns:

### Home-level (`~/` → `SimpleGlobal/.userconfig/`)

```
~/.gitconfig  → SimpleGlobal/.userconfig/.gitconfig
~/.zshenv     → SimpleGlobal/.userconfig/.zshenv
~/.zshrc      → SimpleGlobal/.userconfig/.zshrc
```

Target path is relative to `~/` — no `../` prefix (enterprise rule: `~/..` resolves to `/Users/`, not `~/`).

### Claude-level (`~/.claude/` → `../SimpleGlobal/.userconfig/.claude/`)

```
~/.claude/CLAUDE.md       → ../SimpleGlobal/.userconfig/.claude/CLAUDE.md
~/.claude/settings.json   → ../SimpleGlobal/.userconfig/.claude/settings.json
~/.claude/.mcp.json       → ../SimpleGlobal/.userconfig/.claude/.mcp.json
```

Target uses `../` because the symlink lives inside `~/.claude/`, so `../` goes up to `~/`.

### Plugins (`~/.claude/plugins/` → `../../SimpleGlobal/...`)

```
~/.claude/plugins/known_marketplaces.json → ../../SimpleGlobal/.userconfig/.claude/plugins/known_marketplaces.json
~/.claude/plugins/blocklist.json          → ../../SimpleGlobal/.userconfig/.claude/plugins/blocklist.json
```

Two levels of `../` because the symlink is inside `~/.claude/plugins/`.

## Config File Reference

### Templatised (placeholders replaced by init.sh)

| File | Placeholders |
|------|-------------|
| `config/.gitconfig` | `{{USER_NAME}}`, `{{USER_EMAIL}}` |
| `config/gh/hosts.yml` | `{{GITHUB_USERNAME}}` |

### Shared (copied verbatim)

| File | Purpose |
|------|---------|
| `config/.zshenv` | Cargo/Rust PATH with if-guard |
| `config/.zshrc` | Shell aliases (sm, sg, ls, la) |
| `config/claude/CLAUDE.md` | Enterprise rules (~405 lines) |
| `config/claude/settings.json` | Marketplaces, deny claude_ai, effort high |
| `config/claude/.mcp.json` | All MCP servers disabled |
| `config/claude/plugins/known_marketplaces.json` | simplemotion + simpleglobal marketplaces |
| `config/claude/plugins/blocklist.json` | Empty plugin blocklist |
| `config/gh/config.yml` | gh CLI defaults (HTTPS, prompt enabled) |
| `config/git/ignore` | Global gitignore (settings.local.json) |

## Welcome Email

Triggered via GitHub Actions (`welcome.yml`) after successful GitHub auth.

### Prerequisites

Repository secrets in `simpleglobal/.sg-welcome`:

| Secret | Value |
|--------|-------|
| `AZURE_TENANT_ID` | SimpleGlobal Azure AD tenant ID |
| `AZURE_CLIENT_ID` | Azure AD app registration client ID |
| `AZURE_CLIENT_SECRET` | Azure AD app registration client secret |

The Azure AD app requires `Mail.Send` application permission for `greg.gowans@simplemotion.global`.

### Email content

- Subject: "Welcome to SimpleGlobal — Setup Complete"
- From: `greg.gowans@simplemotion.global`
- Body: confirmation + quick-start guide + link to this repo

## Known Issues

1. **`.claude-executive` hardcoded paths**: The `.claude-executive` submodule `settings.json` (in `SimpleGlobal-9900-0000-00-Templates`) contains hardcoded `/Users/greg.gowans/**` permission paths. This affects all repos, not just welcome — the fix must happen in the `.claude-executive` source template, then propagate via submodule updates. New users will get permission denials until this is resolved.

2. **Employee repo must pre-exist**: Admin must create the employee repo from the folder template and invite the GitHub user BEFORE the new exec runs the init script.

3. **Azure AD secrets**: The welcome email workflow requires Azure AD app credentials configured as repository secrets. Without these, the email step is skipped (non-fatal).

4. **CLAUDE.md template drift**: The `config/claude/CLAUDE.md` is a static copy of the enterprise rules. It will drift as the user-level `CLAUDE.md` evolves via `.claude-executive` submodule updates. Accepted trade-off — new execs get a working starting point, and subsequent updates arrive via the `.claude-executive` submodule in their employee repo.

## Verification Checklist

After running the script on a fresh Mac:

- [ ] `claude --version` returns a version
- [ ] `gh --version` returns a version
- [ ] `rustc --version` returns a version
- [ ] `ls -la ~/.zshrc` shows symlink → `SimpleGlobal/.userconfig/.zshrc`
- [ ] `ls -la ~/.zshenv` shows symlink → `SimpleGlobal/.userconfig/.zshenv`
- [ ] `ls -la ~/.gitconfig` shows symlink → `SimpleGlobal/.userconfig/.gitconfig`
- [ ] `ls -la ~/.claude/CLAUDE.md` shows symlink → `../SimpleGlobal/.userconfig/.claude/CLAUDE.md`
- [ ] `ls -la ~/.claude/settings.json` shows symlink → `../SimpleGlobal/.userconfig/.claude/settings.json`
- [ ] `cat ~/.config/gh/hosts.yml` shows the correct GitHub username
- [ ] `git config user.name` returns the correct name
- [ ] `git config user.email` returns the correct email
- [ ] Opening a new terminal and typing `sm` launches Claude Code in `~/SimpleGlobal`
- [ ] Running `/sg-orgs --sync-folders` in Claude Code pulls the org structure
- [ ] Welcome email received in inbox
