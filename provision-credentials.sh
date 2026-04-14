#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# Provision MCP Credentials
# Downloads credentials from an employee repo's GitHub Actions artifact
# and loads them into macOS Keychain for MCP server access.
#
# Usage: ./provision-credentials.sh <owner/repo>
# Example: ./provision-credentials.sh SimpleGlobal-9200-0000-00-Employees/9200-0001-SG-Greg-Gowans
# ============================================================================

EMPLOYEE_REPO="${1:?Usage: provision-credentials.sh <owner/repo>}"

fail() { echo "ERROR: $1" >&2; exit 1; }

# Verify prerequisites
command -v gh >/dev/null || fail "gh CLI not found. Install it first."
command -v python3 >/dev/null || fail "python3 not found."
command -v security >/dev/null || fail "macOS security command not found (not macOS?)."

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

# Step 4: Download and load credentials
echo "Step 4/4 — Downloading and loading credentials..."
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

gh run download "$RUN_ID" --repo "$EMPLOYEE_REPO" --name mcp-credentials --dir "$TMPDIR"

[ -f "$TMPDIR/credentials.json" ] || fail "credentials.json not found in artifact."

python3 << PYEOF
import json, subprocess, base64, sys

with open("$TMPDIR/credentials.json") as f:
    manifest = json.load(f)

if not manifest:
    print("WARNING: Credential manifest is empty. No secrets set on the repo?")
    sys.exit(0)

count = 0
errors = 0

for service, profiles in manifest.items():
    account = f"{service}-mcp"
    svc_label = "M365" if service == "m365" else "Xero"

    for profile, creds in profiles.items():
        for key, value in creds.items():
            keychain_service = f"{profile}-{svc_label}-{key}"
            encoded = f"b64:{base64.b64encode(value.encode()).decode()}"

            # Delete existing entry (ignore if not found)
            subprocess.run(
                ["security", "delete-generic-password",
                 "-s", keychain_service, "-a", account],
                capture_output=True
            )

            # Add new entry
            result = subprocess.run(
                ["security", "add-generic-password",
                 "-s", keychain_service, "-a", account,
                 "-w", encoded, "-T", "",
                 "login.keychain-db"],
                capture_output=True, text=True
            )

            if result.returncode == 0:
                count += 1
                print(f"  OK  {keychain_service} ({account})")
            else:
                errors += 1
                print(f"  ERR {keychain_service}: {result.stderr.strip()}")

print(f"\nLoaded {count} credentials into macOS Keychain.", end="")
if errors:
    print(f" ({errors} errors)")
    sys.exit(1)
else:
    print()
PYEOF

echo ""
echo "Done. MCP servers will use these credentials on next /sg-mcp --auth."
