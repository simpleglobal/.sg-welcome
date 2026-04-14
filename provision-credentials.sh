#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# Provision MCP Credentials
# Downloads credential TOML files from an employee repo's GitHub Actions
# artifact and installs them for MCP server access.
#
# Usage: ./provision-credentials.sh <owner/repo>
# Example: ./provision-credentials.sh SimpleGlobal-9200-0000-00-Employees/9200-0001-SG-Greg-Gowans
#
# The workflow produces .sg-mcp-m365.toml and .sg-mcp-xero.toml matching
# the format used by /sg-mcp --load and --save.
# ============================================================================

EMPLOYEE_REPO="${1:?Usage: provision-credentials.sh <owner/repo>}"

fail() { echo "ERROR: $1" >&2; exit 1; }

# Verify prerequisites
command -v gh >/dev/null || fail "gh CLI not found. Install it first."

echo "=== Provision MCP Credentials ==="
echo "Employee repo: $EMPLOYEE_REPO"
echo ""

# Step 1: Check if the workflow exists in the repo
echo "Step 1/4 — Checking for provision workflow..."
if ! gh workflow list --repo "$EMPLOYEE_REPO" 2>/dev/null | grep -q "provision-credentials"; then
    fail "No provision-credentials workflow found in $EMPLOYEE_REPO.
  Ask an admin to add config/workflows/provision-credentials.yml to the repo's .github/workflows/"
fi

# Step 2: Trigger the workflow
echo "Step 2/4 — Triggering credential provisioning..."
gh workflow run provision-credentials.yml --repo "$EMPLOYEE_REPO"

# Wait for the run to appear
sleep 3
RUN_ID=$(gh run list --repo "$EMPLOYEE_REPO" --workflow provision-credentials.yml --limit 1 --json databaseId --jq '.[0].databaseId')
[ -n "$RUN_ID" ] || fail "Could not find the triggered workflow run."
echo "  Run ID: $RUN_ID"

# Step 3: Wait for completion
echo "Step 3/4 — Waiting for workflow to complete..."
if ! gh run watch "$RUN_ID" --repo "$EMPLOYEE_REPO" --exit-status 2>/dev/null; then
    fail "Workflow run failed. Check: gh run view $RUN_ID --repo $EMPLOYEE_REPO"
fi

# Step 4: Download TOML files and install
echo "Step 4/4 — Downloading and installing credentials..."
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

COUNT=0

# Download M365 credentials
if gh run download "$RUN_ID" --repo "$EMPLOYEE_REPO" --name sg-mcp-m365 --dir "$TMPDIR/m365" 2>/dev/null; then
    TOML_FILE="$TMPDIR/m365/sg-mcp-m365.toml"
    if [ -f "$TOML_FILE" ]; then
        cp "$TOML_FILE" "$HOME/.sg-mcp-m365.toml"
        echo "  OK  ~/.sg-mcp-m365.toml installed"
        COUNT=$((COUNT + 1))
    fi
else
    echo "  --  No M365 credentials provisioned (no secrets set)"
fi

# Download Xero credentials
if gh run download "$RUN_ID" --repo "$EMPLOYEE_REPO" --name sg-mcp-xero --dir "$TMPDIR/xero" 2>/dev/null; then
    TOML_FILE="$TMPDIR/xero/sg-mcp-xero.toml"
    if [ -f "$TOML_FILE" ]; then
        cp "$TOML_FILE" "$HOME/.sg-mcp-xero.toml"
        echo "  OK  ~/.sg-mcp-xero.toml installed"
        COUNT=$((COUNT + 1))
    fi
else
    echo "  --  No Xero credentials provisioned (no secrets set)"
fi

echo ""
if [ "$COUNT" -eq 0 ]; then
    echo "No credential files were produced. Ensure an admin has set secrets on $EMPLOYEE_REPO."
    exit 0
fi

echo "Installed $COUNT credential file(s). Loading to macOS Keychain..."

# Load each TOML into Keychain via the MCP set_credential tool, then delete
for TOML in "$HOME/.sg-mcp-m365.toml" "$HOME/.sg-mcp-xero.toml"; do
    [ -f "$TOML" ] || continue
    SERVICE=$(basename "$TOML" .toml | sed 's/^\.//')  # sg-mcp-m365 or sg-mcp-xero

    python3 << PYEOF
import subprocess, base64, sys

toml_path = "$TOML"
service = "$SERVICE"
account = "m365-mcp" if "m365" in service else "xero-mcp"
svc_label = "M365" if "m365" in service else "Xero"

# Simple TOML parser — handles the credential file format
current_profile = None
key_buf = None
multiline_val = []
in_multiline = False

entries = {}  # {profile: {field: value}}

with open(toml_path) as f:
    for line in f:
        stripped = line.strip()

        if in_multiline:
            if stripped.endswith('"""'):
                multiline_val.append(line.rstrip().rstrip('"').rstrip('"').rstrip('"'))
                entries.setdefault(current_profile, {})[key_buf] = "\n".join(multiline_val)
                in_multiline = False
                key_buf = None
                multiline_val = []
            else:
                multiline_val.append(line.rstrip())
            continue

        if stripped.startswith("[profiles.") and stripped.endswith("]"):
            current_profile = stripped[len("[profiles."):-1]
            continue

        if stripped.startswith("#") or not stripped or not current_profile:
            continue

        if "=" in stripped:
            key, _, val = stripped.partition("=")
            key = key.strip()
            val = val.strip()

            if val.startswith('"""'):
                in_multiline = True
                key_buf = key
                remainder = val[3:]
                if remainder.endswith('"""'):
                    entries.setdefault(current_profile, {})[key] = remainder[:-3]
                    in_multiline = False
                    key_buf = None
                else:
                    multiline_val = [remainder] if remainder else []
            elif val.startswith('"') and val.endswith('"'):
                entries.setdefault(current_profile, {})[key] = val[1:-1]
            else:
                entries.setdefault(current_profile, {})[key] = val

# Map TOML field names to Keychain key suffixes
FIELD_MAP = {
    "client_id": "Client-ID",
    "tenant_id": "Tenant-ID",
    "user_id": "User-ID",
    "cert_thumbprint": "Thumbprint",
    "cert_key": "Private-Key",
    "cert": "Certificate",
    "client_secret": "Client-Secret",
}

count = 0
errors = 0
for profile, fields in entries.items():
    for field, value in fields.items():
        suffix = FIELD_MAP.get(field)
        if not suffix:
            continue  # skip label and unknown fields

        keychain_service = f"{profile}-{svc_label}-{suffix}"
        encoded = f"b64:{base64.b64encode(value.encode()).decode()}"

        subprocess.run(
            ["security", "delete-generic-password", "-s", keychain_service, "-a", account],
            capture_output=True
        )
        result = subprocess.run(
            ["security", "add-generic-password", "-s", keychain_service, "-a", account,
             "-w", encoded, "-T", "", "login.keychain-db"],
            capture_output=True, text=True
        )
        if result.returncode == 0:
            count += 1
            print(f"  OK  {keychain_service}")
        else:
            errors += 1
            print(f"  ERR {keychain_service}: {result.stderr.strip()}")

print(f"  Loaded {count} credentials from {service}", end="")
if errors:
    print(f" ({errors} errors)")
else:
    print()

sys.exit(1 if errors else 0)
PYEOF

    # Delete the TOML file after loading to Keychain
    rm -f "$TOML"
    echo "  DEL $(basename "$TOML") removed (credentials now in Keychain only)"
done

echo ""
echo "Done. TOML files deleted — credentials live in macOS Keychain only."
echo "Run /sg-mcp --auth to obtain OAuth tokens."
