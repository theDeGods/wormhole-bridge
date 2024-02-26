import { expect } from "chai";
import { ethers } from "ethers";
import { Y00tsV2__factory } from "../../ts-types/factories/Y00tsV2__factory";
import {
  POLYGON_LOCALHOST,
  POLYGON_YOOTS,
  WALLET_PRIVATE_KEY,
  POLYGON_WORMHOLE_ADDRESS,
  POLYGON_DUST,
  POLYGON_MINTER,
  Y00TS_URI,
  POLYGON_YOOTS_OWNER,
} from "./helpers/const";
import * as fs from "fs";

describe("Polygon y00tsV2 Upgrade", () => {
  const polyProvider = new ethers.providers.StaticJsonRpcProvider(
    POLYGON_LOCALHOST
  );
  const polyWallet = new ethers.Wallet(WALLET_PRIVATE_KEY, polyProvider);

  // Read in forge output file.
  const abiFile = JSON.parse(
    fs.readFileSync(`${__dirname}/../../out/y00tsV2.sol/y00tsV2.json`, "utf8")
  );
  expect(abiFile).is.not.null;

  let localVars: any = {};

  it("Deploy Implementation", async () => {
    const factory = new ethers.ContractFactory(
      abiFile.abi,
      abiFile.bytecode.object,
      polyWallet
    );

    const deployTx = await factory.deploy(
      POLYGON_WORMHOLE_ADDRESS,
      POLYGON_DUST,
      POLYGON_MINTER,
      ethers.utils.hexlify(ethers.utils.toUtf8Bytes(Y00TS_URI))
    );
    expect(deployTx).is.not.null;

    // Save deployed address.
    localVars.implementation = deployTx.address;
  });

  it("Upgrade", async () => {
    // Start prank (impersonate the owner).
    await polyProvider.send("anvil_impersonateAccount", [POLYGON_YOOTS_OWNER]);

    // Connect to the contract using the impersonated account.
    // @ts-ignore
    const polyY00tsV2 = Y00tsV2__factory.connect(
      POLYGON_YOOTS,
      polyProvider.getSigner(POLYGON_YOOTS_OWNER)
    );

    // Uprade the contract to the new implementation.
    const upgradeTx = await polyY00tsV2.upgradeTo(localVars.implementation);
    expect(upgradeTx).is.not.null;

    // End prank.
    await polyProvider.send("anvil_stopImpersonatingAccount", [
      POLYGON_YOOTS_OWNER,
    ]);
  });
});
