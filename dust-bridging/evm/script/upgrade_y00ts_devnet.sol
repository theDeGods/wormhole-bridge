// SPDX-License-Identifier: Apache 2
pragma solidity ^0.8.17;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import {IWormhole} from "wormhole-solidity/IWormhole.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {y00tsV2} from "../src/nft/y00tsV2.sol";

contract UpgradeY00tsDevnetScript is Script {
	address constant proxyAddress = 0xCaa4348e77c12fb4DE5226638E9f6E8d75d25290;
	address constant wormholeAddress = 0x0CBE91CF822c73C2315FB05100C2F714765d5c20;
	address constant dustAddress = 0x5B0b1442B04475d1c3Dbf32DBA261f64F6f2F258;
	bytes32 constant emitterAddress =
		0x3a5a8772eeab57012f4a030a584cd8efb87a8996e89bb2d7999ad9dea97a0a4e;
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

		console.log("Upgrading y00ts devnet");
		upgrade();

		vm.stopBroadcast();
	}
}
