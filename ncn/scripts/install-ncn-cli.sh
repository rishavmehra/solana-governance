#!/bin/bash

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
NCN_DIR="$REPO_ROOT/ncn"
JITO_DIR="$REPO_ROOT/jito-tip-router"
JITO_BRANCH="gov-v1"

CLI_PKG="cli"
CLI_BIN_SRC="cli"
CLI_BIN_DEST="ncn-cli"

echo "Installing $CLI_BIN_DEST (global)..."

if ! command -v cargo >/dev/null 2>&1; then
  echo -e "${RED}Error: cargo is not installed.${NC}" >&2
  exit 1
fi

if ! command -v git >/dev/null 2>&1; then
  echo -e "${RED}Error: git is not installed.${NC}" >&2
  exit 1
fi

if [ ! -d "$NCN_DIR" ]; then
  echo -e "${RED}Error: cannot find ncn dir at: $NCN_DIR${NC}" >&2
  exit 1
fi

# Install dependency sources by cloning into the repo root (no submodules).
if [ -d "$JITO_DIR/.git" ]; then
  echo -e "${YELLOW}Updating existing jito-tip-router in $JITO_DIR (branch: $JITO_BRANCH)${NC}"
  cd "$JITO_DIR"
  git fetch --all
  git checkout "$JITO_BRANCH" || git checkout -b "$JITO_BRANCH" "origin/$JITO_BRANCH"
  git pull --ff-only origin "$JITO_BRANCH"
else
  echo -e "${YELLOW}Cloning jito-tip-router into repo root (branch: $JITO_BRANCH)${NC}"
  git clone --branch "$JITO_BRANCH" --single-branch https://github.com/exo-tech-xyz/jito-tip-router.git "$JITO_DIR"
fi

if [ ! -f "$JITO_DIR/meta_merkle_tree/Cargo.toml" ]; then
  echo -e "${RED}Error: expected $JITO_DIR/meta_merkle_tree/Cargo.toml not found.${NC}" >&2
  exit 1
fi

if [ ! -d "$JITO_DIR/tip-router-operator-cli" ]; then
  echo -e "${RED}Error: expected $JITO_DIR/tip-router-operator-cli missing.${NC}" >&2
  exit 1
fi

# Choose install location (similar behavior to svmgov install.sh).
if [ -f "/usr/local/bin/$CLI_BIN_DEST" ]; then
  INSTALL_DIR="/usr/local/bin"
elif [ -f "$HOME/.local/bin/$CLI_BIN_DEST" ]; then
  INSTALL_DIR="$HOME/.local/bin"
elif [ -w "/usr/local/bin" ]; then
  INSTALL_DIR="/usr/local/bin"
else
  INSTALL_DIR="$HOME/.local/bin"
fi

echo -e "${YELLOW}Build $CLI_PKG (release)${NC}"
cd "$NCN_DIR"

# Build only the requested package to keep it fast.
# Some dependencies require compile-time constants from env! macros.
# Provide defaults, but allow the user to override by exporting them beforehand.
export RESTAKING_PROGRAM_ID="${RESTAKING_PROGRAM_ID:-RestkWeAVL8fRGgzhfeoqFhsqKRchg6aa1XrcH96z4Q}"
export VAULT_PROGRAM_ID="${VAULT_PROGRAM_ID:-Vau1t6sLNxnzB7ZDsef8TLbPLfyZMYXH8WTNqUdm9g8}"
export TIP_ROUTER_PROGRAM_ID="${TIP_ROUTER_PROGRAM_ID:-11111111111111111111111111111111}"

cargo build --release -p "$CLI_PKG"

BINARY_PATH="$NCN_DIR/target/release/$CLI_BIN_SRC"
if [ ! -f "$BINARY_PATH" ]; then
  echo -e "${RED}Error: binary not found at: $BINARY_PATH${NC}" >&2
  exit 1
fi

if [ ! -d "$INSTALL_DIR" ]; then
  mkdir -p "$INSTALL_DIR"
fi

echo -e "${YELLOW}Installing to $INSTALL_DIR/$CLI_BIN_DEST${NC}"
if [ "$INSTALL_DIR" = "/usr/local/bin" ]; then
  sudo rm -f "/usr/local/bin/$CLI_BIN_DEST" 2>/dev/null || true
  sudo cp "$BINARY_PATH" "/usr/local/bin/$CLI_BIN_DEST"
  sudo chmod +x "/usr/local/bin/$CLI_BIN_DEST"
else
  rm -f "$HOME/.local/bin/$CLI_BIN_DEST" 2>/dev/null || true
  cp "$BINARY_PATH" "$INSTALL_DIR/$CLI_BIN_DEST"
  chmod +x "$INSTALL_DIR/$CLI_BIN_DEST"
fi

# Add PATH entry when needed (best-effort, like svmgov install.sh).
SHELL_NAME="$(basename "$SHELL" 2>/dev/null || echo "bash")"
CONFIG_FILE=""

case "$SHELL_NAME" in
  bash)
    if [ -f "$HOME/.bashrc" ]; then
      CONFIG_FILE="$HOME/.bashrc"
    elif [ -f "$HOME/.bash_profile" ]; then
      CONFIG_FILE="$HOME/.bash_profile"
    else
      CONFIG_FILE="$HOME/.bashrc"
    fi
    EXPORT_LINE="export PATH=\"$INSTALL_DIR:\$PATH\""
    ;;
  zsh)
    CONFIG_FILE="$HOME/.zshrc"
    EXPORT_LINE="export PATH=\"$INSTALL_DIR:\$PATH\""
    ;;
  fish)
    CONFIG_FILE="$HOME/.config/fish/config.fish"
    EXPORT_LINE="set -gx PATH \"$INSTALL_DIR\" \$PATH"
    ;;
  *)
    CONFIG_FILE=""
    ;;
esac

if [ -n "$CONFIG_FILE" ] && [ "$INSTALL_DIR" != "/usr/local/bin" ]; then
  mkdir -p "$(dirname "$CONFIG_FILE")" 2>/dev/null || true
  if ! grep -q "$INSTALL_DIR" "$CONFIG_FILE" 2>/dev/null; then
    echo "" >> "$CONFIG_FILE"
    echo "# $CLI_BIN_DEST CLI" >> "$CONFIG_FILE"
    echo "$EXPORT_LINE" >> "$CONFIG_FILE"
    echo -e "${GREEN}Added $INSTALL_DIR to PATH in $CONFIG_FILE${NC}"
  fi
fi

echo ""
echo -e "${GREEN}✓ Installation complete!${NC}"
echo ""
echo "Verify installation:"
echo "  $CLI_BIN_DEST --version"
echo ""

