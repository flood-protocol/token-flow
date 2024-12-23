// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {ITokenFlow, Constraint, BadNetflows, InvalidScope, IFlowScope} from "src/ITokenFlow.sol";
import {TransientNetflows} from "src/TransientNetflows.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {SafeCastLib} from "solady/utils/SafeCastLib.sol";
import {ReentrancyGuardTransient} from "solady/utils/ReentrancyGuardTransient.sol";


contract TokenFlow is ITokenFlow, ReentrancyGuardTransient {
    using SafeTransferLib for address;
    using SafeCastLib for uint256;

    uint constant private EXTERNAL_SCOPE = 0;
    uint constant private INTERNAL_SCOPE = 1;
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

        internalScope.enter(SELECTOR_EXTENSION, constraints, msg.sender, data);

        bool netflowsPositive = TransientNetflows.arePositive();
        if (!netflowsPositive) {
            revert BadNetflows();
        }

        clearTransientState();
    }

     /// @inheritdoc ITokenFlow
    function moveOut(address token, uint128 amount) external requireScope(INTERNAL_SCOPE) nonReentrant {
        uint balanceBefore = token.balanceOf(payer);
        token.safeTransferFrom(msg.sender, payer, amount);
        int received = (token.balanceOf(payer) - balanceBefore).toInt256();

        TransientNetflows.add(token, received);
    }

    /// @inheritdoc ITokenFlow
    function moveIn(address token, address to, uint128 amount) external requireScope(INTERNAL_SCOPE) nonReentrant {
        TransientNetflows.add(token, -int256(uint256(amount)));

        token.safeTransferFrom(payer, to, amount);
    }

    /// @inheritdoc ITokenFlow
    function getNetflow(address token) external view returns (int256) {
        return TransientNetflows.get(token);
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

    /// @dev We always use transient storage as this contract does not work without it anyways.
    function _useTransientReentrancyGuardOnlyOnMainnet() internal view virtual override returns (bool) {
        return false;
    }

}


