#!/usr/bin/env bash

# starts two blockchains, deploys the onlyswaps contracts to them, prepares them for transfers,
# then stores the state to a file to hydrate another anvil instance


# first configure a bit of process management
set -euo pipefail

pids=()
cleanup() {
  code=$?
  if ((${#pids[@]})); then
    # ask children to stop, then wait
    kill -TERM "${pids[@]}" >/dev/null 2>&1 || true
    wait "${pids[@]}" >/dev/null  2>&1|| true
  fi
}

on_signal() {
  echo "caught INT/TERM, shutting down..."
  exit 0     # triggers the EXIT trap -> cleanup
}

trap on_signal INT TERM HUP
trap cleanup EXIT

# clear old runs but make sure we have all the right bits
mkdir -p ./build
rm -rf ./build/*

pushd onlyswaps-solidity
npm install && npm run build
popd

## THE REAL FUN STARTS HERE ##

echo "[+] starting blockchains"
anvil --port 31337 --chain-id 31337 --block-time 3 --dump-state build/31337.json > /dev/null & pids+=($!)

anvil --port 31338 --chain-id 31338 --block-time 3 --dump-state build/31338.json > /dev/null & pids+=($!)

echo "[+] deploying contracts to 31337"
./deploy-anvil.sh 31337 
echo "[+] enabling transfers on 31337"
./enable-transfers.sh 31337 31338

echo "[+] deploying contracts to 31338"
./deploy-anvil.sh 31338
echo "[+] enabling transfers on 31338"
./enable-transfers.sh 31338 31337

./configure-solver.sh

echo "[+] completed successfully"

