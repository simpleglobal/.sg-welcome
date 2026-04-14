# .sg-welcome

Executive onboarding bootstrap for SimpleGlobal. Sets up Claude Code, gh CLI, Rust, and the full plugin environment on a fresh Mac with a single command.

## Usage

```bash
curl -fsSL https://get.simplemotion.global/welcome.sh | bash
```

## What it does

The script asks for your **SimpleGlobal email** and infers everything else:

```
Email:  joy.yeoh@simplemotion.global
  ├─→ Name:     Joy Yeoh
  ├─→ GitHub:   Joy-Yeoh-SG
  └─→ Repo:     auto-discovered in SimpleGlobal-9200-0000-00-Employees
```

### Installs

| Tool | Version | Location |
|------|---------|----------|
| Claude Code | Latest | System PATH |
| gh CLI | Latest release | `~/.local/bin/` |
| Rust (rustup) | Stable | `~/SimpleGlobal/.cargo/bin/` |

### Configures

| What | Where | How |
|------|-------|-----|
| Git identity | `~/.gitconfig` | Symlink → `.userconfig/.gitconfig` |
| Shell (zsh) | `~/.zshrc`, `~/.zshenv` | Symlink → `.userconfig/` |
| Claude Code settings | `~/.claude/settings.json` | Symlink → `.userconfig/.claude/` |
| Claude Code rules | `~/.claude/CLAUDE.md` | Symlink → `.userconfig/.claude/` |
| MCP servers | `~/.claude/.mcp.json` | Symlink (all disabled initially) |
| Plugin marketplaces | `~/.claude/plugins/` | Symlink (simplemotion + simpleglobal) |
| gh CLI config | `~/.config/gh/` | Copied (not symlinked — auth tokens) |
| Global gitignore | `~/.config/git/ignore` | Copied |

### Sends

A welcome confirmation email via Microsoft 365 Graph API (GitHub Actions workflow).

## Post-setup

After the script completes, open a new terminal:

```bash
sm                          # Launch Claude Code in ~/SimpleGlobal
/sg-orgs --sync-folders     # Pull org folder structure
/sg-mcp --auth              # Authenticate MCP integrations (when ready)
```

## Admin: onboarding a new executive

Before giving the new exec the curl command:

1. Create their GitHub account (pattern: `Firstname-Lastname-SG`)
2. Invite them to the `simpleglobal-global` enterprise
3. Create their employee repo:

```bash
gh repo create SimpleGlobal-9200-0000-00-Employees/9200-XXXX-SG-Firstname-Lastname \
  --template SimpleGlobal-9900-0000-00-Templates/990002-SG-99-SimpleGlobal-Folder \
  --internal \
  --description "Employee home directory for Firstname Lastname"
```

4. Provision MCP credentials on their employee repo:

```bash
REPO="SimpleGlobal-9200-0000-00-Employees/9200-XXXX-SG-Firstname-Lastname"

# Copy the provision workflow into their repo
gh api repos/$REPO/contents/.github/workflows/provision-credentials.yml \
  --method PUT \
  --field message="Add MCP credential provisioning workflow" \
  --field content="$(base64 -i config/workflows/provision-credentials.yml)"

# Set M365 credentials (certificate auth)
gh secret set SG_M365_CLIENT_ID     -R $REPO -b "<azure-app-client-id>"
gh secret set SG_M365_TENANT_ID     -R $REPO -b "<azure-tenant-id>"
gh secret set SG_M365_USER_ID       -R $REPO -b "firstname.lastname@simplemotion.global"
# Optional: pre-provision certificate (or employee generates locally via /sg-mcp-m365 --generate-cert)
gh secret set SG_M365_CERTIFICATE   -R $REPO -b "$(cat cert.pem)"
gh secret set SG_M365_PRIVATE_KEY   -R $REPO -b "$(cat key.pem)"
gh secret set SG_M365_THUMBPRINT    -R $REPO -b "<cert-thumbprint>"

# Set Xero credentials (OAuth)
gh secret set SP_XERO_CLIENT_ID     -R $REPO -b "<xero-app-client-id>"
gh secret set SP_XERO_CLIENT_SECRET -R $REPO -b "<xero-app-client-secret>"
```

5. Share the curl command with the new exec.

### Post-onboarding: loading credentials to Keychain

After the employee has run the curl command and set up their Mac:

```bash
./provision-credentials.sh SimpleGlobal-9200-0000-00-Employees/9200-XXXX-SG-Firstname-Lastname
```

This triggers the workflow, downloads the credential manifest, and loads everything into macOS Keychain. The employee then runs `/sg-mcp --auth` to obtain OAuth tokens.

**Secret naming convention:**

| Secret Name | Keychain Key | Account |
|---|---|---|
| `{P}_M365_CLIENT_ID` | `{P}-M365-Client-ID` | `m365-mcp` |
| `{P}_M365_TENANT_ID` | `{P}-M365-Tenant-ID` | `m365-mcp` |
| `{P}_M365_USER_ID` | `{P}-M365-User-ID` | `m365-mcp` |
| `{P}_M365_CERTIFICATE` | `{P}-M365-Certificate` | `m365-mcp` |
| `{P}_M365_PRIVATE_KEY` | `{P}-M365-Private-Key` | `m365-mcp` |
| `{P}_M365_THUMBPRINT` | `{P}-M365-Thumbprint` | `m365-mcp` |
| `{P}_XERO_CLIENT_ID` | `{P}-Xero-Client-ID` | `xero-mcp` |
| `{P}_XERO_CLIENT_SECRET` | `{P}-Xero-Client-Secret` | `xero-mcp` |

Profiles: `SM` (SimpleMotion), `SG` (SimpleGlobal), `SP` (Projects), `SA` (Architecture), `SI` (Industry), `SE` (Entertainment)

## Architecture

See [docs/WORKFLOW.md](docs/WORKFLOW.md) for full design rationale, config file details, and symlink conventions.

## Prerequisites

- macOS (Darwin)
- Internet access
- Git (pre-installed with Xcode Command Line Tools)

## License

MIT — SimpleGlobal.Global Pty Ltd. See [ASSIGN.md](ASSIGN.md).
