// SPDX-License-Identifier: Apache 2
pragma solidity ^0.8.17;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import {IWormhole} from "wormhole-solidity/IWormhole.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {y00tsV2} from "../src/nft/y00tsV2.sol";

contract UpgradeY00tsMainnetScript is Script {
	address constant proxyAddress = 0x670fd103b1a08628e9557cD66B87DeD841115190;
	address constant wormholeAddress = 0x7A4B5a56256163F07b2C80A7cA55aBE66c4ec4d7;
	address constant dustAddress = 0x4987A49C253c38B3259092E9AAC10ec0C7EF7542;
	bytes32 constant emitterAddress =
		0x5ec18c34b47c63d17ab43b07b9b2319ea5ee2d163bce2e467000174e238c8e7f;
	bytes constant y00tsBaseUri = "https://metadata.y00ts.com/y/";

	function upgrade() public {
		y00tsV2(proxyAddress).upgradeTo(
			address(
				new y00tsV2(
					IWormhole(wormholeAddress),
					IERC20(dustAddress),
					emitterAddress,
					y00tsBaseUri
				)
			)
		);
	}

	function run() public {
		vm.startBroadcast();

		console.log("Upgrading y00ts mainnet");
		upgrade();

		vm.stopBroadcast();
	}
}
