# Purpose

This project implements the EVM NFT contract called `DeBridge` which completes the bridging of DeLabs's DeGods and y00ts NFT collections on their respective target chains as laid out in the root README. It also generates TypeChain TypeScript bindings for deployment and on-chain interaction.

# Design Summary

`DeBridge` implements the following standards/extensions:

- [ERC721 Non-Fungible Token Standard](https://eips.ethereum.org/EIPS/eip-721)
- [OpenZeppelin's ERC721 Enumerable Extension](https://docs.openzeppelin.com/contracts/4.x/api/token/erc721#IERC721Enumerable)
- [ERC2981 NFT Royalty Standard](https://eips.ethereum.org/EIPS/eip-2981)
- [OpenSea's Default Operator Filterer Standard](https://github.com/ProjectOpenSea/operator-filter-registry)
- [OpenZeppelin's Ownable Extension](https://docs.openzeppelin.com/contracts/4.x/api/access#Ownable)
- [OpenZeppelin's UUPSUpgradeable Extension](https://docs.openzeppelin.com/contracts/4.x/api/proxy#UUPSUpgradeable)
- [ERC165 Interface Detection Standard](https://eips.ethereum.org/EIPS/eip-165)

The project uses the [Foundry](https://book.getfoundry.sh/) toolchain.

## Deployment

The deployment process has two stages:

1. Deploy the logic contract via `DeBridge`'s constructor which nails down the immutable datamembers.
2. Deploy the proxy contract (OpenZeppelin's `ERC1967Proxy`) and call `DeBridge`'s `initialize` function which plays the role of the constructor of the proxy.

Immutable datamembers baked into the logic contract via `DeBridge`'s constructor are:

- [address of the Wormhole core contract on this EVM chain](https://book.wormhole.com/reference/contracts.html)
- address of the Dust ERC20 token contract on this EVM chain (can be [queried from the Wormhole token bridge](https://github.com/wormhole-foundation/wormhole/blob/24f3893b492c0de859ab82cc91b294450efdbac1/ethereum/contracts/bridge/BridgeGetters.sol#L50) on this EVM chain using the `chainId` and `tokenAddress` of the original Dust token contract)
- the emitter (=address of the instance account) of the associated `DeBridge` program's instance on Solana for the given NFT collection (see README in solana directory for details)
- the ERC721 base URI of the NFT collection (`"https://metadata.degods.com/g/"` for DeGods, `"https://metadata.y00ts.com/y/"` for y00ts)

The `initialize` call for the proxy contract takes the following arguments:

- the name and symbol of the NFT collection
- the amounts of gas tokens and DUST transferred upon minting (both in wei)
- the basis points and recipient of NFT sales royalties (see [ERC2981 NFT Royalty Standard](https://eips.ethereum.org/EIPS/eip-2981))

The name and symbol can't be changed after deployment but the remaining parameters have set/update methods.

While logic contract can be deployed by anyone (it has no concept of ownership), the deployer of the proxy contract automatically becomes its owner.

# Building

Install GNU make if you don't have it already and then build via:

```
make build
```

This will compile the contract and then generate the TypeChain bindings in the ts-types directory.

# Testing

First, set the `ETH_FORK_RPC` and `POLYGON_FORK_RPC` variables in `env/testing.env`. The integration tests fork mainnet, so be sure to use the mainnet URL. Then run the tests with the following commands:

```
# solidity-based unit tests
make unit-test

# local-validator integration tests written in typescript
make integration-test

# unit tests and local-validator integration tests
make test
```

# Storage Layout Verification

The following script compares the storage layout of any verified `DeBridge` contract (`verified` on `etherscan` or `polygonscan`) with the local implementation. Before running the script, you will need to install the `ethereum-sources-downloader`. Also, make sure to have a working python environment with the following installed dependencies:

- pandas
- argparse

Next, open the `verify_storage_layout.sh` file and configure the following arguments depending on the target smart contract and network you wish to verify:

```
# 20-byte hex encoded address
CONTRACT_ADDRESS=

# polygonscan or etherscan
API=

# contract name (e.g. y00tsV2)
CONTRACT=
```

Finally, run the verification script:

```
bash shell-scripts/verify_storage_layout.sh
```
