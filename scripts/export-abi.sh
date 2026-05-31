#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ABI_DIR="$ROOT/frontend/src/abi"
mkdir -p "$ABI_DIR"

cd "$ROOT"
forge build

copy_abi() {
  local contract=$1
  local outfile=$2
  jq '.abi' "out/${contract}.sol/${contract}.json" > "$ABI_DIR/${outfile}"
}

copy_abi "USDKEngine" "USDKEngine.json"
copy_abi "USDK" "USDK.json"
copy_abi "ERC20Mock" "ERC20Mock.json"
copy_abi "MockV3Aggregator" "MockV3Aggregator.json"

echo "ABIs exported to $ABI_DIR"
