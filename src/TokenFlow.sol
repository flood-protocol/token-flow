// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {ITokenFlow, Constraint, BadNetflows, InvalidScope, IFlowScope} from "src/ITokenFlow.sol";
import {TransientNetflows} from "src/TransientNetflows.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";


contract TokenFlow is ITokenFlow {
    using SafeTransferLib for address;

    uint constant EXTERNAL_SCOPE = 0;
    uint constant INTERNAL_SCOPE = 1;
    /// @notice The selector extension to append to the operator call.
    /// @dev For security reasons, there must never be clash between the IFlowScope.enter selector and any ERC20 selector that can transfer funds (today this is only transferFrom).
    /// @dev The selector extension is used to avoid such clashes.
    bytes28 public constant SELECTOR_EXTENSION = bytes28(keccak256("IFlowScope.enter(bytes28,Constraint[],address,bytes)"));
    

    modifier requireScope(uint required) {
        if (scope != required) revert InvalidScope();
        _;
    }

    /// @inheritdoc ITokenFlow
    address public transient payer;
    uint private transient scope;



     /// @inheritdoc ITokenFlow
    function main(Constraint[] calldata constraints, IFlowScope internalScope, bytes calldata data) external requireScope(EXTERNAL_SCOPE) {
        initTransientState(constraints, msg.sender);

        (bool ok, bytes memory err) = address(internalScope).call(abi.encodeCall(IFlowScope.enter, (SELECTOR_EXTENSION, constraints, msg.sender, data)));

        if (!ok) {
            clearTransientState();
            // bubble up the error
            assembly {
                revert(add(err, 0x20), mload(err))
            }
        }

        bool netflowsPositive = TransientNetflows.arePositive();
        clearTransientState();

        if (!netflowsPositive) {
            revert BadNetflows();
        }
    }

     /// @inheritdoc ITokenFlow
    function moveOut(address token, uint128 amount) external requireScope(INTERNAL_SCOPE) {
        TransientNetflows.add(token, int256(uint256(amount)));

        token.safeTransferFrom(msg.sender, payer, amount);
    }

    /// @inheritdoc ITokenFlow
    function moveIn(address token, uint128 amount, address to) external requireScope(INTERNAL_SCOPE) {
        TransientNetflows.add(token, -int256(uint256(amount)));

        token.safeTransferFrom(payer, to, amount);
    }

    function initTransientState(Constraint[] calldata constraints, address payer_) private {
        for (uint256 i = 0; i < constraints.length; i++) {
            TransientNetflows.insert(constraints[i].token, constraints[i].value);
        }
        payer = payer_;
        scope = INTERNAL_SCOPE;
    }

    function clearTransientState() private {
        payer = address(0);
        scope = EXTERNAL_SCOPE;
        TransientNetflows.clear();
    }
}


