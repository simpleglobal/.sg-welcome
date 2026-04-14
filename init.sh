#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# SimpleGlobal Executive Onboarding Bootstrap
# Usage: curl -fsSL https://get.simplemotion.global/welcome.sh | bash
# ============================================================================

INIT_REPO="https://github.com/simpleglobal/.sg-welcome.git"
INIT_DIR="/tmp/.sg-welcome"
EMPLOYEES_ORG="SimpleGlobal-9200-0000-00-Employees"

# ── Helpers ─────────────────────────────────────────────────────────────────

info()  { echo "  [*] $*"; }
ok()    { echo "  [+] $*"; }
warn()  { echo "  [!] $*"; }
fail()  { echo "  [x] $*" >&2; exit 1; }

# ── Step 1: Preflight ──────────────────────────────────────────────────────

echo ""
echo "  SimpleGlobal — Executive Onboarding"
echo "  ======================================"
echo ""

[[ "$(uname)" == "Darwin" ]] || fail "macOS required. This script does not support $(uname)."
command -v git >/dev/null    || fail "git not found. Install Xcode Command Line Tools: xcode-select --install"
[[ $EUID -ne 0 ]]           || fail "Do not run as root."

ARCH=$(uname -m)
info "macOS $(sw_vers -productVersion) ($ARCH)"

if [[ -d "$HOME/SimpleGlobal" ]]; then
    warn "~/SimpleGlobal already exists. This script is for fresh installs."
    read -p "  Continue anyway? (y/n): " CONTINUE < /dev/tty
    [[ "$CONTINUE" == "y" ]] || exit 0
fi

# ── Step 2: Collect email ──────────────────────────────────────────────────

echo ""
read -p "  SimpleGlobal email: " USER_EMAIL < /dev/tty

[[ "$USER_EMAIL" == *@simplemotion.global ]] || fail "Must be an @simplemotion.global address."

# Infer identity from email prefix
PREFIX="${USER_EMAIL%%@*}"

USER_NAME=$(echo "$PREFIX" | tr '.' '\n' \
    | awk '{print toupper(substr($0,1,1)) tolower(substr($0,2))}' \
    | paste -sd ' ')

GITHUB_USERNAME=$(echo "$PREFIX" | tr '.' '\n' \
    | awk '{print toupper(substr($0,1,1)) tolower(substr($0,2))}' \
    | paste -sd '-')
GITHUB_USERNAME="${GITHUB_USERNAME}-SG"

echo ""
echo "  Inferred identity:"
echo "    Name:     $USER_NAME"
echo "    GitHub:   $GITHUB_USERNAME"
echo "    Email:    $USER_EMAIL"
echo ""
read -p "  Correct? (y/n): " CONFIRM < /dev/tty
[[ "$CONFIRM" == "y" ]] || fail "Aborted. Re-run and enter the correct email."

# ── Step 3: Clone config repo ─────────────────────────────────────────────

info "Cloning config templates..."
rm -rf "$INIT_DIR"
git clone --quiet "$INIT_REPO" "$INIT_DIR"
ok "Config templates ready."

# ── Step 4: Install Claude Code ───────────────────────────────────────────

echo ""
if command -v claude >/dev/null 2>&1; then
    ok "Claude Code already installed: $(claude --version 2>/dev/null || echo 'unknown version')"
else
    info "Installing Claude Code..."
    curl -fsSL https://claude.ai/install.sh | sh
    ok "Claude Code installed."
fi

# ── Step 5: Install gh CLI ────────────────────────────────────────────────

mkdir -p "$HOME/.local/bin"
export PATH="$HOME/.local/bin:$PATH"

if command -v gh >/dev/null 2>&1; then
    ok "gh CLI already installed: $(gh --version 2>/dev/null | head -1)"
else
    info "Installing gh CLI..."

    GH_VERSION=$(curl -sL https://api.github.com/repos/cli/cli/releases/latest \
        | grep '"tag_name"' | head -1 | sed 's/.*"v\(.*\)".*/\1/')

    if [[ "$ARCH" == "arm64" ]]; then
        GH_ARCH="macOS_arm64"
    else
        GH_ARCH="macOS_amd64"
    fi

    curl -sL "https://github.com/cli/cli/releases/download/v${GH_VERSION}/gh_${GH_VERSION}_${GH_ARCH}.zip" \
        -o /tmp/gh.zip
    unzip -oq /tmp/gh.zip -d /tmp/gh_extract
    cp /tmp/gh_extract/*/bin/gh "$HOME/.local/bin/gh"
    chmod +x "$HOME/.local/bin/gh"
    rm -rf /tmp/gh.zip /tmp/gh_extract

    ok "gh CLI installed: $(gh --version 2>/dev/null | head -1)"
fi

# ── Step 6: GitHub authentication ─────────────────────────────────────────

echo ""
info "Authenticating with GitHub..."
info "A browser window will open. Sign in as: $GITHUB_USERNAME"
echo ""

gh auth login --hostname github.com --git-protocol https --web

ok "GitHub authenticated."

# ── Step 7: Clone employee repo (or mkdir fallback) ───────────────────────

echo ""
info "Looking for employee repo in $EMPLOYEES_ORG..."

SEARCH_NAME=$(echo "$USER_NAME" | tr ' ' '-')
EMPLOYEE_REPO=$(gh repo list "$EMPLOYEES_ORG" \
    --json name --jq ".[].name" 2>/dev/null \
    | grep -i "$SEARCH_NAME" | head -1 || true)

if [[ -n "$EMPLOYEE_REPO" ]]; then
    info "Found: $EMPLOYEE_REPO"
    git clone --recurse-submodules \
        "https://github.com/${EMPLOYEES_ORG}/${EMPLOYEE_REPO}.git" \
        "$HOME/SimpleGlobal"
    ok "Employee repo cloned to ~/SimpleGlobal"
else
    warn "No employee repo found matching '$SEARCH_NAME'."
    warn "Creating ~/SimpleGlobal manually. Ask your admin to create your employee repo."
    mkdir -p "$HOME/SimpleGlobal"
fi

# ── Step 8: Install Rust ──────────────────────────────────────────────────

echo ""
export CARGO_HOME="$HOME/SimpleGlobal/.cargo"
export RUSTUP_HOME="$HOME/SimpleGlobal/.rustup"

if [[ -f "$CARGO_HOME/bin/rustc" ]]; then
    ok "Rust already installed: $("$CARGO_HOME/bin/rustc" --version)"
else
    info "Installing Rust toolchain..."
    mkdir -p "$CARGO_HOME" "$RUSTUP_HOME"
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
        | sh -s -- -y --no-modify-path
    ok "Rust installed: $(source "$CARGO_HOME/env" && rustc --version)"
fi

# ── Step 9: Deploy config to .userconfig ──────────────────────────────────

echo ""
info "Deploying configuration..."

DEST="$HOME/SimpleGlobal/.userconfig"
mkdir -p "$DEST/.claude/plugins" "$DEST/.config/gh" "$DEST/.config/git" "$DEST/.m365"
touch "$DEST/.gitkeep" "$DEST/.m365/.gitkeep"

# Templatised files — replace placeholders
sed "s/{{USER_NAME}}/$USER_NAME/g; s/{{USER_EMAIL}}/$USER_EMAIL/g" \
    "$INIT_DIR/config/.gitconfig" > "$DEST/.gitconfig"

sed "s/{{GITHUB_USERNAME}}/$GITHUB_USERNAME/g" \
    "$INIT_DIR/config/gh/hosts.yml" > "$DEST/.config/gh/hosts.yml"

# Shared files — direct copy
cp "$INIT_DIR/config/.zshenv"                              "$DEST/.zshenv"
cp "$INIT_DIR/config/.zshrc"                               "$DEST/.zshrc"
cp "$INIT_DIR/config/claude/CLAUDE.md"                     "$DEST/.claude/CLAUDE.md"
cp "$INIT_DIR/config/claude/settings.json"                 "$DEST/.claude/settings.json"
cp "$INIT_DIR/config/claude/.mcp.json"                     "$DEST/.claude/.mcp.json"
cp "$INIT_DIR/config/claude/plugins/known_marketplaces.json" "$DEST/.claude/plugins/known_marketplaces.json"
cp "$INIT_DIR/config/claude/plugins/blocklist.json"        "$DEST/.claude/plugins/blocklist.json"
cp "$INIT_DIR/config/gh/config.yml"                        "$DEST/.config/gh/config.yml"
cp "$INIT_DIR/config/git/ignore"                           "$DEST/.config/git/ignore"

ok "Configuration deployed to ~/SimpleGlobal/.userconfig/"

# ── Step 10: Create symlinks ──────────────────────────────────────────────

info "Creating symlinks..."

# Home-level: ~/ → SimpleGlobal/.userconfig/
ln -sf SimpleGlobal/.userconfig/.gitconfig  "$HOME/.gitconfig"
ln -sf SimpleGlobal/.userconfig/.zshenv     "$HOME/.zshenv"
ln -sf SimpleGlobal/.userconfig/.zshrc      "$HOME/.zshrc"

# Claude-level: ~/.claude/ → ../SimpleGlobal/.userconfig/.claude/
mkdir -p "$HOME/.claude/plugins"
ln -sf ../SimpleGlobal/.userconfig/.claude/CLAUDE.md       "$HOME/.claude/CLAUDE.md"
ln -sf ../SimpleGlobal/.userconfig/.claude/settings.json   "$HOME/.claude/settings.json"
ln -sf ../SimpleGlobal/.userconfig/.claude/.mcp.json       "$HOME/.claude/.mcp.json"
ln -sf ../../SimpleGlobal/.userconfig/.claude/plugins/known_marketplaces.json \
       "$HOME/.claude/plugins/known_marketplaces.json"
ln -sf ../../SimpleGlobal/.userconfig/.claude/plugins/blocklist.json \
       "$HOME/.claude/plugins/blocklist.json"

# gh/git config: COPY (not symlink — gh auth login writes tokens here)
mkdir -p "$HOME/.config/gh" "$HOME/.config/git"
cp "$DEST/.config/gh/config.yml"  "$HOME/.config/gh/config.yml"
cp "$DEST/.config/gh/hosts.yml"   "$HOME/.config/gh/hosts.yml"
cp "$DEST/.config/git/ignore"     "$HOME/.config/git/ignore"

ok "Symlinks created."

# ── Step 11: Send welcome email ───────────────────────────────────────────

echo ""
info "Sending welcome confirmation email..."
gh workflow run welcome.yml \
    --repo simpleglobal/.sg-welcome \
    --field email="$USER_EMAIL" \
    --field name="$USER_NAME" 2>/dev/null \
    && ok "Welcome email triggered. Check your inbox." \
    || warn "Could not trigger welcome email. This is non-fatal."

# ── Step 12: Cleanup & summary ────────────────────────────────────────────

rm -rf "$INIT_DIR"

echo ""
echo "  ======================================"
echo "  Setup complete!"
echo "  ======================================"
echo ""
echo "  Name:        $USER_NAME"
echo "  Email:       $USER_EMAIL"
echo "  GitHub:      $GITHUB_USERNAME"
echo ""
echo "  Claude Code: $(command -v claude >/dev/null 2>&1 && claude --version 2>/dev/null || echo 'installed')"
echo "  gh CLI:      $(gh --version 2>/dev/null | head -1 || echo 'installed')"
echo "  Rust:        $(source "$CARGO_HOME/env" 2>/dev/null && rustc --version 2>/dev/null || echo 'installed')"
echo ""
echo "  Next steps:"
echo "    1. Open a new terminal (or run: source ~/.zshrc)"
echo "    2. Type 'sm' to launch Claude Code in ~/SimpleGlobal"
echo "    3. Run '/sg-orgs --sync-folders' to pull org structure"
echo "    4. Check your email for the welcome confirmation"
echo ""
