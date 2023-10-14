// SPDX-License-Identifier: Apache 2

pragma solidity ^0.8.17;

import "forge-std/Script.sol";
import "forge-std/console.sol";

import {IWormhole} from "wormhole-solidity/IWormhole.sol";
import {y00tsV3} from "../src/nft/y00tsV3.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "wormhole-solidity/BytesLib.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {IRegistry} from "registry/IRegistry.sol";

contract ContractScript is Script {
	using BytesLib for bytes;
	// bytes32 constant minterAddress =
	// 	0x000000000000000000000000670fd103b1a08628e9557cD66B87DeD841115190; // Polygon y00tsV2 Mainnet
	bytes32 constant minterAddress =
		0x000000000000000000000000Caa4348e77c12fb4DE5226638E9f6E8d75d25290; // Polygon y00tsV2 Devnet
	uint256 constant dustAmountOnMint = 0;
	uint256 constant gasTokenAmountOnMint = 0;
	address constant royaltyReceiver = 0xa45D808eAFDe8B8E6B6B078fd246e28AD13030E8;
	uint96 constant royaltyFeeNumerator = 333;
	bytes constant baseUri = "https://metadata.y00ts.com/y/";
	string constant name = "y00ts";
	string constant symbol = "y00t";

	// Ethereum Wormhole mainnet
	// IWormhole wormhole = IWormhole(0x98f3c9e6E3fAce36bAAd05FE09d375Ef1464288B);
	// IERC20 dustToken = IERC20(0xB5b1b659dA79A2507C27AaD509f15B4874EDc0Cc);

	// Ethereum Wormhole devnet
	IWormhole wormhole = IWormhole(0x706abc4E45D419950511e474C7B9Ed348A4a716c);
	IERC20 dustToken = IERC20(0xAD290867AEFFA008cDC182dC1092bFB378340Ba8); 
	IRegistry registry = IRegistry(0xAD290867AEFFA008cDC182dC1092bFB378340Ba8);

	y00tsV3 nft;

	function deployContract() public {
		//Deploy our contract for testing
		y00tsV3 nftImplementation = new y00tsV3(wormhole, dustToken, minterAddress, baseUri, registry);
		ERC1967Proxy proxy = new ERC1967Proxy(
			address(nftImplementation),
			abi.encodeCall(
				nftImplementation.initialize,
				(
					name,
					symbol,
					dustAmountOnMint,
					gasTokenAmountOnMint,
					royaltyReceiver,
					royaltyFeeNumerator
				)
			)
		);
		nft = y00tsV3(address(proxy));
	}

	function run() public {
		// begin sending transactions
		vm.startBroadcast();

		// y00tsV3.sol
		console.log("Deploying contract");
		deployContract();

		// finished
		vm.stopBroadcast();
	}
}
