import { ethers } from "ethers";

// ethereum testnet fork
export const ETH_LOCALHOST = "http://localhost:8546";
export const ETH_WORMHOLE_ADDRESS = process.env.ETH_WORMHOLE!;

// polygon testnet fork
export const POLYGON_LOCALHOST = "http://localhost:8547";
export const POLYGON_WORMHOLE_ADDRESS = process.env.POLYGON_WORMHOLE!;
export const POLYGON_YOOTS = process.env.POLYGON_YOOTS!;
export const POLYGON_YOOTS_OWNER = process.env.POLYGON_YOOTS_OWNER!;
export const POLYGON_DUST = process.env.POLYGON_DUST!;
export const POLYGON_MINTER = process.env.POLYGON_MINTER!;
export const POLYGON_YOOTS_HOLDER = process.env.POLYGON_YOOTS_HOLDER!;
export const POLYGON_HOLDER_INVENTORY: number[] = [
  162, 217, 238, 614, 653, 696, 811, 924, 951, 1208, 1371, 1420, 1463, 1646,
  1843, 1961, 1962, 2530, 2703, 2787, 2801, 2995, 3001, 3188, 3262, 3266, 3555,
  3600, 3801, 4042, 4139, 4179, 4651, 4724, 4776,
];

// global
export const WORMHOLE_MESSAGE_FEE = ethers.BigNumber.from(
  process.env.TESTING_WORMHOLE_MESSAGE_FEE!
);
export const WORMHOLE_GUARDIAN_SET_INDEX = Number(
  process.env.TESTING_WORMHOLE_GUARDIAN_SET_INDEX!
);
export const GUARDIAN_PRIVATE_KEY = process.env.TESTING_DEVNET_GUARDIAN!;
export const WALLET_PRIVATE_KEY = process.env.WALLET_PRIVATE_KEY!;
export const WALLET_PRIVATE_KEY_TWO = process.env.WALLET_PRIVATE_KEY_TWO!;
export const Y00TS_URI = "https://metadata.y00ts.com/y/";
export const SOLANA_TEST_YOOT = process.env.SOLANA_TEST_YOOT!;

// Solidity Smart Contract Errors
export const DEPRECATED_ERROR = "0xc73b9d7c";
export const INVALID_MSG_LEN_ERROR = "0x8d0242c9";

// wormhole event ABIs
export const WORMHOLE_TOPIC =
  "0x6eb224fb001ed210e379b335e35efe88672a8ce935d981a6896b27ffdf52a3b2";
export const WORMHOLE_MESSAGE_EVENT_ABI = [
  "event LogMessagePublished(address indexed sender, uint64 sequence, uint32 nonce, bytes payload, uint8 consistencyLevel)",
];
