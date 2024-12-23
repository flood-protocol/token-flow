// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "solady/tokens/ERC20.sol";
import {TokenFlow} from "src/TokenFlow.sol";
import {ITokenFlow, Constraint, BadNetflows, InvalidScope, IFlowScope} from "src/ITokenFlow.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {MockFlowScope} from "./mocks/MockFlowScope.sol";

contract TokenFlowTest is Test {
    TokenFlow tokenFlow;
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
        vm.startPrank(address(flowScope));
        token1.approve(address(tokenFlow), type(uint256).max);
        token2.approve(address(tokenFlow), type(uint256).max);
        vm.stopPrank();
    }

    function test_avoidCollisionWithERC20() public {
        Constraint[] memory constraints = new Constraint[](0);

        bytes memory data = abi.encodeCall(ERC20.transferFrom, (address(alice), address(this), 1 ether));

        vm.expectRevert();
        tokenFlow.main(constraints, IFlowScope(address(token1)), data);
    }

    // Scope access

    function test_revertCallingMoveInFromExternalScope() public {
        vm.expectRevert(InvalidScope.selector);
        tokenFlow.moveIn(address(token1), address(this), 1 ether);
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

    function test_revertOnBadNetflows() public {
        Constraint[] memory constraints = new Constraint[](1);
        constraints[0] = Constraint({
            token: address(token1),
            value: -1 ether // Negative constraint that should fail
        });

        vm.expectRevert(BadNetflows.selector);
        tokenFlow.main(constraints, flowScope, "");
    }

    function test_bubbleUpErrors() public {
        Constraint[] memory constraints = new Constraint[](0);

        // Setup MockFlowScope to revert with custom error
        flowScope.addRevert("CustomError");

        vm.expectRevert("CustomError");
        tokenFlow.main(constraints, flowScope, "");
    }

    function test_multipleConstraints() public {
        Constraint[] memory constraints = new Constraint[](2);
        constraints[0] = Constraint({token: address(token1), value: 1 ether});
        constraints[1] = Constraint({token: address(token2), value: 2 ether});

        // Test multiple token constraints
        tokenFlow.main(constraints, flowScope, "");
    }

    function test_emptyConstraints() public {
        Constraint[] memory constraints = new Constraint[](0);

        // Should succeed with no constraints
        tokenFlow.main(constraints, flowScope, "");
    }

    function test_moveInOutSequence() public {
        deal(address(token1), address(this), 10 ether);
        deal(address(token1), address(flowScope), 10 ether);
        // empty constraints so final netflows must be >= 0
        Constraint[] memory constraints = new Constraint[](0);

        // Add sequence of moveIn/moveOut that nets to zero
        flowScope.addMoveIn(address(token1), 1 ether, alice);
        flowScope.addMoveOut(address(token1), 1 ether);

        tokenFlow.main(constraints, flowScope, "");

        assertEq(token1.balanceOf(alice), 1 ether);
        assertEq(token1.balanceOf(address(flowScope)), 9 ether);
        assertEq(token1.balanceOf(address(this)), 10 ether);
    }
}
