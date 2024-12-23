// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {IFlowScope, Constraint} from "src/ITokenFlow.sol";
import {ITokenFlow} from "src/ITokenFlow.sol";

struct MoveIn {
    address token;
    address to;
    uint128 amount;
}

struct MoveOut {
    address token;
    uint128 amount;
}

struct Reentry {
    IFlowScope flowScope;
    bytes data;
}

struct Revert {
    string reason;
}

enum InstructionType {
    MoveIn,
    MoveOut,
    Reentry,
    Revert
}

contract MockFlowScope is IFlowScope {
    ITokenFlow tokenFlow;

    uint256 instructionIndex;
    InstructionType[] instructionTypes;

    uint256 moveInIndex;
    uint256 moveOutIndex;
    uint256 reentryIndex;
    uint256 revertIndex;

    MoveIn[] moveInInstructions;
    MoveOut[] moveOutInstructions;
    Reentry[] reentryInstructions;
    Revert[] revertInstructions;

    bool shouldRevert;
    bool shouldReenter;

    constructor(ITokenFlow _tokenFlow) {
        tokenFlow = _tokenFlow;
    }

    function addMoveIn(address token, uint128 amount, address to) external {
        moveInInstructions.push(MoveIn({token: token, amount: amount, to: to}));
        instructionTypes.push(InstructionType.MoveIn);
    }

    function addMoveOut(address token, uint128 amount) external {
        moveOutInstructions.push(MoveOut({token: token, amount: amount}));
        instructionTypes.push(InstructionType.MoveOut);
    }

    function addReentry(IFlowScope flowScope, bytes calldata data) external {
        reentryInstructions.push(Reentry({flowScope: flowScope, data: data}));
        instructionTypes.push(InstructionType.Reentry);
    }

    function addRevert(string calldata reason) external {
        revertInstructions.push(Revert({reason: reason}));
        instructionTypes.push(InstructionType.Revert);
    }

    function enter(
        bytes28, /* selectorExtension */
        Constraint[] calldata constraints,
        address, /* payer */
        bytes calldata /* data */
    ) external {
        
        // Execute all instructions
        for (uint256 i = 0; i < instructionTypes.length; i++) {
            InstructionType iType = instructionTypes[i];

            if (iType == InstructionType.MoveIn) {
                tokenFlow.moveIn(
                    moveInInstructions[moveInIndex].token,
                    moveInInstructions[moveInIndex].to,
                    moveInInstructions[moveInIndex].amount
                );
                moveInIndex++;
            } else if (iType == InstructionType.MoveOut) {
                tokenFlow.moveOut(moveOutInstructions[moveOutIndex].token, moveOutInstructions[moveOutIndex].amount);
                moveOutIndex++;
            } else if (iType == InstructionType.Reentry) {
                ITokenFlow(msg.sender).main(
                    constraints, reentryInstructions[reentryIndex].flowScope, reentryInstructions[reentryIndex].data
                );
                reentryIndex++;
            } else if (iType == InstructionType.Revert) {
                revert(revertInstructions[revertIndex].reason);
            }
        }
    }
}
