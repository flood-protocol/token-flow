// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {EfficientHashLib} from "solady/utils/EfficientHashLib.sol";

/// @notice A helper library to manage netflows in a transient storage.
/// @dev the netflows are stored as an array of (token, value) pairs, with length in the first slot of the netflows.
library TransientNetflows {
    /// @notice The slot where the nonce for this set of netflows is stored.
    /// Equivalent to bytes32(uint256(keccak256("TokenFlow.netflows")) - 1)
    bytes32 internal constant NETFLOWS_SLOT = 0xb8ea23bb4fe1252fa49dff7d6168221ebfea7b5c55753f63740c76a259eb8f88;

    /// @notice The slot where the counter of negative netflows is stored.
    /// Equivalent to bytes32(uint256(keccak256("TokenFlow.negativeNetflowsCounter")) - 1)
    bytes32 internal constant NEGATIVE_NETFLOWS_COUNTER_SLOT =
        0x14f6a9c5e25725efcb69b4d15bdae41110c6a38bf78cda4b45b3539514d3fc55;

    /// @notice Sets the netflow for a token. If the netflow is not present, it is created.
    /// @param token The token to set the netflow for.
    /// @param value The value to set the netflow to.
    function insert(address token, int256 value) internal {
        // load the nonce from the netflows slot
        bytes32 slot = deriveAddressSlot(token);
        assembly ("memory-safe") {
            let previousValue := tload(slot)
            // If the previous value was >= 0 and the new value is < 0, we increment the negative netflows counter.
            if and(iszero(slt(previousValue, 0)), slt(value, 0)) {
                tstore(NEGATIVE_NETFLOWS_COUNTER_SLOT, add(tload(NEGATIVE_NETFLOWS_COUNTER_SLOT), 1))
            }
            // If the previous value was < 0 and the new value is >= 0, we decrement the negative netflows counter.
            if and(slt(previousValue, 0), iszero(slt(value, 0))) {
                tstore(NEGATIVE_NETFLOWS_COUNTER_SLOT, sub(tload(NEGATIVE_NETFLOWS_COUNTER_SLOT), 1))
            }
            tstore(slot, value)
        }
    }

    /// @notice Adds a value to the netflow for a token. If the token is not present, it is created with the value.
    /// @param token The token to add the value to.
    /// @param delta The value to add to the netflow.
    function add(address token, int256 delta) internal {
        insert(token, get(token) + delta);
    }

    /// @notice Gets the netflow for a token.
    /// @param token The token to get the netflow for.
    /// @return value The netflow value, or 0 if not present.
    function get(address token) internal view returns (int256 value) {
        bytes32 slot = deriveAddressSlot(token);
        assembly ("memory-safe") {
            value := tload(slot)
        }
    }

    /// @notice Checks if all the netflows are positive.
    /// @dev We keep a running counter of how many netflows are negative. See `insert`, so we just need to check if the counter is 0.
    /// @return result True if all the netflows are positive, false otherwise.
    function arePositive() internal view returns (bool result) {
        assembly ("memory-safe") {
            result := iszero(tload(NEGATIVE_NETFLOWS_COUNTER_SLOT))
        }
    }

    /// @notice Clears the netflows by incrementing the nonce. This ensure all the current netflows are not accessible anymore.
    function clear() internal {
        assembly ("memory-safe") {
            tstore(NETFLOWS_SLOT, add(tload(NETFLOWS_SLOT), 1))
            tstore(NEGATIVE_NETFLOWS_COUNTER_SLOT, 0)
        }
    }

    function deriveAddressSlot(address token) internal view returns (bytes32) {
        uint256 slot;
        assembly ("memory-safe") {
            slot := tload(NETFLOWS_SLOT)
        }
        return EfficientHashLib.hash(slot, uint256(uint160(token)));
    }
}
