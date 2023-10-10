import { ethers } from "ethers";
import { ChainId, tryNativeToHexString } from "@certusone/wormhole-sdk";
import { WORMHOLE_MESSAGE_EVENT_ABI, WORMHOLE_TOPIC } from "./const";
import * as fs from "fs";

export function readY00tsV3Proxy(): string {
  return JSON.parse(
    fs.readFileSync(
      `${__dirname}/../../../broadcast-test/deploy_y00tsV3.sol/1/run-latest.json`,
      "utf-8"
    )
  ).transactions[1].contractAddress;
}

export async function parseWormholeEventsFromReceipt(
  receipt: ethers.ContractReceipt
): Promise<ethers.utils.LogDescription[]> {
  // create the wormhole message interface
  const wormholeMessageInterface = new ethers.utils.Interface(
    WORMHOLE_MESSAGE_EVENT_ABI
  );

  // loop through the logs and parse the events that were emitted
  let logDescriptions: ethers.utils.LogDescription[] = [];
  for (const log of receipt.logs) {
    if (log.topics.includes(WORMHOLE_TOPIC)) {
      logDescriptions.push(wormholeMessageInterface.parseLog(log));
    }
  }
  return logDescriptions;
}

export async function formatWormholeMessageFromReceipt(
  receipt: ethers.ContractReceipt,
  emitterChainId: ChainId
): Promise<Buffer[]> {
  // parse the wormhole message logs
  const messageEvents = await parseWormholeEventsFromReceipt(receipt);

  // find VAA events
  if (messageEvents.length == 0) {
    throw new Error("No Wormhole messages found!");
  }

  let results: Buffer[] = [];

  // loop through each event and format the wormhole Observation (message body)
  for (const event of messageEvents) {
    // create a timestamp and find the emitter address
    const timestamp = Math.floor(+new Date() / 1000);
    const emitterAddress: ethers.utils.BytesLike = ethers.utils.hexlify(
      "0x" + tryNativeToHexString(event.args.sender, emitterChainId)
    );

    // encode the observation
    const encodedObservation = ethers.utils.solidityPack(
      ["uint32", "uint32", "uint16", "bytes32", "uint64", "uint8", "bytes"],
      [
        timestamp,
        event.args.nonce,
        emitterChainId,
        emitterAddress,
        event.args.sequence,
        event.args.consistencyLevel,
        event.args.payload,
      ]
    );

    // append the observation to the results buffer array
    results.push(Buffer.from(encodedObservation.substring(2), "hex"));
  }

  return results;
}

export function sortTokenIds(tokenIds: number[]): ethers.BigNumber[] {
  tokenIds.sort(function (a, b) {
    return a - b;
  });

  let results: ethers.BigNumber[] = [];
  for (const tokenId of tokenIds) {
    results.push(ethers.BigNumber.from(tokenId));
  }

  return results;
}
