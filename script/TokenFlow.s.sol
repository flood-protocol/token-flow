// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {TokenFlow} from "src/TokenFlow.sol";
import {Create3} from "./Create3.sol";

contract TokenFlowScript is Create3 {
    TokenFlow public tokenFlow;

    function setUp() public {}

    function run() public {
        bytes memory creationCode = type(TokenFlow).creationCode;

        bytes32 SALT = 0x1c00000000000000000000000000001fb0b5674d5f14a482a42ae41a6c646263;
        vm.broadcast();
        console.log("TokenFlow deployed at ", deploy3(creationCode, SALT, ""));
    }
}
