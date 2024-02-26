// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {IWormhole} from "wormhole-solidity/IWormhole.sol";
import {WormholeSimulator, FakeWormholeSimulator} from "wormhole-solidity/WormholeSimulator.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {y00tsV2} from "../src/nft/y00tsV2.sol";
import {y00ts} from "../src/nft/y00tsV3.sol";

import "forge-std/Test.sol";
import "forge-std/console2.sol";

/**
 * @notice This contract inherits the y00tsV2 contract to expose a `test only` method
 * which allows anyone to mint a y00t for testing purpose.
 */
contract TestY00tsV2 is y00tsV2 {
	constructor(
		IWormhole wormhole,
		IERC20 dustToken,
		bytes32 emitterAddress,
		bytes memory baseUri
	) y00tsV2(wormhole, dustToken, emitterAddress, baseUri) {}

	function mintTestOnly(address recipient, uint16 tokenId) public {
		_safeMint(recipient, uint256(tokenId));
	}

	function exists(uint tokenId) external view returns (bool) {
		return _exists(tokenId);
	}

	function getImplementation() external view returns (address) {
		return _getImplementation();
	}

	function getMaxBatchSize() external pure returns (uint16) {
		return MAX_BATCH_SIZE;
	}
}

/**
 * @notice This contract inherits the y00tsV3 contract to expose a `test only` method
 * which allows anyone to mint a y00t for testing purpose.
 */
contract TestY00tsV3 is y00ts {
	constructor(
		IWormhole wormhole,
		IERC20 dustToken,
		bytes32 emitterAddress,
		bytes memory baseUri
	) y00ts(wormhole, emitterAddress, baseUri) {}

	function mintTestOnly(address recipient, uint16 tokenId) public {
		_safeMint(recipient, uint256(tokenId));
	}

	function exists(uint tokenId) external view returns (bool) {
		return _exists(tokenId);
	}

	function getImplementation() external view returns (address) {
		return _getImplementation();
	}

	function _parseBatchPayload(
		bytes memory message
	) external pure returns (uint256[] memory tokenIds, address recipient) {
		return parseBatchPayload(message);
	}
}

contract TestHelpers is Test {
	struct Balances {
		uint256 recipientDust;
		uint256 recipientNative;
		uint256 recipientNft;
		uint256 relayerEth;
		uint256 relayerDust;
		uint256 nft;
	}

	struct Deployed {
		IERC20 dustToken;
		WormholeSimulator wormholeSimulator;
		IWormhole wormhole;
		bytes32 acceptedEmitter;
	}

	function createBatchAndMint(
		TestY00tsV2 nft,
		address recipient,
		uint256 len,
		uint256 start
	) public returns (uint256[] memory) {
		uint256[] memory arr = new uint256[](len);
		for (uint256 i = 0; i < len; i++) {
			uint256 tokenId = start + i;
			arr[i] = tokenId;

			nft.mintTestOnly(recipient, uint16(tokenId));
		}
		return arr;
	}

	function createBatchIds(uint256 len, uint256 start) public pure returns (uint256[] memory) {
		uint256[] memory arr = new uint256[](len);
		for (uint256 i = 0; i < len; i++) {
			arr[i] = start + i;
		}
		return arr;
	}

	function createBatchPayload(
		uint256[] memory tokenIds,
		address recipient
	) public pure returns (bytes memory) {
		bytes memory payload;
		for (uint256 i = 0; i < tokenIds.length; i++) {
			payload = abi.encodePacked(payload, uint16(tokenIds[i]));
		}
		return abi.encodePacked(payload, recipient);
	}

	function toWormholeFormat(address addr) public pure returns (bytes32 whFormat) {
		return bytes32(uint256(uint160(addr)));
	}

	function fromWormholeFormat(bytes32 whFormatAddress) public pure returns (address addr) {
		return address(uint160(uint256(whFormatAddress)));
	}

	function getBalances(
		Deployed memory deployed,
		TestY00tsV3 nft,
		address user,
		address relayer
	) internal view returns (Balances memory bal) {
		bal.recipientDust = deployed.dustToken.balanceOf(user);
		bal.recipientNative = user.balance;
		bal.recipientNft = nft.balanceOf(user);
		bal.relayerEth = relayer.balance;
		bal.relayerDust = deployed.dustToken.balanceOf(relayer);
	}

	function getBalances(
		Deployed memory deployed,
		TestY00tsV2 nft,
		address user,
		address relayer
	) internal view returns (Balances memory bal) {
		bal.recipientDust = deployed.dustToken.balanceOf(user);
		bal.recipientNative = user.balance;
		bal.recipientNft = nft.balanceOf(user);
		bal.relayerEth = relayer.balance;
		bal.relayerDust = deployed.dustToken.balanceOf(relayer);
	}

	function assertBalanceCheckInbound(
		Balances memory beforeBal,
		Balances memory afterBal,
		uint256 dustAmount,
		uint256 nativeAmount,
		uint256 nftCount
	) public {
		assertEq(beforeBal.recipientDust + dustAmount, afterBal.recipientDust);
		assertEq(beforeBal.recipientNative + nativeAmount, afterBal.recipientNative);
		assertEq(beforeBal.recipientNft + nftCount, afterBal.recipientNft);
		assertEq(beforeBal.relayerEth - nativeAmount, afterBal.relayerEth);
		assertEq(beforeBal.relayerDust - dustAmount, afterBal.relayerDust);
	}

	function assertBalanceCheckOutbound(
		Balances memory beforeBal,
		Balances memory afterBal,
		uint256 nftCount
	) public {
		assertEq(beforeBal.recipientNft - nftCount, afterBal.recipientNft);
	}

	function craftValidVaa(
		Deployed memory deployed,
		uint16 tokenId,
		address evmRecipient,
		uint16 emitterChainId,
		bytes32 emitterAddress
	) internal returns (bytes memory) {
		return
			craftValidVaa(
				deployed,
				emitterChainId,
				emitterAddress,
				abi.encodePacked(tokenId, evmRecipient)
			);
	}

	function craftValidVaa(
		Deployed memory deployed,
		uint16 emitterChainId,
		bytes32 emitterAddress,
		bytes memory payload
	) internal returns (bytes memory) {
		IWormhole.VM memory vaa = IWormhole.VM({
			version: 1,
			timestamp: 0,
			nonce: 0,
			emitterChainId: emitterChainId,
			emitterAddress: emitterAddress,
			sequence: 0,
			consistencyLevel: 1,
			payload: payload,
			guardianSetIndex: deployed.wormhole.getCurrentGuardianSetIndex(),
			signatures: new IWormhole.Signature[](0),
			hash: 0x00
		});

		return deployed.wormholeSimulator.encodeAndSignMessage(vaa);
	}
}
