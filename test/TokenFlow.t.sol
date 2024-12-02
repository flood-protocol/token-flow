// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {ERC20} from "solady/tokens/ERC20.sol";
import {TokenFlow} from "src/TokenFlow.sol";
import {ITokenFlow, Constraint, BadNetflows, InvalidScope, IFlowScope} from "src/ITokenFlow.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {MockFlowScope} from "./mocks/MockFlowScope.sol";

contract TokenFlowTest is Test {
    TokenFlow  tokenFlow;
    MockERC20 token1;
    MockERC20 token2;
    MockFlowScope flowScope;
    address alice = makeAddr("alice");

    function setUp() public {
        tokenFlow = new TokenFlow();
        token1 = new MockERC20("Token1", "TK1", 18);
        token2 = new MockERC20("Token2", "TK2", 18);
        flowScope = new MockFlowScope(tokenFlow);

        token1.approve(address(tokenFlow), type(uint256).max);
        token2.approve(address(tokenFlow), type(uint256).max);
    }

    function test_avoidCollisionWithERC20() public {
        Constraint[] memory constraints = new Constraint[](0);

        bytes memory data = abi.encodeCall(
            ERC20.transferFrom,
            (address(alice), address(this), 1 ether)
        );

        vm.expectRevert();
        tokenFlow.main(constraints, IFlowScope(address(token1)), data);
    }

    // Scope access

    function test_revertCallingMoveInFromExternalScope() public {
        vm.expectRevert(InvalidScope.selector);
        tokenFlow.moveIn(address(token1), 1 ether, address(this));
    }

    function test_revertCallingMoveOutFromExternalScope() public {
        vm.expectRevert(InvalidScope.selector);
        tokenFlow.moveOut(address(token1), 1 ether);
    }

    function test_revertCallingMainFromInternalScope() public {
        Constraint[] memory constraints = new Constraint[](0);

        flowScope.addReentry(flowScope, "");

        vm.expectRevert(InvalidScope.selector);
        // FlowScope will re-enter the tokenFlow contract, which will revert
        tokenFlow.main(constraints, flowScope, "");
    }
}
