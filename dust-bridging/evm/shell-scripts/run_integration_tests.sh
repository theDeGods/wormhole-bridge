#/bin/bash

pgrep anvil > /dev/null
if [ $? -eq 0 ]; then
    echo "anvil already running"
    exit 1;
fi

# ethereum goerli testnet
anvil \
    -m "myth like bonus scare over problem client lizard pioneer submit female collect" \
    --port 8546 \
    --fork-block-number $ETH_FORK_BLOCK \
    --fork-url $ETH_FORK_RPC > anvil_eth.log &

# polygon fuji testnet
anvil \
    -m "myth like bonus scare over problem client lizard pioneer submit female collect" \
    --port 8547 \
    --fork-block-number $POLYGON_FORK_BLOCK \
    --fork-url $POLYGON_FORK_RPC > anvil_polygon.log &

sleep 2

## first key from mnemonic above
export PRIVATE_KEY=$WALLET_PRIVATE_KEY

mkdir -p cache
cp -v foundry.toml cache/foundry.toml
cp -v foundry-test.toml foundry.toml

EVM_ROOT=$(dirname $0)/..

echo "deploying y00tsV3"
forge script $EVM_ROOT/script/deploy_y00tsV3.sol \
    --rpc-url http://localhost:8546 \
    --private-key $PRIVATE_KEY \
    --broadcast --slow >> deploy.out 2>&1

echo "overriding foundry.toml"
mv -v cache/foundry.toml foundry.toml

## run tests here
npx ts-mocha -t 1000000 ts/test/*.ts

# nuke
pkill anvil