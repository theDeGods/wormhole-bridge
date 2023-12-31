import {expect, use as chaiUse} from "chai";
import chaiAsPromised from 'chai-as-promised';
chaiUse(chaiAsPromised);
import {
  Connection,
  PublicKey,
  Keypair,
  Transaction,
  sendAndConfirmTransaction,
  TransactionInstruction,
  LAMPORTS_PER_SOL,
  SYSVAR_INSTRUCTIONS_PUBKEY,
} from "@solana/web3.js";
import {CONTRACTS} from "@certusone/wormhole-sdk";
import * as wormhole from "@certusone/wormhole-sdk/lib/cjs/solana/wormhole";
import {Metaplex, keypairIdentity, CreateNftOutput} from "@metaplex-foundation/js";
import {
  TokenStandard,
  createVerifyInstruction,
  VerificationArgs
} from '@metaplex-foundation/mpl-token-metadata';
import {DeBridge} from "../de_bridge_sdk";

const LOCALHOST = "http://localhost:8899";
const GUARDIAN_ADDRESS = "0xbefa429d57cd18b7f8a4d91a2da9ab4af05d0fbe";
//we use mainnet despite testing on localnet because the wormhole module is compiled for mainnet
const WORMHOLE_ID = new PublicKey(CONTRACTS.MAINNET.solana.core);

const range = (size: number) => [...Array(size).keys()];

describe("DeLabs NFT bridging", function() {
  const admin = Keypair.generate();
  const connection = new Connection(LOCALHOST, "processed");
  const metaplex = Metaplex.make(connection).use(keypairIdentity(admin));

  const nftCount = (owner: Keypair) =>
    metaplex.nfts().findAllByOwner({owner: owner.publicKey}).then(arr => arr.length);
  // const getCollectionNft = () =>
  //   metaplex.nfts().findByMint({mintAddress: collectionMint}) as Promise<Nft>;

  const airdropSol = async (keypair: Keypair) => {
    return connection.confirmTransaction(
      await connection.requestAirdrop(keypair.publicKey, 1000 * LAMPORTS_PER_SOL)
    );
  };

  async function instantiate(tokenStandard: TokenStandard = TokenStandard.NonFungible) {
    const collectionNft = await metaplex.nfts().create({
      name: "DeGods",
      symbol: "DGOD",
      uri: "https://arweave.net/k8ZelfKwFjZcxNMyfhnXAaPfZPp5YISLZmvBha6gz48",
      sellerFeeBasisPoints: 333,
      tokenStandard,
      //for NFTs with the "old", non-programmable standard, we also don't set isCollection
      isCollection: false,
    });

    const deBridge = new DeBridge(
      connection,
      collectionNft.mintAddress,
       //force use of mainnet address despite testing on local cluster because module is configured
       // with mainnet address regardless and hence deployed to that address by Anchor
      {wormholeId: WORMHOLE_ID},
    );
    return {collectionNft, deBridge};
  }

  const sendAndConfirmIx = (ix: TransactionInstruction, signers: Keypair[]) =>
    sendAndConfirmTransaction(connection, new Transaction().add(ix), signers);

  const initialize = async (
    deBridge: DeBridge,
    deployer: Keypair,
    whitelistSize: number,
  ) => sendAndConfirmIx(
    await deBridge.createInitializeInstruction(deployer.publicKey, whitelistSize), [deployer]
  );

  const setPause = async (
    deBridge: DeBridge,
    sender: Keypair,
    paused: boolean
  ) => sendAndConfirmIx(
    await deBridge.createSetPausedInstruction(sender.publicKey, paused), [sender]
  );

  before("Fund Admin and Initialize Wormhole", async function() {
    await airdropSol(admin);
    
    const guardianSetExpirationTime = 86400;
    const fee = 100n;
    const devnetGuardian = Buffer.from(GUARDIAN_ADDRESS.substring(2), "hex");
    await sendAndConfirmIx(
      wormhole.createInitializeInstruction(
        WORMHOLE_ID,
        admin.publicKey,
        guardianSetExpirationTime,
        fee,
        [devnetGuardian]
      ),
      [admin]
    );
  });

  describe("Admin/Delegate Operations", function() {
    let deBridge: DeBridge;
    const delegate = Keypair.generate();
    const whitelistSize = 10000;

    before("Create a collection NFT and instantiate DeBridge", async function() {
      await airdropSol(delegate);
      deBridge = (await instantiate()).deBridge;
    });

    describe("Initialize Ix", function() {
      const initializeTest = (deployer: Keypair) => async function() {
        expect(await deBridge.isInitialized()).equals(false);
        const expectedOutcome = (deployer === admin) ? "fulfilled" : "rejected";
        await expect(initialize(deBridge, deployer, whitelistSize)).to.be[expectedOutcome];
        expect(await deBridge.isInitialized()).equals(deployer === admin);
      };

      it("as a rando", initializeTest(delegate));
      it("as the admin (i.e. the update authority of the collection)", initializeTest(admin));
    });

    const tokenIdsToWhitelist = [0, 1, 8, whitelistSize-9, whitelistSize-2, whitelistSize-1];
    const notWhitelisted = [2, 7, 9, whitelistSize-10, whitelistSize-8, whitelistSize-3];

    describe("whitelistBulk Ix", function() {
      it("test", async function() {
        for (const tokenId of tokenIdsToWhitelist.concat(notWhitelisted))
          expect(await deBridge.isNftWhitelisted(tokenId)).to.equal(false);

        const bulkWhitelistIxs = await deBridge.createWhitelistBulkInstructions(
          admin.publicKey,
          range(whitelistSize).map(index => tokenIdsToWhitelist.includes(index))
        );

        for (const ix of bulkWhitelistIxs)
          await expect(sendAndConfirmIx(ix, [admin])).to.be.fulfilled;
        
        for (const tokenId of tokenIdsToWhitelist)
          expect(await deBridge.isNftWhitelisted(tokenId)).to.equal(true);
        
        for (const tokenId of notWhitelisted)
          expect(await deBridge.isNftWhitelisted(tokenId)).to.equal(false);
      })
    });

    describe("delegation", function() {
      const setDelegate = async (newDelegate: PublicKey | null) => sendAndConfirmTransaction(
        connection,
        new Transaction().add(await deBridge.createSetDelegateInstruction(newDelegate)),
        [admin]
      );

      const delegateWhitelist = async (tokenId: number) => sendAndConfirmTransaction(
        connection,
        new Transaction().add(await deBridge.createWhitelistInstruction(
          delegate.publicKey,
          tokenId,
        )),
        [delegate]
      );

      it("unauthorized delegate can't whitelist", async function() {
        await expect(delegateWhitelist(0)).to.be.rejected;
      });

      it("unauthorized delegate can't pause", async function() {
        await expect(setPause(deBridge, delegate, true)).to.be.rejected;
      });

      it("admin authorizes delegate", async function() {
        await expect(setDelegate(delegate.publicKey)).to.be.fulfilled;
      });

      it("authorized delegate pauses", async function() {
        await expect(setPause(deBridge, delegate, true)).to.be.fulfilled;
      });

      it("admin unpauses", async function() {
        await expect(setPause(deBridge, admin, false)).to.be.fulfilled;
      });

      it("delegate whitelists", async function() {
        const tokenId = notWhitelisted[0];
        expect(await deBridge.isNftWhitelisted(tokenId)).to.equal(false);
        await expect(delegateWhitelist(tokenId)).to.be.fulfilled;
        expect(await deBridge.isNftWhitelisted(tokenId)).to.equal(true);
      });

      it("delegate whitelists out of bounds", async function() {
        await expect(delegateWhitelist(whitelistSize)).to.be.rejected;
      });

      it("admin revokes authorization", async function() {
        await expect(setDelegate(null)).to.be.fulfilled;
      });

      it("delegate can't pause anymore", async function() {
        await expect(setPause(deBridge, delegate, true)).to.be.rejected;
      });

      it("delegate can't whitelist anymore", async function() {
        await expect(delegateWhitelist(0)).to.be.rejected;
      });
    });
  });

  const tokenStandardTestCases =
    ["NonFungible", "ProgrammableNonFungible"] as (keyof typeof TokenStandard)[];
  const truthValues = [true, false];
  const BurnIxTestCombinations = tokenStandardTestCases.flatMap(
    tokenStandardName => truthValues.flatMap(useWhitelist => {
      return {
        tokenStandardName,
        useWhitelist,
      };
    })
  );
  BurnIxTestCombinations.forEach(({tokenStandardName, useWhitelist}) =>
  describe("BurnAndSend Ix for NFT with token standard " + tokenStandardName +
    " with" + (useWhitelist ? "" : "out") + " using a whitelist", function() {
    const user = Keypair.generate();
    let collectionNft: CreateNftOutput;
    let deBridge: DeBridge;
    let userNft: CreateNftOutput;
    const tokenId = 3250;
    const whitelistSize = useWhitelist ? 10000 : 0;
    const tokenStandard = TokenStandard[tokenStandardName];
    //const isSizedCollection = tokenStandard === TokenStandard.ProgrammableNonFungible;

    const evmRecipient = "0x" + "00123456".repeat(5);
    const burnAndSend = async (sender: Keypair) => sendAndConfirmIx(
      await deBridge.createSendAndBurnInstruction(
        sender.publicKey,
        userNft.tokenAddress,
        evmRecipient,
      ),
      [sender]
    );

    before("Mint NFTs, instantiate and initialize DeBridge, fund the user", async function() {
      await airdropSol(user);
      const res = await instantiate(tokenStandard);
      collectionNft = res.collectionNft;
      deBridge = res.deBridge;
      await initialize(deBridge, admin, whitelistSize);

      expect(await nftCount(user)).equals(0);

      //does not verify that the NFT belongs to the collection
      userNft = await metaplex.nfts().create({
        name: "DeGod #" + (tokenId+1),
        symbol: "DGOD",
        uri: "https://metadata.degods.com/g/" + tokenId + ".json",
        sellerFeeBasisPoints: 333,
        collection: collectionNft.mintAddress,
        tokenOwner: user.publicKey,
        tokenStandard,
      });

      expect(await nftCount(user)).equals(1);
    });

    describe("without verifying that the NFT belongs to the collection", function() {
      it("when not the owner of the NFT", async function() {
        await expect(burnAndSend(admin)).to.be.rejected;
      });

      it("as the owner of the NFT", async function() {
        await expect(burnAndSend(user)).to.be.rejected;
      });
    });

    describe("after verifying the NFT", function() {
      before("verify the NFT as part of the collection", async function() {
        await sendAndConfirmIx(
          createVerifyInstruction({
              authority: admin.publicKey,
              metadata: userNft.metadataAddress,
              collectionMint: collectionNft.mintAddress,
              collectionMetadata: collectionNft.metadataAddress,
              collectionMasterEdition: collectionNft.masterEditionAddress,
              sysvarInstructions: SYSVAR_INSTRUCTIONS_PUBKEY,
            },
            {verificationArgs: VerificationArgs.CollectionV1},
          ),
          [admin]
        );
      });

      it("when not the owner of the NFT", async function() {
        await expect(burnAndSend(admin)).to.be.rejected;
      });
    });
    
    if (useWhitelist) {
      describe("without whitelisting the NFT", function() {
        it("as the owner of the NFT ", async function() {
          expect (await deBridge.isNftWhitelisted(tokenId)).to.equal(false);
          await expect(burnAndSend(user)).to.be.rejected;
        });
      });

      describe("after whitelisting the NFT", function() {
        before("whitelist the NFT via whitelist instruction", async function() {
          expect (await deBridge.isNftWhitelisted(tokenId)).to.equal(false);
          await expect(sendAndConfirmIx(
            await deBridge.createWhitelistInstruction(admin.publicKey, tokenId), [admin]
          )).to.be.fulfilled;
          expect (await deBridge.isNftWhitelisted(tokenId)).to.equal(true);
        });

        it("when not the owner of the NFT", async function() {
          await expect(burnAndSend(admin)).to.be.rejected;
        });
      });
    }

    describe("not while paused", function() {
      before("pause", async function() {
        await expect(setPause(deBridge, admin, true)).to.be.fulfilled;
      });

      it("as the owner of the NFT", async function() {
        await expect(burnAndSend(user)).to.be.rejected;
      });

      after("unpause", async function() {
        await expect(setPause(deBridge, admin, false)).to.be.fulfilled;
      });
    });

    describe("and finally successfully", function() {
      it("as the owner of the NFT", async function() {
        await expect(burnAndSend(user)).to.be.fulfilled;
      });

      it("... and verify that the NFT was burned", async function() {
        expect(await nftCount(user)).equals(0);
      });

      it("... and that the correct Wormhole message was emitted", async function() {
        const {payload} = (await wormhole.getPostedMessage(
          connection, DeBridge.messageAccountAddress(userNft.mintAddress)
        )).message;

        expect(payload.readUint16BE(0)).to.equal(tokenId);
        expect(Buffer.compare(
          payload.subarray(2),
          Buffer.from(evmRecipient.substring(2), "hex")
        )).to.equal(0);
      });
    });
  }));
});
