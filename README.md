# TokenFlow

TokenFlow is a primitive that enables arbitrary token movements within a scope while enforcing constraints on the final state.

Handling token approvals and transfers often requires careful tracking of every operation and extensive safety checks. 
Traditional approaches either rely on multiple approvals degrading UX or introduce unnecessary intermediary hops.
While `Permit2` solves the multiple approvals problem and safely holds approvals, it's mostly used with signatures, thus requiring users to sign and then send their transaction, or delegate transaction execution to third parties. Moreover, since signatures are fully spent it can only be used for a single transfer, and not for complex operations like a multiplexing swap.

Thanks to transient storage, TokenFlow allows users to specify constraints on the final token state, without tying it to a specific action or contract.

The core idea is simple:
1. Define constraints on the final token state
2. Within an internal scope, allow _any_ contract to move _any_ user token around, in _any_ amount
3. Verify that the user's final token balance meets the constraints. If a token was not specified in the constraints but was moved, the default constraint is that the token was not spent, i.e. the balance must be greater or equal to the initial balance.

In spirit, this is similar to a flash loan from the user's balance, with the key difference that user-specified constraints are enforced.

## How It Works

<div class="mermaid">
sequenceDiagram
    participant User
    participant TokenFlow
    participant Scope
    participant Token

    User->>TokenFlow: main(constraints, scope)
    activate TokenFlow
    Note over TokenFlow: Initialize netflows tracking
    TokenFlow->>Scope: enter()
    activate Scope
    Note over Scope: Can freely move tokens
    Scope->>Token: transferFrom(user, to)
    Scope->>Token: transferFrom(from, user)
    Scope-->>TokenFlow: return
    deactivate Scope
    Note over TokenFlow: Verify netflow constraints
    TokenFlow-->>User: return
    deactivate TokenFlow
</div>



## Examples

```solidity
// Example 1: Token Swap
function swapTokens(
    address tokenIn,
    address tokenOut,
    uint amountIn,
    uint minAmountOut
) external {
    Constraint[] memory constraints = new Constraint[](2);
    constraints[0] = Constraint(tokenIn, int256(amountIn));  // Max outflow
    constraints[1] = Constraint(tokenOut, -int256(minAmountOut)); // Min inflow
    // This will revert if the constraints are not met
    tokenFlow.main(constraints, swapContract, "");
}

// Example 2: Simple Approve
function simpleApprove(
    address token,
    address spender,
    uint amount
) external {
    Constraint[] memory constraints = new Constraint[](1);
    constraints[0] = Constraint(token, int256(amount));
    tokenFlow.main(constraints, contractToApprove, "");
}

// Example 3: Batch Operations
function batchedOperations(
    address[] calldata tokens,
    uint[] calldata maxOutflows,
    address batchProcessor
) external {
    Constraint[] memory constraints = new Constraint[](tokens.length);
    for (uint i = 0; i < tokens.length; i++) {
        constraints[i] = Constraint(tokens[i], int256(maxOutflows[i]));
    }
    tokenFlow.main(constraints, batchProcessor, "");
}
```

## Implementation

TokenFlow combines two key mechanisms:

1. **Netflow Accounting**: Rather than transferring a predetermined amount, we allow arbitrary token movements within a scope. The system tracks the net flow of tokens (inflows minus outflows) and ensures it satisfies the user's constraints. This enables complex operations while maintaining simple safety invariants.

2. **Transient Storage + Scoping**: A scoped execution environment using transient storage ensures all state is properly isolated and cleaned up between transactions. This prevents any state leakage between different flows and provides clean composition.

## Properties

TokenFlow enables several key optimizations and use cases:

1. **Optimized Token Movements**
   - DEX aggregators can transfer directly from users to pools
   - No intermediate router hops needed
   - Eliminates the need for a contract holding approvals

2. **Intent Settlement**
   - Users specify constraints (min/max amounts) without tying them to specific actions
   - The user constraints are separated from the calldata of the operation, meaning they can be settled by any solver or protocol.

3. **Composability**
   - Clean composition with other protocols
   - No shared state between flows
   - Simple safety invariants

## Security Considerations

1. **Scope Trust**
   - Scope contracts have full control over user funds during execution
   - Must be carefully audited and verified
   - Consider using scope allowlists for additional safety

2. **Token Compatibility**
   - Works with standard ERC20 tokens
   - Works with fee-on-transfer tokens

## License

UNLICENSED
