import { expect } from "chai";
import { ethers } from "ethers";
import { IWormhole__factory } from "@certusone/wormhole-sdk/lib/cjs/ethers-contracts";
import { CHAIN_ID_POLYGON, CHAIN_ID_ETH } from "@certusone/wormhole-sdk";
import {
  WORMHOLE_MESSAGE_FEE,
  WORMHOLE_GUARDIAN_SET_INDEX,
  GUARDIAN_PRIVATE_KEY,
  WALLET_PRIVATE_KEY,
  ETH_LOCALHOST,
  ETH_WORMHOLE_ADDRESS,
  POLYGON_LOCALHOST,
  POLYGON_WORMHOLE_ADDRESS,
} from "./helpers/const";

describe("Environment Test", () => {
  describe("Global", () => {
    it("Environment Variables", () => {
      expect(WORMHOLE_MESSAGE_FEE).is.not.undefined;
      expect(WORMHOLE_GUARDIAN_SET_INDEX).is.not.undefined;
      expect(GUARDIAN_PRIVATE_KEY).is.not.undefined;
      expect(WALLET_PRIVATE_KEY).is.not.undefined;
    });
  });

  describe("Ethereum Goerli Testnet Fork", () => {
    describe("Environment", () => {
      it("Variables", () => {
        expect(ETH_LOCALHOST).is.not.undefined;
        expect(ETH_WORMHOLE_ADDRESS).is.not.undefined;
      });
    });

    describe("RPC", () => {
      const provider = new ethers.providers.StaticJsonRpcProvider(
        ETH_LOCALHOST
      );
      const wormhole = IWormhole__factory.connect(
        ETH_WORMHOLE_ADDRESS,
        provider
      );
      expect(wormhole.address).to.equal(ETH_WORMHOLE_ADDRESS);

      it("Wormhole", async () => {
        const chainId = await wormhole.chainId();
        expect(chainId).to.equal(CHAIN_ID_ETH as number);

        // fetch current wormhole protocol fee
        const messageFee: ethers.BigNumber = await wormhole.messageFee();
        expect(messageFee.eq(WORMHOLE_MESSAGE_FEE)).to.be.true;

        // Override guardian set
        {
          // check guardian set index
          const guardianSetIndex = await wormhole.getCurrentGuardianSetIndex();
          expect(guardianSetIndex).to.equal(WORMHOLE_GUARDIAN_SET_INDEX);

          // override guardian set
          const abiCoder = ethers.utils.defaultAbiCoder;

          // get slot for Guardian Set at the current index
          const guardianSetSlot = ethers.utils.keccak256(
            abiCoder.encode(["uint32", "uint256"], [guardianSetIndex, 2])
          );

          // Overwrite all but first guardian set to zero address. This isn't
          // necessary, but just in case we inadvertently access these slots
          // for any reason.
          const numGuardians = await provider
            .getStorageAt(wormhole.address, guardianSetSlot)
            .then((value) => ethers.BigNumber.from(value).toBigInt());
          for (let i = 1; i < numGuardians; ++i) {
            await provider.send("anvil_setStorageAt", [
              wormhole.address,
              abiCoder.encode(
                ["uint256"],
                [
                  ethers.BigNumber.from(
                    ethers.utils.keccak256(guardianSetSlot)
                  ).add(i),
                ]
              ),
              ethers.utils.hexZeroPad("0x0", 32),
            ]);
          }

          // Now overwrite the first guardian key with the devnet key specified
          // in the function argument.
          const devnetGuardian = new ethers.Wallet(GUARDIAN_PRIVATE_KEY)
            .address;
          await provider.send("anvil_setStorageAt", [
            wormhole.address,
            abiCoder.encode(
              ["uint256"],
              [
                ethers.BigNumber.from(
                  ethers.utils.keccak256(guardianSetSlot)
                ).add(
                  0 // just explicit w/ index 0
                ),
              ]
            ),
            ethers.utils.hexZeroPad(devnetGuardian, 32),
          ]);

          // change the length to 1 guardian
          await provider.send("anvil_setStorageAt", [
            wormhole.address,
            guardianSetSlot,
            ethers.utils.hexZeroPad("0x1", 32),
          ]);

          // confirm guardian set override
          const guardians = await wormhole
            .getGuardianSet(guardianSetIndex)
            .then(
              (guardianSet: any) => guardianSet[0] // first element is array of keys
            );
          expect(guardians.length).to.equal(1);
          expect(guardians[0]).to.equal(devnetGuardian);
        }
      });
    });
  });

  describe("Avalanche Fuji Testnet Fork", () => {
    describe("Environment", () => {
      it("Variables", () => {
        expect(POLYGON_LOCALHOST).is.not.undefined;
        expect(POLYGON_WORMHOLE_ADDRESS).is.not.undefined;
      });
    });

    describe("RPC", () => {
      const provider = new ethers.providers.StaticJsonRpcProvider(
        POLYGON_LOCALHOST
      );
      const wormhole = IWormhole__factory.connect(
        POLYGON_WORMHOLE_ADDRESS,
        provider
      );
      expect(wormhole.address).to.equal(POLYGON_WORMHOLE_ADDRESS);

      it("Wormhole", async () => {
        const chainId = await wormhole.chainId();
        expect(chainId).to.equal(CHAIN_ID_POLYGON as number);

        // fetch current wormhole protocol fee
        const messageFee = await wormhole.messageFee();
        expect(messageFee.eq(WORMHOLE_MESSAGE_FEE)).to.be.true;

        // override guardian set
        {
          // check guardian set index
          const guardianSetIndex = await wormhole.getCurrentGuardianSetIndex();
          expect(guardianSetIndex).to.equal(WORMHOLE_GUARDIAN_SET_INDEX);

          // override guardian set
          const abiCoder = ethers.utils.defaultAbiCoder;

          // get slot for Guardian Set at the current index
          const guardianSetSlot = ethers.utils.keccak256(
            abiCoder.encode(["uint32", "uint256"], [guardianSetIndex, 2])
          );

          // Overwrite all but first guardian set to zero address. This isn't
          // necessary, but just in case we inadvertently access these slots
          // for any reason.
          const numGuardians = await provider
            .getStorageAt(wormhole.address, guardianSetSlot)
            .then((value) => ethers.BigNumber.from(value).toBigInt());
          for (let i = 1; i < numGuardians; ++i) {
            await provider.send("anvil_setStorageAt", [
              wormhole.address,
              abiCoder.encode(
                ["uint256"],
                [
                  ethers.BigNumber.from(
                    ethers.utils.keccak256(guardianSetSlot)
                  ).add(i),
                ]
              ),
              ethers.utils.hexZeroPad("0x0", 32),
            ]);
          }

          // Now overwrite the first guardian key with the devnet key specified
          // in the function argument.
          const devnetGuardian = new ethers.Wallet(GUARDIAN_PRIVATE_KEY)
            .address;
          await provider.send("anvil_setStorageAt", [
            wormhole.address,
            abiCoder.encode(
              ["uint256"],
              [
                ethers.BigNumber.from(
                  ethers.utils.keccak256(guardianSetSlot)
                ).add(
                  0 // just explicit w/ index 0
                ),
              ]
            ),
            ethers.utils.hexZeroPad(devnetGuardian, 32),
          ]);

          // change the length to 1 guardian
          await provider.send("anvil_setStorageAt", [
            wormhole.address,
            guardianSetSlot,
            ethers.utils.hexZeroPad("0x1", 32),
          ]);

          // Confirm guardian set override
          const guardians = await wormhole
            .getGuardianSet(guardianSetIndex)
            .then(
              (guardianSet: any) => guardianSet[0] // first element is array of keys
            );
          expect(guardians.length).to.equal(1);
          expect(guardians[0]).to.equal(devnetGuardian);
        }
      });
    });
  });
});
