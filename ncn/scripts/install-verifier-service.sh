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

echo "Select network:"
echo "1) mainnet"
echo "2) testnet"

NETWORK=""
while true; do
  read -r -p "> " choice
  if [ "$choice" = "1" ]; then
    NETWORK="mainnet"
    break
  elif [ "$choice" = "2" ]; then
    NETWORK="testnet"
    break
  else
    echo "Please enter 1 or 2."
  fi
done

if [ "$NETWORK" = "testnet" ]; then
  IMAGE_TAG="verifier-service:latest-testnet"
else
  IMAGE_TAG="verifier-service:latest-mainnet"
fi

echo -e "${YELLOW}Preparing jito-tip-router dependency (branch: ${JITO_BRANCH})...${NC}"
if [ -d "$JITO_DIR/.git" ]; then
  cd "$JITO_DIR"
  git fetch --all
  git checkout "$JITO_BRANCH" || git checkout -b "$JITO_BRANCH" "origin/$JITO_BRANCH"
  git pull --ff-only origin "$JITO_BRANCH"
else
  git clone --branch "$JITO_BRANCH" --single-branch https://github.com/exo-tech-xyz/jito-tip-router.git "$JITO_DIR"
fi

if [ ! -f "$JITO_DIR/meta_merkle_tree/Cargo.toml" ]; then
  echo -e "${RED}Error: expected $JITO_DIR/meta_merkle_tree/Cargo.toml not found.${NC}" >&2
  exit 1
fi

echo -e "${YELLOW}Building verifier-service binary...${NC}"
export RESTAKING_PROGRAM_ID="${RESTAKING_PROGRAM_ID:-RestkWeAVL8fRGgzhfeoqFhsqKRchg6aa1XrcH96z4Q}"
export VAULT_PROGRAM_ID="${VAULT_PROGRAM_ID:-Vau1t6sLNxnzB7ZDsef8TLbPLfyZMYXH8WTNqUdm9g8}"
export TIP_ROUTER_PROGRAM_ID="${TIP_ROUTER_PROGRAM_ID:-11111111111111111111111111111111}"

cd "$NCN_DIR"
cargo build --release --bin verifier-service

echo -e "${YELLOW}Building Docker image: ${IMAGE_TAG}${NC}"
sudo docker build -f verifier-service/Dockerfile -t "${IMAGE_TAG}" .

echo -e "${YELLOW}Starting verifier-service container via setup.sh...${NC}"
cd "$NCN_DIR/verifier-service/src/scripts"

# setup.sh asks for OPERATOR_PUBKEY, METRICS_AUTH_TOKEN, and PORT_HOST
export VERIFIER_NETWORK="$NETWORK"
sudo bash setup.sh

echo -e "${GREEN}Done.${NC}"

