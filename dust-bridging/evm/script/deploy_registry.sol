// SPDX-License-Identifier: Apache 2

pragma solidity ^0.8.17;

import "forge-std/Script.sol";
import "forge-std/console.sol";

import "wormhole-solidity/BytesLib.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {Registry} from "../src/registry/Registry.sol";

contract ContractScript is Script {
    Registry registry;

    function deployContract() public {
        registry = new Registry();
    }

    function run() public {
        // begin sending transactions
        vm.startBroadcast();

        console.log("Deploying contract");
        deployContract();

        // finished
        vm.stopBroadcast();
    }
}
