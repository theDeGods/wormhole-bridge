// SPDX-License-Identifier: Apache 2

pragma solidity ^0.8.0;

import {MockWormhole} from "wormhole-solidity/MockWormhole.sol";
import {WormholeSimulator, FakeWormholeSimulator} from "wormhole-solidity/WormholeSimulator.sol";
import {IWormhole} from "wormhole-solidity/IWormhole.sol";
import {TestHelpers, TestY00tsV2, TestY00tsV3} from "./TestHelpers.sol";
import "wormhole-solidity/BytesLib.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

import {MockDust} from "./MockDust.sol";

import "forge-std/Test.sol";
import "forge-std/console2.sol";

contract TestY00tsMigration is TestHelpers {
	using BytesLib for bytes;

	// Wormhole chain IDs for Ethereum and Polygon.
	uint16 constant polygonWormholeChain = 5;
	uint16 constant ethereumWormholeChain = 2;
	uint16 constant solanaWormholeChain = 1;

	uint16 constant maxY00tsSupply = 15_000;
	uint8 constant evmFinality = 201;
	bytes32 constant userAddress = bytes32("user address") >> (12 * 8);
	uint256 constant dustAmountOnMint = 1e18;
	uint256 constant gasTokenAmountOnMint = 1e16;
	uint256 constant wormholeFee = 1e6;
	address constant royaltyReceiver = address(0x1234);
	uint96 constant royaltyFeeNumerator = 250;
	bytes constant baseUri = "https://base.uri.test/";
	string constant name = "testing token name";
	string constant symbol = "testing token symbol";

	//deployed contracts required for testing
	Deployed polygon;
	Deployed ethereum;
	TestY00tsV2 polygonNft;
	TestY00tsV3 ethereumNft;

	function _beforeDeployment(
		Deployed storage deployed,
		uint16 initChainId,
		address acceptedEmitter
	) internal {
		// deploy Wormhole to "Polygon"
		MockWormhole mockWormhole = new MockWormhole({
			initChainId: initChainId,
			initEvmChainId: block.chainid
		});
		deployed.wormhole = mockWormhole;
		deployed.wormholeSimulator = new FakeWormholeSimulator(mockWormhole);
		deployed.wormholeSimulator.setMessageFee(wormholeFee);

		// address(this) receives the dust tokens.
		deployed.dustToken = new MockDust(dustAmountOnMint * 10);

		// only VAAs from this emitter can mint NFTs with our contract (prevents spoofing)
		deployed.acceptedEmitter = toWormholeFormat(acceptedEmitter);
	}

	function _deployPolygon(uint16 initChainId, address acceptedEmitter) internal {
		// deploy prerequisites: wormhole, dust token
		_beforeDeployment(polygon, initChainId, acceptedEmitter);

		// deploy our contract for testing
		TestY00tsV2 nftImplementation = new TestY00tsV2(
			polygon.wormhole,
			polygon.dustToken,
			polygon.acceptedEmitter,
			baseUri
		);
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
		polygonNft = TestY00tsV2(address(proxy));
	}

	function _deployEthereum(uint16 initChainId, address acceptedEmitter) internal {
		// deploy prerequisites: wormhole, dust token
		_beforeDeployment(ethereum, initChainId, acceptedEmitter);

		// deploy our contract for testing
		TestY00tsV3 nftImplementation = new TestY00tsV3(
			ethereum.wormhole,
			ethereum.dustToken,
			ethereum.acceptedEmitter,
			baseUri
		);
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
		ethereumNft = TestY00tsV3(address(proxy));
	}

	function setUp() public {
		// deploy polygon with a random accepted emitter
		_deployPolygon(polygonWormholeChain, makeAddr("solanaEmitter"));

		// deploy ethereum with the polygon emitter
		_deployEthereum(ethereumWormholeChain, address(polygonNft));
	}

	/**
	 * TESTS
	 */

	function testUpgradeY00tsV2() public {
		address newImplementation = address(
			new TestY00tsV2(polygon.wormhole, polygon.dustToken, polygon.acceptedEmitter, baseUri)
		);

		// upgrade the implementation
		TestY00tsV2(address(polygonNft)).upgradeTo(newImplementation);

		assertEq(polygonNft.getImplementation(), newImplementation);
	}

	function testUpgradeY00tsV3() public {
		address newImplementation = address(
			new TestY00tsV3(
				ethereum.wormhole,
				ethereum.dustToken,
				ethereum.acceptedEmitter,
				baseUri
			)
		);

		// upgrade the implementation
		TestY00tsV2(address(ethereumNft)).upgradeTo(newImplementation);

		assertEq(ethereumNft.getImplementation(), newImplementation);
	}

	function testCannotUpgradeY00tsV2OwnerOnly() public {
		address newImplementation = address(
			new TestY00tsV2(polygon.wormhole, polygon.dustToken, polygon.acceptedEmitter, baseUri)
		);

		// upgrade the implementation
		vm.prank(makeAddr("0xdeadbeef"));
		vm.expectRevert("Ownable: caller is not the owner");
		TestY00tsV2(address(polygonNft)).upgradeTo(newImplementation);
	}

	function testCannotUpgradeY00tsV3OwnerOnly() public {
		address newImplementation = address(
			new TestY00tsV3(
				ethereum.wormhole,
				ethereum.dustToken,
				ethereum.acceptedEmitter,
				baseUri
			)
		);

		// upgrade the implementation
		vm.prank(makeAddr("0xdeadbeef"));
		vm.expectRevert("Ownable: caller is not the owner");
		TestY00tsV2(address(ethereumNft)).upgradeTo(newImplementation);
	}

	function testCannotReceiveAndMintOnPolygon(uint16 tokenId) public {
		vm.assume(tokenId < maxY00tsSupply);

		bytes memory mintVaa = craftValidVaa(
			polygon,
			tokenId,
			fromWormholeFormat(userAddress),
			solanaWormholeChain,
			polygon.acceptedEmitter
		);

		vm.expectRevert(abi.encodeWithSignature("Deprecated()"));
		polygonNft.receiveAndMint(mintVaa);
	}

	/**
	 * Send And Mint Tests
	 */

	function testBurnAndSendOnPolygon(uint16 tokenId) public {
		vm.assume(tokenId < maxY00tsSupply);

		address recipient = fromWormholeFormat(userAddress);

		// mint an NFT on Polygon
		polygonNft.mintTestOnly(recipient, tokenId);

		// burn and send the NFT on polygon
		vm.prank(address(recipient));
		polygonNft.approve(address(this), tokenId);
		vm.deal(address(this), wormholeFee);

		Balances memory beforeBal = getBalances(
			polygon,
			polygonNft,
			fromWormholeFormat(userAddress),
			address(this)
		);

		// start recording logs to capture the wormhole message
		vm.recordLogs();
		polygonNft.burnAndSend{value: wormholeFee}(tokenId, recipient);

		// Fetch the emitted VM and parse the payload. The wormhole message will
		// be the second log, since the first log is the `Transfer` event.
		Vm.Log[] memory entries = vm.getRecordedLogs();

		IWormhole.VM memory vm_ = polygon.wormholeSimulator.parseVMFromLogs(entries[2]);
		assertEq(vm_.payload.toUint16(0), tokenId);
		assertEq(vm_.payload.toAddress(BytesLib.uint16Size), recipient);

		Balances memory afterBal = getBalances(
			polygon,
			polygonNft,
			fromWormholeFormat(userAddress),
			address(this)
		);

		assertTrue(!polygonNft.exists(tokenId));
		assertBalanceCheckOutbound(beforeBal, afterBal, 1);
	}

	function testCannotBurnAndSendOnPolygonBurnNotApproved(uint16 tokenId) public {
		vm.assume(tokenId < maxY00tsSupply);

		address recipient = fromWormholeFormat(userAddress);

		// mint an NFT on Polygon
		polygonNft.mintTestOnly(recipient, tokenId);

		// burn and send the NFT on polygon
		vm.prank(address(recipient));
		vm.deal(address(this), wormholeFee);

		vm.expectRevert();
		// forge is not reverting with data here (bug)
		polygonNft.burnAndSend{value: wormholeFee}(tokenId, recipient);
	}

	function testCannotBurnAndSendOnPolygonLocked(uint16 tokenId) public {
		vm.assume(tokenId < maxY00tsSupply);

		address recipient = fromWormholeFormat(userAddress);

		// mint an NFT on Polygon
		polygonNft.mintTestOnly(recipient, tokenId);

		// burn and send the NFT on polygon
		vm.prank(address(recipient));

		//lock the NFT
		polygonNft.lock(
			tokenId,
			0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
		);

		vm.prank(address(recipient));
		polygonNft.approve(address(this), tokenId);

		vm.expectRevert("ERC5058: token transfer while locked");
		polygonNft.burnAndSend{value: wormholeFee}(tokenId, recipient);
	}

	function testCannotBurnAndSendOnPolygonRecipientZeroAddress(uint16 tokenId) public {
		vm.assume(tokenId < maxY00tsSupply);

		address recipient = fromWormholeFormat(userAddress);

		// mint an NFT on Polygon
		polygonNft.mintTestOnly(recipient, tokenId);

		vm.prank(address(recipient));
		polygonNft.approve(address(this), tokenId);

		vm.expectRevert(abi.encodeWithSignature("RecipientZeroAddress()"));
		polygonNft.burnAndSend{value: wormholeFee}(tokenId, address(0));
	}

	/**
	 * Receive and Mint Tests
	 */

	function testReceiveAndMintOnEthereum(uint16 tokenId) public {
		vm.assume(tokenId < maxY00tsSupply);

		// craft a VAA sent from the Polygon contract to Ethereum
		bytes memory mintVaa = craftValidVaa(
			ethereum,
			tokenId,
			fromWormholeFormat(userAddress),
			polygonWormholeChain, // emitter chainId
			ethereum.acceptedEmitter
		);

		(uint256 dustAmount, uint256 gasTokenAmount) = ethereumNft.getAmountsOnMint();
		vm.deal(address(this), gasTokenAmount);

		// We need to balance check after dealing the dust token.
		Balances memory beforeBal = getBalances(
			ethereum,
			ethereumNft,
			fromWormholeFormat(userAddress),
			address(this)
		);

		ethereum.dustToken.approve(address(ethereumNft), dustAmount);
		ethereumNft.receiveAndMint{value: gasTokenAmount}(mintVaa);

		Balances memory afterBal = getBalances(
			ethereum,
			ethereumNft,
			fromWormholeFormat(userAddress),
			address(this)
		);

		assertEq(ethereumNft.ownerOf(tokenId), fromWormholeFormat(userAddress));
		assertBalanceCheckInbound(beforeBal, afterBal, dustAmount, gasTokenAmount, 1);
	}

	function testCannotReceiveAndMintOnEthereumWrongEmitterAddress() public {
		uint16 tokenId = 5;

		// craft a VAA sent from the Polygon contract to Ethereum
		bytes memory mintVaa = craftValidVaa(
			ethereum,
			tokenId,
			fromWormholeFormat(userAddress),
			polygonWormholeChain, // emitter chainId
			toWormholeFormat(makeAddr("spoofedEmitter"))
		);

		(uint256 dustAmount, uint256 gasTokenAmount) = ethereumNft.getAmountsOnMint();
		vm.deal(address(this), gasTokenAmount);

		ethereum.dustToken.approve(address(ethereumNft), dustAmount);

		vm.expectRevert(abi.encodeWithSignature("WrongEmitterAddress()"));
		ethereumNft.receiveAndMint{value: gasTokenAmount}(mintVaa);
	}

	function testCannotReceiveAndMintOnEthereumWrongEmitterChainId() public {
		uint16 tokenId = 5;

		// craft a VAA sent from the Polygon contract to Ethereum
		bytes memory mintVaa = craftValidVaa(
			ethereum,
			tokenId,
			fromWormholeFormat(userAddress),
			solanaWormholeChain, // invalid emitter chain
			ethereum.acceptedEmitter
		);

		(uint256 dustAmount, uint256 gasTokenAmount) = ethereumNft.getAmountsOnMint();
		vm.deal(address(this), gasTokenAmount);

		ethereum.dustToken.approve(address(ethereumNft), dustAmount);

		vm.expectRevert(abi.encodeWithSignature("WrongEmitterChainId()"));
		ethereumNft.receiveAndMint{value: gasTokenAmount}(mintVaa);
	}

	function testCannotReceiveAndMintOnEthereumAgain() public {
		uint16 tokenId = 5;

		//craft a VAA sent from the Polygon contract to Ethereum
		bytes memory mintVaa = craftValidVaa(
			ethereum,
			tokenId,
			fromWormholeFormat(userAddress),
			polygonWormholeChain, // emitter chainId
			ethereum.acceptedEmitter
		);

		(uint256 dustAmount, uint256 gasTokenAmount) = ethereumNft.getAmountsOnMint();
		vm.deal(address(this), gasTokenAmount);

		ethereum.dustToken.approve(address(ethereumNft), dustAmount);
		ethereumNft.receiveAndMint{value: gasTokenAmount}(mintVaa);

		// try to mint again
		vm.deal(address(this), gasTokenAmount);
		vm.expectRevert(); // forge is not reverting with data here (bug)
		ethereumNft.receiveAndMint{value: gasTokenAmount}(mintVaa);
	}

	function testTokenURIOnEthereum(uint16 tokenId) public {
		vm.assume(tokenId < maxY00tsSupply);

		//craft a VAA sent from the Polygon contract to Ethereum
		bytes memory mintVaa = craftValidVaa(
			ethereum,
			tokenId,
			fromWormholeFormat(userAddress),
			polygonWormholeChain, // emitter chainId
			ethereum.acceptedEmitter
		);

		(uint256 dustAmount, uint256 gasTokenAmount) = ethereumNft.getAmountsOnMint();
		ethereum.dustToken.approve(address(ethereumNft), dustAmount);
		vm.deal(address(this), gasTokenAmount);
		ethereumNft.receiveAndMint{value: gasTokenAmount}(mintVaa);

		string memory uri = ethereumNft.tokenURI(tokenId);
		assertEq(
			bytes(uri),
			bytes(abi.encodePacked(baseUri, Strings.toString(tokenId), string(".json")))
		);
	}

	/**
	 * Forward Message Tests
	 */

	function testForwardMessage(uint16 tokenId) public {
		vm.assume(tokenId < maxY00tsSupply);

		// craft a VAA sent from the Solana contract to Polygon
		bytes memory forwardVaa = craftValidVaa(
			polygon,
			tokenId,
			fromWormholeFormat(userAddress),
			solanaWormholeChain, // emitter chainId
			polygon.acceptedEmitter
		);

		// forward the message from Polygon to Ethereum
		vm.recordLogs();

		vm.deal(address(this), wormholeFee);
		polygonNft.forwardMessage{value: wormholeFee}(forwardVaa);

		// Fetch the emitted VM and sign the message. The Wormhole message is
		// the first emitted log in this scenario.
		Vm.Log[] memory entries = vm.getRecordedLogs();
		bytes memory mintVaa = polygon.wormholeSimulator.fetchSignedMessageFromLogs(
			entries[0],
			polygonWormholeChain, // emitter chain
			address(polygonNft) // emitter address
		);

		// now receive and mint on Ethereum
		(uint256 dustAmount, uint256 gasTokenAmount) = ethereumNft.getAmountsOnMint();
		vm.deal(address(this), gasTokenAmount);

		// We need to balance check after dealing the dust token.
		Balances memory beforeBal = getBalances(
			ethereum,
			ethereumNft,
			fromWormholeFormat(userAddress),
			address(this)
		);

		ethereum.dustToken.approve(address(ethereumNft), dustAmount);
		ethereumNft.receiveAndMint{value: gasTokenAmount}(mintVaa);

		Balances memory afterBal = getBalances(
			ethereum,
			ethereumNft,
			fromWormholeFormat(userAddress),
			address(this)
		);

		assertEq(ethereumNft.ownerOf(tokenId), fromWormholeFormat(userAddress));
		assertBalanceCheckInbound(beforeBal, afterBal, dustAmount, gasTokenAmount, 1);
	}

	function testCannotForwardMessageWrongEmitterAddress() public {
		uint16 tokenId = 5;

		// craft a VAA sent from the Solana contract to Polygon
		bytes memory forwardVaa = craftValidVaa(
			polygon,
			tokenId,
			fromWormholeFormat(userAddress),
			solanaWormholeChain,
			toWormholeFormat(makeAddr("badEmitterAddress"))
		);

		vm.expectRevert(abi.encodeWithSignature("WrongEmitterAddress()"));
		polygonNft.forwardMessage{value: wormholeFee}(forwardVaa);
	}

	function testCannotForwardMessageWrongEmitterChainId() public {
		uint16 tokenId = 5;

		// craft a VAA sent from the Solana contract to Polygon
		bytes memory forwardVaa = craftValidVaa(
			polygon,
			tokenId,
			fromWormholeFormat(userAddress),
			ethereumWormholeChain, // bad emitter chainId
			polygon.acceptedEmitter
		);

		vm.expectRevert(abi.encodeWithSignature("WrongEmitterChainId()"));
		polygonNft.forwardMessage{value: wormholeFee}(forwardVaa);
	}

	function testCannotForwardMessageInvalidMessageLength() public {
		uint16 tokenId = 5;

		// craft a VAA sent from the Solana contract to Polygon
		bytes memory forwardVaa = craftValidVaa(
			polygon,
			solanaWormholeChain,
			polygon.acceptedEmitter,
			hex"deadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef" // Invalid payload
		);

		vm.expectRevert(abi.encodeWithSignature("InvalidMessageLength()"));
		polygonNft.forwardMessage{value: wormholeFee}(forwardVaa);
	}

	function testCannotForwardMessageAgain() public {
		uint16 tokenId = 5;

		// craft a VAA sent from the Solana contract to Polygon
		bytes memory forwardVaa = craftValidVaa(
			polygon,
			tokenId,
			fromWormholeFormat(userAddress),
			solanaWormholeChain, // emitter chainId
			polygon.acceptedEmitter
		);

		vm.deal(address(this), wormholeFee);
		polygonNft.forwardMessage{value: wormholeFee}(forwardVaa);

		vm.deal(address(this), wormholeFee);
		vm.expectRevert(); // forge is not reverting with data here (bug)
		polygonNft.forwardMessage{value: wormholeFee}(forwardVaa);
	}

	/**
	 * Sending Batch Tests
	 */

	function testBurnAndSendBatch(uint256 tokenCount, uint256 start) public {
		vm.assume(tokenCount > 1 && tokenCount <= polygonNft.getMaxBatchSize());
		vm.assume(start < maxY00tsSupply - tokenCount);

		address spender = makeAddr("spender");
		address recipient = fromWormholeFormat(userAddress);

		// create batch of tokenIds
		uint256[] memory tokenIds = createBatchAndMint(polygonNft, spender, tokenCount, start);
		assertEq(polygonNft.balanceOf(spender), tokenCount);

		vm.recordLogs();

		// burn and send batch
		vm.deal(spender, wormholeFee);
		vm.prank(spender);
		polygonNft.burnAndSend{value: wormholeFee}(tokenIds, recipient);

		// confirm spender's balance is zero and all nfts were burned
		assertEq(polygonNft.balanceOf(spender), 0);
		for (uint256 i = 0; i < tokenCount; i++) {
			assertTrue(!polygonNft.exists(tokenIds[i]));
		}

		// Fetch the emitted VM and sign the message. The Wormhole message is
		// the last emitted log in this scenario. There are two events
		// per token that is burned.
		IWormhole.VM memory vm_ = polygon.wormholeSimulator.parseVMFromLogs(
			vm.getRecordedLogs()[tokenCount * 2]
		);

		// verify the message payload.
		uint256 expectedMessagelength = tokenCount * 2 + 20;
		assertEq(vm_.payload.length, expectedMessagelength);
		assertEq(vm_.payload.toAddress(expectedMessagelength - 20), recipient);
		for (uint256 i = 0; i < tokenCount; i++) {
			assertEq(vm_.payload.toUint16(i * 2), tokenIds[i]);
		}
	}

	function testCannotBurnAndSendBatchZeroTokens() public {
		uint256 tokenCount = 0;
		uint256 start = 0;

		address spender = makeAddr("spender");
		address recipient = fromWormholeFormat(userAddress);

		// create batch of tokenIds
		uint256[] memory tokenIds = createBatchAndMint(polygonNft, spender, tokenCount, start);

		// burn and send batch
		vm.deal(spender, wormholeFee);
		vm.prank(spender);

		vm.expectRevert(abi.encodeWithSignature("InvalidBatchCount()"));
		polygonNft.burnAndSend{value: wormholeFee}(tokenIds, recipient);
	}

	function testCannotBurnAndSendBatchOneToken() public {
		uint256 tokenCount = 1;
		uint256 start = 0;

		address spender = makeAddr("spender");
		address recipient = fromWormholeFormat(userAddress);

		// create batch of tokenIds
		uint256[] memory tokenIds = createBatchAndMint(polygonNft, spender, tokenCount, start);

		// burn and send batch
		vm.deal(spender, wormholeFee);
		vm.prank(spender);

		vm.expectRevert(abi.encodeWithSignature("InvalidBatchCount()"));
		polygonNft.burnAndSend{value: wormholeFee}(tokenIds, recipient);
	}

	function testCannotBurnAndSendBatchTooManyTokens() public {
		uint256 tokenCount = polygonNft.getMaxBatchSize() + 1;
		uint256 start = 0;

		address spender = makeAddr("spender");
		address recipient = fromWormholeFormat(userAddress);

		// create batch of tokenIds
		uint256[] memory tokenIds = createBatchAndMint(polygonNft, spender, tokenCount, start);

		// burn and send batch
		vm.deal(spender, wormholeFee);
		vm.prank(spender);

		vm.expectRevert(abi.encodeWithSignature("InvalidBatchCount()"));
		polygonNft.burnAndSend{value: wormholeFee}(tokenIds, recipient);
	}

	function testCannotBurnAndSendBatchRecipientZeroAddress() public {
		uint256 tokenCount = 5;
		uint256 start = 0;

		address spender = makeAddr("spender");
		address recipient = address(0);

		// create batch of tokenIds
		uint256[] memory tokenIds = createBatchAndMint(polygonNft, spender, tokenCount, start);

		// burn and send batch
		vm.deal(spender, wormholeFee);
		vm.prank(spender);

		vm.expectRevert(abi.encodeWithSignature("RecipientZeroAddress()"));
		polygonNft.burnAndSend{value: wormholeFee}(tokenIds, recipient);
	}

	function testCannotBurnAndSendBatchDuplicateTokenIds() public {
		uint256 tokenCount = 5;
		uint256 start = 0;

		address spender = makeAddr("spender");
		address recipient = makeAddr("recipient");

		// create batch of tokenIds
		uint256[] memory tokenIds = createBatchAndMint(polygonNft, spender, tokenCount, start);

		// add a duplicate token id
		tokenIds[1] = tokenIds[0];

		// burn and send batch
		vm.deal(spender, wormholeFee);
		vm.prank(spender);

		vm.expectRevert(abi.encodeWithSignature("NotAscendingOrDuplicated()"));
		polygonNft.burnAndSend{value: wormholeFee}(tokenIds, recipient);
	}

	function testCannotBurnAndSendBatchNotAscendingTokenIds() public {
		uint256 tokenCount = 25;
		uint256 start = 0;

		address spender = makeAddr("spender");
		address recipient = makeAddr("recipient");

		// create batch of tokenIds
		uint256[] memory tokenIds = createBatchAndMint(polygonNft, spender, tokenCount, start);

		// swap two token ids so the order is not ascending
		uint256 placeholder = tokenIds[20];
		tokenIds[20] = tokenIds[21];
		tokenIds[21] = placeholder;

		// burn and send batch
		vm.deal(spender, wormholeFee);
		vm.prank(spender);

		vm.expectRevert(abi.encodeWithSignature("NotAscendingOrDuplicated()"));
		polygonNft.burnAndSend{value: wormholeFee}(tokenIds, recipient);
	}

	function testCannotBurnAndSendBatchBurnNotApproved() public {
		uint256 tokenCount = 25;
		uint256 start = 0;

		address spender = makeAddr("spender");
		address notOwner = makeAddr("notTheSpender");
		address recipient = makeAddr("recipient");

		// create batch of tokenIds
		uint256[] memory tokenIds = createBatchAndMint(polygonNft, spender, tokenCount, start);

		// burn and send batch
		vm.deal(notOwner, wormholeFee);
		vm.prank(notOwner);

		vm.expectRevert(abi.encodeWithSignature("BurnNotApproved()"));
		polygonNft.burnAndSend{value: wormholeFee}(tokenIds, recipient);
	}

	function testCannotBurnAndSendBatchBurnNotApprovedSingleToken() public {
		uint256 tokenCount = 25;
		uint256 start = 0;

		address spender = makeAddr("spender");
		address notOwner = makeAddr("notTheSpender");
		address recipient = makeAddr("recipient");

		// create batch of tokenIds
		uint256[] memory tokenIds = createBatchAndMint(polygonNft, spender, tokenCount, start);

		// prank spender for approvals
		vm.startPrank(spender);

		// approve all tokens
		for (uint256 i = 0; i < tokenCount - 1; i++) {
			polygonNft.approve(notOwner, tokenIds[i]);
		}

		vm.stopPrank();

		// burn and send batch
		vm.deal(notOwner, wormholeFee);
		vm.prank(notOwner);

		vm.expectRevert(abi.encodeWithSignature("BurnNotApproved()"));
		polygonNft.burnAndSend{value: wormholeFee}(tokenIds, recipient);
	}

	/**
	 * Receiving Batch Tests
	 */

	function testParseBatchPayload(uint256 tokenCount, uint256 start) public {
		vm.assume(tokenCount > 1 && tokenCount <= polygonNft.getMaxBatchSize());
		vm.assume(start < maxY00tsSupply - tokenCount);

		address recipient = fromWormholeFormat(userAddress);

		// create batch of tokenIds
		uint256[] memory tokenIds = createBatchIds(tokenCount, start);

		// parse the payload
		(uint256[] memory parsedTokenIds, address parsedRecipient) = ethereumNft._parseBatchPayload(
			createBatchPayload(tokenIds, recipient)
		);

		// validate parsed output
		assertEq(parsedTokenIds.length, tokenCount);
		assertEq(parsedRecipient, recipient);
		for (uint256 i = 0; i < tokenCount; i++) {
			assertEq(parsedTokenIds[i], tokenIds[i]);
		}
	}

	function testReceiveAndMintBatch(uint256 tokenCount, uint256 start) public {
		vm.assume(tokenCount > 1 && tokenCount <= polygonNft.getMaxBatchSize());
		vm.assume(start < maxY00tsSupply - tokenCount);

		address recipient = fromWormholeFormat(userAddress);

		// create batch of tokenIds
		uint256[] memory tokenIds = createBatchIds(tokenCount, start);

		// create batch mint VAA
		bytes memory batchVaa = craftValidVaa(
			ethereum,
			polygonWormholeChain,
			ethereum.acceptedEmitter,
			createBatchPayload(tokenIds, recipient)
		);

		(uint256 dustAmount, uint256 gasTokenAmount) = ethereumNft.getAmountsOnMint();
		vm.deal(address(this), gasTokenAmount);

		// We need to balance check after dealing the dust token.
		Balances memory beforeBal = getBalances(
			ethereum,
			ethereumNft,
			fromWormholeFormat(userAddress),
			address(this)
		);

		ethereum.dustToken.approve(address(ethereumNft), dustAmount);
		ethereumNft.receiveAndMintBatch{value: gasTokenAmount}(batchVaa);

		Balances memory afterBal = getBalances(
			ethereum,
			ethereumNft,
			fromWormholeFormat(userAddress),
			address(this)
		);

		// Confirm recipient is now owner of each nft in the batch, and validate
		// the gas drop off.
		assertBalanceCheckInbound(beforeBal, afterBal, dustAmount, gasTokenAmount, tokenCount);
		for (uint256 i = 0; i < tokenCount; i++) {
			assertEq(ethereumNft.ownerOf(tokenIds[i]), recipient);
		}
	}

	function testCannotReceiveAndMintBatchAgain() public {
		uint256 tokenCount = 5;
		uint256 start = 0;

		// create batch mint VAA
		bytes memory batchVaa = craftValidVaa(
			ethereum,
			polygonWormholeChain,
			ethereum.acceptedEmitter,
			createBatchPayload(createBatchIds(tokenCount, start), fromWormholeFormat(userAddress))
		);

		(uint256 dustAmount, uint256 gasTokenAmount) = ethereumNft.getAmountsOnMint();
		vm.deal(address(this), gasTokenAmount);

		ethereum.dustToken.approve(address(ethereumNft), dustAmount);
		ethereumNft.receiveAndMintBatch{value: gasTokenAmount}(batchVaa);

		// try to mint again
		vm.deal(address(this), gasTokenAmount);
		vm.expectRevert(); // forge is not reverting with data here (bug)
		ethereumNft.receiveAndMintBatch{value: gasTokenAmount}(batchVaa);
	}

	function testCannotReceiveAndMintBatchWrongEmitterChainId() public {
		uint256 tokenCount = 5;
		uint256 start = 0;

		// create batch mint VAA
		bytes memory batchVaa = craftValidVaa(
			ethereum,
			solanaWormholeChain, // invalid chain Id
			ethereum.acceptedEmitter,
			createBatchPayload(createBatchIds(tokenCount, start), fromWormholeFormat(userAddress))
		);

		(uint256 dustAmount, uint256 gasTokenAmount) = ethereumNft.getAmountsOnMint();
		vm.deal(address(this), gasTokenAmount);
		ethereum.dustToken.approve(address(ethereumNft), dustAmount);

		vm.expectRevert(abi.encodeWithSignature("WrongEmitterChainId()"));
		ethereumNft.receiveAndMintBatch{value: gasTokenAmount}(batchVaa);
	}

	function testCannotReceiveAndMintBatchWrongEmitterAddress() public {
		uint256 tokenCount = 5;
		uint256 start = 0;

		// create batch mint VAA
		bytes memory batchVaa = craftValidVaa(
			ethereum,
			polygonWormholeChain,
			toWormholeFormat(makeAddr("invalid emitter")), // invalid emitter address
			createBatchPayload(createBatchIds(tokenCount, start), fromWormholeFormat(userAddress))
		);

		(uint256 dustAmount, uint256 gasTokenAmount) = ethereumNft.getAmountsOnMint();
		vm.deal(address(this), gasTokenAmount);
		ethereum.dustToken.approve(address(ethereumNft), dustAmount);

		vm.expectRevert(abi.encodeWithSignature("WrongEmitterAddress()"));
		ethereumNft.receiveAndMintBatch{value: gasTokenAmount}(batchVaa);
	}

	function testCannotReceiveAndMintBatchModuloNonzero() public {
		uint256 tokenCount = 5;
		uint256 start = 0;

		bytes memory payload = createBatchPayload(
			createBatchIds(tokenCount, start),
			fromWormholeFormat(userAddress)
		);

		// create batch mint VAA, add an extra byte at the end
		bytes memory batchVaa = craftValidVaa(
			ethereum,
			polygonWormholeChain,
			ethereum.acceptedEmitter,
			abi.encodePacked(payload, hex"69")
		);

		(uint256 dustAmount, uint256 gasTokenAmount) = ethereumNft.getAmountsOnMint();
		vm.deal(address(this), gasTokenAmount);
		ethereum.dustToken.approve(address(ethereumNft), dustAmount);

		vm.expectRevert(abi.encodeWithSignature("InvalidMessageLength()"));
		ethereumNft.receiveAndMintBatch{value: gasTokenAmount}(batchVaa);
	}

	function testCannotReceiveAndMintBatchNotEnoughBytes() public {
		uint256 tokenCount = 1;
		uint256 start = 0;

		bytes memory payload = createBatchPayload(
			createBatchIds(tokenCount, start),
			fromWormholeFormat(userAddress)
		);
		require(payload.length == 22, "invalid payload");

		// create batch mint VAA, but with only a single token ID
		bytes memory batchVaa = craftValidVaa(
			ethereum,
			polygonWormholeChain,
			ethereum.acceptedEmitter,
			payload
		);

		(uint256 dustAmount, uint256 gasTokenAmount) = ethereumNft.getAmountsOnMint();
		vm.deal(address(this), gasTokenAmount);
		ethereum.dustToken.approve(address(ethereumNft), dustAmount);

		vm.expectRevert(abi.encodeWithSignature("InvalidMessageLength()"));
		ethereumNft.receiveAndMintBatch{value: gasTokenAmount}(batchVaa);
	}

	function testCannotReceiveAndMintBatchInvalidMessageValueSelfRedeem() public {
		uint256 tokenCount = 5;
		uint256 start = 0;

		address recipient = fromWormholeFormat(userAddress);

		bytes memory payload = createBatchPayload(createBatchIds(tokenCount, start), recipient);

		// create batch mint VAA, but with only a single token ID
		bytes memory batchVaa = craftValidVaa(
			ethereum,
			polygonWormholeChain,
			ethereum.acceptedEmitter,
			payload
		);

		(uint256 dustAmount, uint256 gasTokenAmount) = ethereumNft.getAmountsOnMint();
		vm.deal(recipient, gasTokenAmount);
		ethereum.dustToken.approve(address(ethereumNft), dustAmount);

		// self redeem, but send value
		vm.prank(recipient);
		vm.expectRevert(abi.encodeWithSignature("InvalidMsgValue()"));
		ethereumNft.receiveAndMintBatch{value: gasTokenAmount}(batchVaa);
	}

	function testCannotReceiveAndMintBatchInvalidMessageValueRelayer() public {
		uint256 tokenCount = 5;
		uint256 start = 0;

		bytes memory payload = createBatchPayload(
			createBatchIds(tokenCount, start),
			fromWormholeFormat(userAddress)
		);

		// create batch mint VAA, but with only a single token ID
		bytes memory batchVaa = craftValidVaa(
			ethereum,
			polygonWormholeChain,
			ethereum.acceptedEmitter,
			payload
		);

		(uint256 dustAmount, uint256 gasTokenAmount) = ethereumNft.getAmountsOnMint();
		ethereum.dustToken.approve(address(ethereumNft), dustAmount);

		// relayer submits transaction, but doesnt send any gas.
		vm.expectRevert(abi.encodeWithSignature("InvalidMsgValue()"));
		ethereumNft.receiveAndMintBatch{value: 0}(batchVaa);
	}
}
