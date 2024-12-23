// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {TransientNetflows} from "src/TransientNetflows.sol";

contract TransientNetflowsTest is Test {
    function test_insert(address token, int256 amount) public {
        TransientNetflows.insert(token, amount);

        bytes32 slot = TransientNetflows.deriveAddressSlot(token);
        int256 value;
        assembly {
            value := tload(slot)
        }
        assertEq(value, amount, "incorrect amount");
    }

    function test_get(address token, int256 amount) public {
        TransientNetflows.insert(token, amount);
        int256 value = TransientNetflows.get(token);
        assertEq(value, amount, "incorrect amount");
    }

    function test_clear() public {
        TransientNetflows.insert(address(1), 1 ether);
        TransientNetflows.insert(address(2), 2 ether);
        TransientNetflows.clear();
        assertEq(TransientNetflows.get(address(1)), 0, "incorrect amount");
        assertEq(TransientNetflows.get(address(2)), 0, "incorrect amount");
    }

    function test_are_positive(address token1, address token2, int256 amount1, int256 amount2) public {
        vm.assume(token1 != token2);
        vm.assume(amount1 > 0);
        vm.assume(amount2 < 0);

        TransientNetflows.insert(token1, amount1);
        assertTrue(TransientNetflows.arePositive(), "should be positive with single positive amount");

        TransientNetflows.insert(token2, amount2);
        assertFalse(TransientNetflows.arePositive(), "should be negative with one negative amount");

        TransientNetflows.clear();
        assertTrue(TransientNetflows.arePositive(), "should be positive after clear");

        TransientNetflows.insert(token1, amount2);
        assertFalse(TransientNetflows.arePositive(), "should be negative after reinserting negative");
    }

    function test_addOverflow() public {
        // Test adding beyond int256 bounds
        TransientNetflows.insert(address(1), type(int256).max);

        vm.expectRevert();
        TransientNetflows.add(address(1), 1);
    }

    function test_multipleTokens() public {
        address[] memory tokens = new address[](3);
        tokens[0] = address(1);
        tokens[1] = address(2);
        tokens[2] = address(3);

        for (uint256 i = 0; i < tokens.length; i++) {
            TransientNetflows.insert(tokens[i], int256(i + 1));
        }

        for (uint256 i = 0; i < tokens.length; i++) {
            assertEq(TransientNetflows.get(tokens[i]), int256(i + 1));
        }

        TransientNetflows.clear();

        for (uint256 i = 0; i < tokens.length; i++) {
            assertEq(TransientNetflows.get(tokens[i]), 0);
        }
    }

    function test_negativeNetflows() public {
        TransientNetflows.insert(address(1), -1);
        assertFalse(TransientNetflows.arePositive());
    }

    function test_are_positive_empty() public view {
        // Test arePositive() with no entries
        assertTrue(TransientNetflows.arePositive(), "should be positive with no entries");
    }

    function test_add_to_nonexistent() public {
        // Test adding to a token that hasn't been inserted
        TransientNetflows.add(address(1), 1 ether);
        assertEq(TransientNetflows.get(address(1)), 1 ether, "should create new entry");
    }
}
