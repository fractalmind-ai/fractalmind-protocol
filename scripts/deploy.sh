#!/usr/bin/env bash
set -euo pipefail

NETWORK="${1:-testnet}"

echo "Building contracts..."
cd contracts/protocol
sui move build --silence-warnings

echo "Publishing to ${NETWORK}..."
sui client publish --gas-budget 200000000
