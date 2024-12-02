// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

struct Constraint {
    address token;
    int256 value;
}

/// @title IFlowScope
/// @notice A flow scope is a contract that is called by the TokenFlow contract to execute a transaction.
/// @dev The flow scope is free to transfer any token of the payer, as long as they're repaid by the end of the flow.
interface IFlowScope {
    /// @notice Enter a token flow. During the token flow, any token of the payer can be transferred, as long as they're back by the end of the flow.
    /// @param selectorExtension A safety measure to prevent conflicts with ERC20 selectors.
    /// @param constraints The netflows constraints of the token flow.
    /// @param payer The payer of the token flow. Whoever is paying for the token flow.
    /// @param data Data to be passed to the entrypoint.
    function enter(bytes28 selectorExtension, Constraint[] calldata constraints, address payer, bytes calldata data)
        external;
}

/// @notice Reverts when the netflows constraints are violated.
error BadNetflows();

/// @notice Reverts when the function is called outside the proper scope (external or internal).
error InvalidScope();

/// @title ITokenFlow
/// A token flow is a set of netflows that must be respected by the internal scope. The internal scope is free to spend any token the user has approved to the token flow.
interface ITokenFlow {
    /// @notice Entrypoint into a token flow.
    /// @param constraints The netflows constraints of the token flow.
    /// @param scope The contract to be called to execute the token flow.
    /// @param data Data to be passed to the internal scope.
    function main(Constraint[] calldata constraints, IFlowScope scope, bytes calldata data) external;

    /// @notice Move tokens out of the current flow to the payer.
    /// @dev Calling this function outside of a flow scope will revert.
    /// @param token The token to move.
    /// @param amount The amount of tokens to move.
    function moveOut(address token, uint128 amount) external;

    /// @notice Move tokens from the current flow payer into the specified address.
    /// @dev Calling this function outside of a flow scope will revert.
    /// @param token The token to move.
    /// @param amount The amount of tokens to move.
    /// @param to The address to move the tokens to.
    function moveIn(address token, uint128 amount, address to) external;

    /// @notice A helper function to get the current flow payer.
    function payer() external view returns (address);

    /// @notice A helper function to get the current netflow of a token.
    /// @param token The token to get the netflow of.
    /// @return The current netflow of the token.
    function getNetflow(address token) external view returns (int256);
}
