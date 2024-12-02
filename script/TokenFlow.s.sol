// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {TokenFlow} from "src/TokenFlow.sol";

contract TokenFlowScript is Script {
    TokenFlow public tokenFlow;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        tokenFlow = new TokenFlow();

        vm.stopBroadcast();
    }
}
