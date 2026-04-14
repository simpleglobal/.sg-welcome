# CLAUDE.md (User-Level — Enterprise Rules)

This file provides enterprise-wide guidance to Claude Code (claude.ai/code) across all SimpleGlobal repositories. It is loaded automatically for every project via `~/.claude/CLAUDE.md`.

Domain-specific rules (document workflows, PDF generation, Xero invoicing) live in their respective plugins and load on-demand. Project-specific context lives in each repo's local `CLAUDE.md`.

## System Architecture

### Core Concepts

```
GitHub Organization                    ↔    Local Folder    ↔    Home Repository
SimpleGlobal-9000-0000-00-Govern            9000-Govern/         9000-Govern
(container for repos)                       (local mirror)       (org home directory)
```

**Each organization contains:**
- `XXXX-Name` — Home directory repo (from `990002-SG-99-SimpleGlobal-Folder` template)
- `.github` / `.github-private` — GitHub config submodules (from 9900-0000-00-Templates)

**Plugins** are centralised in monorepos (`simpleglobal/sm-plugins`, `simpleglobal/sg-plugins`), not in individual org repos.

**Submodules:** `.claude`, `.github`, `.github-private`, `.simpleglobal` — all sourced from 9900-0000-00-Templates.

### Submodule Version Policy

**RULE: All `.claude` submodules MUST track the latest version of `.claude-executive` in SimpleGlobal-9900-0000-00-Templates.**

```bash
# Update a .claude submodule
cd path/to/.claude && git fetch --tags && git checkout vX.X.X.X
cd .. && git add .claude && git commit -m "Update .claude submodule to vX.X.X.X" && git push origin HEAD:main
```

Exceptions: Project-specific `.claude` configurations are permitted but must be documented in the project's local `CLAUDE.md`.

### User Configuration (.userconfig/)

Stores user-specific dotfiles tracked in version control, applied to the home directory via symlinks.

**Key files:** `.claude/` (settings), `.config/` (gh, git), `.gitconfig`, `.zshrc`. OS-specific overrides go in `macos/`, `winos/`, `linux/` subdirectories.

**RULE: Symlinks from `~/` must use `SimpleGlobal/.userconfig/{file}` as target (no `../` prefix).** The `../` form breaks because `~/..` resolves to `/Users/`, not `~/`.

```bash
# CORRECT
ln -s SimpleGlobal/.userconfig/.gitconfig ~/.gitconfig
# WRONG
ln -s ../SimpleGlobal/.userconfig/.gitconfig ~/.gitconfig
```

### Naming Conventions

All SimpleGlobal identifiers follow a consistent `XXXX-XXXX` hyphenated block structure.

#### Organisations and Repositories

| Entity Type | Pattern | Example |
|-------------|---------|---------|
| First-Tier Org | `SimpleGlobal-XX00-0000-00-Name` | `SimpleGlobal-9000-0000-00-Govern` |
| Second-Tier Org | `SimpleGlobal-XXYY-0000-00-Name` | `SimpleGlobal-9200-0000-00-Employees` |
| Simple Sub-Org | `SimpleGlobal-0X00-0000-SM-Name` | `SimpleGlobal-0300-0000-SM-Entertainment` |
| Project Org | `SimpleGlobal-YYYY-0000-00-Projects` | `SimpleGlobal-2026-0000-00-Projects` |
| Local Folder | `XXXX-Name/` | `9000-Govern/` |
| Org Home Repo | `XXXX-Name` | `9000-Govern` |
| Plugin (monorepo subdir) | `sm-{name}` | `sg-govern` (in `sm-plugins`) |
| Default Template | `990001-SG-99-SimpleGlobal-Default` | Standard repo template |
| Folder Template | `990002-SG-99-SimpleGlobal-Folder` | Home directory template |
| Employee Home | `9200-XXXX-ST-SimpleGlobal-Name` | `9200-0001-ST-SimpleGlobal-Greg-Gowans` |

**ID Ranges:**

| Range | Purpose |
|-------|---------|
| 0000-0900 | Simple — uses SM prefix (0100-Architecture, 0200-Digital, 0300-Entertainment, 0400-Industry, 0500-Manufacturing, 0600-Projects) |
| 1000-1900 | Engage (1100-Quotes, 1200-Branding, 1300-Proposals, 1400-Tenders, 1500-Contracts, 1600-References) |
| 2000-2900 | Manage (2019-2029 Projects) |
| 3000-3900 | Design (3100-Mechanical, 3200-Electrical, 3300-Electronics, 3400-Software, 3600-Process, 3700-Products, 3900-Legacy) |
| 4000-4900 | Supply |
| 5000-5900 | Create |
| 6000-6900 | Checks |
| 7000-7900 | Deploy (7100-Installation, 7200-Commissioning, 7300-Training, 7400-Support, 7500-Handover) |
| 8000-8900 | Corpus (8100-Technical, 8200-Regulations, 8300-Training, 8400-Research, 8500-Knowledge, 8600-Vendors) |
| 9000-9900 | Govern (9100-ADR, 9200-Employees, 9300-Compliance, 9400-Corporate, 9500-Forecasting, 9600-Assets, 9700-Standards, 9800-Commands, 9900-Templates, 9999-Enterprise) |
| 990xxx | Template IDs |

**First-tier orgs:** 0000-Simple, 1000-Engage, 2000-Manage, 3000-Design, 4000-Supply, 5000-Create, 6000-Checks, 7000-Deploy, 8000-Corpus, 9000-Govern. Each has second-tier child orgs as shown above, a home directory repo matching its folder name, and a plugin repo.

**RULE: Plugins (`sm-{name}`) exist ONLY for the 10 tier-1 orgs, as subdirectories in the monorepo. Tier-2 orgs inherit their parent's plugin and MUST NOT have their own.**

#### Reference Files Within Org Folders

Files within org-level folders use a sequential prefix derived from the parent folder ID:

| Parent Folder | File Prefix | Example |
|---------------|-------------|---------|
| `1600-References/` | `16XX-` | `1601-Rate-Card.toml`, `1602-Company-Profile.md` |
| `1200-Branding/` | `12XX-` | (brand assets use descriptive names: `sp-black-banner.svg`) |

Pattern: `{ParentPrefix}{Seq}-Title-Case-Name.{ext}` — sequential numbering starting at 01 within the parent's ID range.

#### Enterprise Documents

Documents within repos use: `XXXX-XXXX-XX-MMM-short-description.md`

| Block | Meaning | Example |
|-------|---------|---------|
| 1st (4 digits) | Org location (tier + sub-org) | `9100` (ADR org) |
| 2nd (4 digits) | Document number within repo | `0004` |
| 3rd (2 digits) | Revision | `00` |
| MMM | 3-letter document type | `ADR`, `TPL`, `RFC`, `POL`, `SPC` |

Example: `9100-0004-00-ADR-NamingConventions.md`

#### Projects

| Element | Pattern | Example |
|---------|---------|---------|
| Project ID | `YYYY-NNNN` | `2026-0049` |
| Project folder | `YYYY-NNNN-{Type}-{YY}-Client-Project` | `2026-0049-SI-99-ActionLaser-PowerFailure` |

**Entity type codes:**

| Code | Entity |
|------|--------|
| `SA` | Architecture |
| `SE` | Entertainment |
| `SI` | Industrial |
| `SP` | Projects |

#### Project Documents

Format: `{ProjectID}-{Type}-{DocType}-{Seq}-v{N}.{ext}`

Example: `2026-0049-SI-QUO-0001-v1.pdf`

| Segment | Description | Values |
|---------|-------------|--------|
| ProjectID | YYYY-NNNN project ID | `2026-0049` |
| Type | 2-letter entity type | `SA`, `SE`, `SI`, `SP` |
| DocType | 3-letter document type | See table below |
| Seq | 4-digit sequential number | `0001`, `0002` |
| v{N} | Version number (not zero-padded) | `v1`, `v2` |

**Document type codes:**

| Code | Type |
|------|------|
| `QUO` | Quotation |
| `INV` | Invoice |
| `PUR` | Purchase Order |
| `EXP` | Expenses |
| `RFQ` | Request for Quote |
| `CHK` | Checklist |
| `AUD` | Audit |
| `RPT` | Report |
| `DAT` | Data / Metadata |
| `COM` | Compliance Matrix |

**File naming rules:**

| File type | Pattern | Example |
|-----------|---------|---------|
| Working HTML | `.{DocNum}-v{N}.html` | `.2026-0049-SI-QUO-0001-v1.html` |
| Working CSS | `.{DocNum}-v{N}.css` | `.2026-0049-SI-QUO-0001-v1.css` |
| Working MD | `.{DocNum}-v{N}.md` | `.2026-0049-SI-QUO-0001-v1.md` |
| Distribution PDF | `{DocNum}-v{N}.pdf` | `2026-0049-SI-QUO-0001-v1.pdf` |
| Data file | `{ProjectID}-{Type}-{DocType}-{Description}.toml` | `2026-0051-SE-DAT-ProjectMetadata.toml` |

- Working sources (`.md`, `.html`, `.css`) get a **dot prefix** (hidden files)
- Distribution files (`.pdf`) have **no dot prefix**
- Increment version (`v1` → `v2`) rather than overwriting
- PDF generation uses **WeasyPrint** (not pandoc)

```bash
weasyprint -s .{DocNum}-v1.css .{DocNum}-v1.html {DocNum}-v1.pdf
```

**Legacy format migration:** Old formats (`260049-SI-QU-0001-v1`) use 6-digit IDs and 2-letter doc types. New documents always use the YYYY-NNNN format with 3-letter doc types.

### Synchronization

Local folder structure mirrors remote GitHub organizations. Key sync commands:

| Command | Purpose |
|---------|---------|
| `/sm-orgs --sync-folders` | Pull org structure to local folders |
| `/sm-orgs --sync-profiles` | Apply org profile template to GitHub |
| `/sm-orgs --sync-submodules` | Propagate latest submodule versions |
| `/sm-orgs --sync-visibility` | Enforce repo visibility (internal default, .github public) |
| `/sm-repo --sync-settings` | Apply repo settings template |
| `/sm-repo --sync-remote` | Create GitHub repos for local dirs |

**Rules:** Empty dirs tracked with `.gitkeep`. All home repos are **internal** visibility. Org profiles sourced from `sm-orgs-template.toml`.

### Configuration Propagation

Template inheritance: Source templates in 9900-0000-00-Templates (`.claude-executive`, `.github`, `.github-private`) flow into `990001` (Default) and `990002` (Folder). Those templates create all org home repos. Plugins live in monorepos (`simpleglobal/sm-plugins`, `simpleglobal/sg-plugins`).

**Update flow:** Update source template → pull into 990001/990002 → propagate submodule updates across all repos.

## Plugin Architecture

Every tier-1 org has a plugin (`sm-{name}`) providing Claude Code commands for that domain. All plugins live as subdirectories in a **monorepo**: `simpleglobal/sm-plugins` (SM) and `simpleglobal/sg-plugins` (SG). Tier-2 orgs do not have plugins — they inherit their parent tier-1 plugin.

### Monorepo Structure

```
sm-plugins/                           # simpleglobal/sm-plugins
├── .claude-plugin/
│   └── marketplace.json              # Marketplace manifest (inline, not separate repo)
├── sg-simple/                        # One subdirectory per plugin
│   ├── .claude-plugin/plugin.json    # Plugin manifest (name, version, description)
│   ├── skills/                       # Skills (slash commands)
│   ├── agents/                       # Subagent definitions
│   ├── hooks/                        # Hook configuration
│   ├── scripts/                      # Utility scripts
│   └── templates/                    # Document/code templates
├── sg-engage/
├── sg-manage/
├── ...                               # (10 plugin subdirectories total)
├── CHANGE.md
└── README.md
```

### Marketplace

`marketplace.json` lives inline in the monorepo at `.claude-plugin/marketplace.json`. Each plugin entry uses a relative source path pointing to its subdirectory.

```json
{
  "name": "simpleglobal",
  "plugins": [
    { "name": "sg-govern", "source": "./sg-govern" }
  ]
}
```

Enabled in `.claude/settings.json` via `extraKnownMarketplaces` and `enabledPlugins`.

**Naming:** `sm-{name}` matching the tier-1 org short name (e.g. `sg-govern` for 9000-Govern).

### Creating a New Plugin

Add a new subdirectory to the monorepo:

```bash
# Clone the monorepo
git clone https://github.com/simpleglobal/sm-plugins.git
cd sm-plugins

# Create plugin subdirectory with standard structure
mkdir -p sm-{name}/{.claude-plugin,skills/sm-{name},agents,hooks,scripts,templates}

# Update plugin.json, create SKILL.md, add entry to .claude-plugin/marketplace.json
# Commit, tag, and push
```

### Plugin Versioning

**RULE: The monorepo follows v0.0.0.x versioning. Every commit gets a sequential tag. Individual `plugin.json` versions track the plugin's own version. `marketplace.json` must reflect actual versions.**

After each change: stage → commit → tag `v0.0.0.x` → update CHANGE.md → update individual `plugin.json` version if changed → push.

## MCP Integration Rules

**RULE: ALWAYS use MCP tools for Microsoft 365 and Xero operations. NEVER use alternatives when MCP tools are available.**

| Domain | MCP Server | Use For |
|--------|------------|---------|
| Email, Calendar, Contacts, Teams | M365 (`/sg-mcp-m365`) | All Microsoft 365 operations |
| Invoices, Quotes, POs, Contacts | Xero (`/sg-mcp-xero`) | All Xero operations |

**RULE: Authenticate BEFORE any M365/Xero operation:** `/sm-mcp --auth` (or individually `/sg-mcp-m365 --auth`, `/sg-mcp-xero --auth`). Tokens expire ~1 hour; re-auth on "TokenExpired" or 401 errors.

**Token storage:** macOS Keychain using `{Profile}-{Service}-{Type}` format (profiles: SP, SM). Diagnostics: `/sg-mcp-m365 --status`, `/sg-mcp-xero --status`.

**Keychain encoding:** ALL values in Keychain MUST use `b64:` prefix with Base64-encoded content. TOML files store plaintext; Keychain stores `b64:<base64>`. The `--load` flow encodes (plaintext → `b64:`), the `--save` flow decodes (`b64:` → plaintext). Base credentials are encoded automatically by MCP `set_credential` tools. Certificate credentials stored via `security` CLI MUST be manually encoded with `b64:` prefix.

## Commits and Versioning

### Commit Workflow

**RULE: ALWAYS use `/sm-commit` for all commits. NEVER use manual `git commit`, `git tag`, or manual CHANGE.md updates.**

```bash
git add <files>
/sm-commit "Your commit message" --push
```

This automatically handles submodule commits, CHANGE.md files, tags, and pushing.

**Manual fallback** (only if `/sm-commit` unavailable):

```bash
cd .claude && git add . && git commit -m "message" && git tag vX.X.X.X && git push origin HEAD:main && git push --tags && cd ..
git add .claude && git commit -m "Update .claude submodule" && git tag vX.X.X.X && git push && git push --tags
# Update CHANGE.md in both repos
```

### Versioning Rules

Format: `v0.0.0.x` (Major.Minor.Patch.Build)

- **Every commit gets a sequential tag** in all repos and submodules
- **CHANGE.md** documents every tagged commit: Version, Hash, Date (YYYY-MM-DD HH:MM UTC), Author, Message
- **Default:** Always bump 4th segment. Only bump higher segments for significant changes (3rd = multiple features, 2nd = new org tier, 1st = enterprise breaking change). Reset lower segments to 0 when bumping higher.

```markdown
| Version | Hash | Date | Author | Message |
|---------|------|------|--------|---------|
| v0.0.0.2 | abc1234 | 2026-01-07 09:30 UTC | Greg Gowans | Commit message here |
```

## Date Format Standard

**RULE: All dates MUST use Australian format (DD/MM/YYYY). Day first, month second — never US format.**

| Context | Format | Example |
|---------|--------|---------|
| Documents, emails, UI | DD/MM/YYYY | 02/02/2026 |
| Prose | D Month YYYY | 2 February 2026 |
| Filenames | DDMMYY | 050226 |
| CHANGE.md (exception) | YYYY-MM-DD HH:MM UTC | 2026-02-05 09:30 UTC |

## Configuration Policy

**RULE: All Claude Code project configuration MUST be at project level in git via `.claude/` submodule.**

**Exceptions — user-level config symlinked from `.userconfig/.claude/`:**

| File | Purpose |
|------|---------|
| `~/.claude/CLAUDE.md` | Enterprise rules (this file) |
| `~/.claude/settings.json` | Permissions, marketplace config, effort level |
| `~/.claude/.mcp.json` | User-level MCP servers (sg-mcp-xero, sg-mcp-m365) |
| `~/.claude/plugins/known_marketplaces.json` | Registered plugin marketplaces |

All symlinked via `ln -sf ../SimpleGlobal/.userconfig/.claude/{file}` (relative from `~/.claude/`). Run `/sg-manage:sm-setup` to create or refresh these symlinks.

```
~/.claude/
├── CLAUDE.md              → .userconfig/.claude/CLAUDE.md
├── settings.json          → .userconfig/.claude/settings.json
├── .mcp.json              → .userconfig/.claude/.mcp.json
├── plugins/
│   └── known_marketplaces.json → .userconfig/.claude/plugins/known_marketplaces.json

any-repo/
├── .claude/               # Submodule → .claude-executive (settings, hooks, scripts)
│   └── settings.json      # Permissions, plugins, env
├── .github/               # Submodule → .github (GitHub config & profile assets)
├── .github-private/       # Submodule → .github-private (private GitHub config)
├── .simpleglobal/         # Submodule → .simpleglobal (org framework config)
├── .mcp.json              # Project-specific MCP servers (if any)
├── CLAUDE.md              # Project-specific context
```

## Creating New Repositories

**RULE: All new repos MUST be created from `990001-SG-99-SimpleGlobal-Default` template. All org home repos MUST use `990002-SG-99-SimpleGlobal-Folder` template. All repos are internal visibility.**

```bash
# Standard repo
gh repo create <org>/<repo-name> --template SimpleGlobal-9900-0000-00-Templates/990001-SG-99-SimpleGlobal-Default --internal --description "Description"

# Org home directory repo
gh repo create <org>/<folder-name> --template SimpleGlobal-9900-0000-00-Templates/990002-SG-99-SimpleGlobal-Folder --internal --description "SimpleGlobal - Engineered for Architecture, Entertainment and Industry."
```

After creating: `git clone --recurse-submodules <url>`, update `README.md`, commit and push.

## Important Patterns

- Each configuration domain is a separate Git submodule for independent versioning
- Standard submodules: `.claude`, `.github`, `.github-private`, `.simpleglobal`
- All modules contain: README.md, ASSIGN.md, CHANGE.md
- IP Assignment Agreement applies to all contributions (see ASSIGN.md)
- Use `.gitkeep` files to track empty directories
- **Do not include "Co-Authored-By" trailers in git commits**
- **Commit and push immediately after successful changes** — don't ask, just do it

## Staff Directory

**RULE: Use these email addresses when referencing staff by first name:**

| Name | Email |
|------|-------|
| Greg | greg.gowans@simpleglobal.com |
| Joy | joy.yeoh@simpleglobal.com |
| Kenji | kenji.oates@simpleglobal.com |
| Ryan | ryan.sturgeon@simpleglobal.com |

**Greg's email signature:**
```
Kind Regards,

Greg Gowans (he/him) - Managing Director

Email: greg.gowans@simpleglobal.com
Mobile/WhatsApp: +61 418 888 604
20-22 Hampstead Road,
Auburn NSW, AUSTRALIA.
```
