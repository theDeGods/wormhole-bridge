// SPDX-License-Identifier: Apache 2

pragma solidity ^0.8.17;

import "forge-std/Script.sol";
import "forge-std/console.sol";

import {IWormhole} from "wormhole-solidity/IWormhole.sol";
import {y00tsV2} from "../src/nft/y00tsV2.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "wormhole-solidity/BytesLib.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

contract ContractScript is Script {
    using BytesLib for bytes;
    // DeGods emitter address in hex
    // base58 -> 7NtVtjkCAz5ywnwLMsd3TwtEM3rVtzsPinBEXPNZT6r2
    // bytes32 constant minterAddress = 0x34a23b4d22d5b0c4b851498188c27d94fe0f90d6258705db3c6975835b75beb8; //DeGods devnet
    // bytes32 constant minterAddress = 0x5ec18c34b47c63d17ab43b07b9b2319ea5ee2d163bce2e467000174e238c8e7f; //y00ts mainnet
    bytes32 constant minterAddress = 0x3a5a8772eeab57012f4a030a584cd8efb87a8996e89bb2d7999ad9dea97a0a4e; //y00ts devnet
    // bytes32 constant minterAddress = 0xe298490ef8d01f56d0460c07e60e753040fe2ca53f56d39925df0f654cd995bd; //DeGods mainnet
    uint256 constant dustAmountOnMint = 0; // 1 DUST to stake
    uint256 constant gasTokenAmountOnMint = 0 ether; // devnet
    // uint256 constant gasTokenAmountOnMint = 0.05 ether; // DeGods mainnet
    // temp receiver, also deployer address
    address constant royaltyReceiver = 0xa45D808eAFDe8B8E6B6B078fd246e28AD13030E8; 
    uint96 constant royaltyFeeNumerator = 333;
    
    // bytes constant baseUri = "https://metadata.degods.com/g/";
    // string constant name = "DeGods";
    // string constant symbol = "DEGODS";

    bytes constant baseUri = "https://metadata.y00ts.com/y/";
	string constant name = "y00ts";
	string constant symbol = "y00t";

    // Polygon Devnet
    IWormhole wormhole = IWormhole(0x0CBE91CF822c73C2315FB05100C2F714765d5c20);
    IERC20 dustToken = IERC20(0x5B0b1442B04475d1c3Dbf32DBA261f64F6f2F258);

    // Goerli Devnet
    // IWormhole wormhole = IWormhole(0x706abc4E45D419950511e474C7B9Ed348A4a716c);
    // IERC20 dustToken = IERC20(0xAD290867AEFFA008cDC182dC1092bFB378340Ba8); 

    // Polygon Wormhole mainnet
    // IWormhole wormhole = IWormhole(0x7A4B5a56256163F07b2C80A7cA55aBE66c4ec4d7);
    // IERC20 dustToken = IERC20(0x4987A49C253c38B3259092E9AAC10ec0C7EF7542);

    // Ethereum Wormhole mainnet
    // IWormhole wormhole = IWormhole(0x98f3c9e6E3fAce36bAAd05FE09d375Ef1464288B);
    // IERC20 dustToken = IERC20(0xB5b1b659dA79A2507C27AaD509f15B4874EDc0Cc);

    y00tsV2 nft;

    function deployContract() public {
        //Deploy our contract for testing
        y00tsV2 nftImplementation = new y00tsV2(
                wormhole,
                dustToken,
                minterAddress,
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
        nft = y00tsV2(address(proxy));
    }

    function run() public {
        // begin sending transactions
        vm.startBroadcast();

        // TokenBridgeRelayer.sol
        console.log("Deploying contract");
        deployContract();

        // finished
        vm.stopBroadcast();
    }
}
