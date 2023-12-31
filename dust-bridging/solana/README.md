# Purpose

This project implements the Solana program called DeBridge which initiates the bridging of DeLabs's DeGods and y00ts NFT collections as laid out in the root README. It also provides a TypeScript SDK to interact with the program on-chain.

# Design Summary

DeBridge is a program on the Solana blockchain written with the [Anchor framework](https://www.anchor-lang.com/).

## Burn and Send

Its most important instruction is called `burnAndSend` which burns a provided NFT and emits a Wormhole message, thus initiating the bridging process.

In more detail, when invoked, it will:
1. Ensure that all its prerequisites are fulfilled, namely that
  * the NFT belongs to the collection of the given instance of DeBridge
  * the instance isn't paused
  * the NFT is whitelisted (if whitelisting is enabled)
2. Additionally it relies on [Metaplex's new Burn instruction](https://github.com/metaplex-foundation/metaplex-program-library/blob/master/token-metadata/program/src/instruction/mod.rs#L504-L545) to ensure that:
  * the NFT is a [verified item of the collection](https://docs.metaplex.com/programs/token-metadata/instructions#verify-a-collection-item)
  * the transaction was signed by the owner of the NFT or an authorized delegate and is hence authorized to burn the NFT
  * the NFT is the [master edition](https://docs.metaplex.com/programs/token-metadata/accounts#master-edition) and [not some other edition](https://docs.metaplex.com/programs/token-metadata/accounts#edition)
  * that a coherent set of Metaplex accounts was provided
3. [Burn](https://github.com/metaplex-foundation/metaplex-program-library/blob/master/token-metadata/program/src/instruction/mod.rs#L504-L545) the NFT.
4. Emit a Wormhole message using the format described in the root README which serves as proof for the burning of the NFT and which can be submitted on the target EVM chain to mint its equivalent there.

### Wormhole Accounts

**Emitter**

DeBridge uses what is considered non-standard emitters by Wormhole because it uses the instance account (which has the seeds `["instance", collection_mint.key()]`) instead using a single, shared emitter account (with the default seed `["emitter"]`).

The advantage of this approach is that it
1. requires one fewer account to be passed in (the instance account is already part of the instruction)
2. allows easy filtering to only find VAAs that belong to one particular NFT collection

**Message**

The message account uses the seeds `["message", nft_mint.key()]`.

**Sequence**

The sequence account uses Wormhole's default derivation, i.e. the seed `["Sequence"]` (mind the unfortunate capitalization!) and is hence shared across all instances of DeBridge.

## Admin Instructions

The program can be instantiated multiple times but only once per [Collection NFT](https://docs.metaplex.com/programs/token-metadata/certified-collections#collection-nfts) and only by the [UpdateAuthority](https://docs.metaplex.com/programs/token-metadata/accounts#metadata) of that collection (who can then be thought of as the admin of that program instance) by using the `initialize` instruction, which creates the instance account using the seeds mentioned above.

DeBridge supports:
* an optional whitelist -- Passing a collection size argument of 0 to the `initialize` instruction disables the whitelist, otherwise it must be set to the size of the collection (there is no way to undo an initialization that used the wrong collection size argument!).
* whitelisting (`whitelist` and `whitelist_bulk`) -- `whitelist` sets the corresponding bit of an NFT with the given token id to true and is hence more natural, while `whitelist_bulk` allows writing directly to the underlying bit array for a more efficient approach (primarily inteded for setting up the initial state of the whitelist).
* delegating (`set_delegate`) -- Allows delegating admin functionality to a separate account (known as the delegate).
* pausing (`set_paused`) -- So `burnAndSend` instructions will fail even if all other prerequisites are met.

## SDK

The TypeScript SDK can be found in `./ts/de_bridge_sdk`. It includes (and thus depends on) the [IDL](https://www.anchor-lang.com/docs/cli) generated by Anchor.

## Deployment

Deploying will require changing the program id of `DeBridge` to a keypair under the deployer's control. Ensure to grep for the old program id and replace it everywhere (Anchor.toml, programs/de_bridge/src/lib.rs, and ts/de_bridge_sdk/index.ts).

## Remarks

* Both NFT collections currently use the current [Non-Fungible Standard](https://docs.metaplex.com/programs/token-metadata/token-standard#the-non-fungible-standard), however there is a new [Programmable Non-Fungible Standard](https://docs.metaplex.com/programs/token-metadata/token-standard#the-programmable-non-fungible-standard) in development, which has been introduced as a means to enforce payment of royalty fees to the NFT's creator upon NFT sales. Since DeLabs intends to convert both collections to the new pNFT standard within the given [upgrade window for existing assets](https://github.com/metaplex-foundation/mip/blob/main/mip-1.md#upgrade-window), DeBridge must use [the new, backwards compatible instructions of the Metaplex token metadata program](https://github.com/metaplex-foundation/metaplex-program-library/blob/ecb0dcd82274b8e70dacd171e1a553b6f6dab5c6/token-metadata/program/src/instruction/mod.rs#L502).
* Neither collection ought to have any print editions.

# Building

Install GNU make if you don't have it already and follow the [Anchor installation](https://www.anchor-lang.com/docs/installation) steps to set up the prereqs.

> **Warning**
> There are known issues when using Solana version 1.15 - please use Solana 1.14.14 instead.

Then build via:
```
make build
```

# Testing

You can run Rust's clippy for the DeBridge program (triggers additional compilation because it is built normally instead of via build-bpf) as well as the included TypeScript tests (found in `./ts/tests`) via
```
make test
```

The tests are a good reference for how to use the included SDK.

# Resources

## Anchor
* [Anchor framework](https://www.anchor-lang.com/docs/high-level-overview)

## Wormhole
* [general doc](https://book.wormhole.com/)
* [wormhole-scaffolding](https://github.com/wormhole-foundation/wormhole-scaffolding) - served as the jumping-off point for this repo

## Metaplex
* [general doc (not upated for pNFTs yet!)](https://docs.metaplex.com/)
* [pNFT standard MIP](https://github.com/metaplex-foundation/mip/blob/main/mip-1.md)
* [pNFT dev guide](https://github.com/metaplex-foundation/metaplex-program-library/blob/master/token-metadata/program/ProgrammableNFTGuide.md)
* [js npm package](https://www.npmjs.com/package/@metaplex-foundation/js)
* [mpl-token-metadata npm package](https://www.npmjs.com/package/@metaplex-foundation/mpl-token-metadata)
  * the new Verify instruction for pNFTs hadn't made it into the general js package yet at the time writing
