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
# The workflow produces .sm-mcp-m365.toml and .sm-mcp-xero.toml matching
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
if [ "$COUNT" -gt 0 ]; then
    echo "Installed $COUNT credential file(s). Next steps:"
    echo "  1. Run /sg-mcp --load to push credentials to macOS Keychain"
    echo "  2. Run /sg-mcp --auth to obtain OAuth tokens"
else
    echo "No credential files were produced. Ensure an admin has set secrets on $EMPLOYEE_REPO."
fi
