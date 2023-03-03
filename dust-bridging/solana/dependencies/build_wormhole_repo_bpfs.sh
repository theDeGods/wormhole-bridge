#!/bin/bash

### Are the wormhole programs already built? If so, bail out.
ls wormhole.so token_bridge.so > /dev/null 2>&1
if [ $? -eq 0 ]; then
  exit 0
fi

### Clone the repo
echo "fetching Solana programs from wormhole repo"
git clone \
  --depth 1 \
  --branch main \
  --filter=blob:none \
  --sparse \
  https://github.com/wormhole-foundation/wormhole \
  tmp-wormhole > /dev/null 2>&1
cd tmp-wormhole

### Checkout solana directory and move that to this program directory
git sparse-checkout set solana > /dev/null 2>&1

### Build program artifacts
echo "building"
cd solana
DOCKER_BUILDKIT=1 docker build \
  -f Dockerfile \
  --build-arg BRIDGE_ADDRESS=worm2ZoG2kUd4vFXhvjh93UUH596ayRfgQ2MgjNMTth \
  -o artifacts .

### Move wormhole artifact
cd ../..
mv tmp-wormhole/solana/artifacts/bridge.so wormhole.so
mv tmp-wormhole/solana/artifacts/token_bridge.so .
rm -rf tmp-wormhole

### Done
exit 0
